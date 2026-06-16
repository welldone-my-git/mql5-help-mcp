/**
 * Semantic search layer — Ollama embedding + SQLite vector store + cosine similarity
 *
 * Zero new npm dependencies:
 *   - Embeddings: Ollama REST API (local, user-managed)
 *   - Vector store: better-sqlite3 (already in deps), Float32Array as BLOB
 *   - Similarity: pure JS cosine (adequate for ≤20k docs)
 */
import Database from "better-sqlite3";
import * as fsSync from "fs";
import * as path from "path";
import { stripHtml } from "../utils.js";
import { DATA_DIR } from "./paths.js";
// ── Math ─────────────────────────────────────────────────────────────────────
export function cosineSimilarity(a, b) {
    let dot = 0, na = 0, nb = 0;
    for (let i = 0; i < a.length; i++) {
        dot += a[i] * b[i];
        na += a[i] * a[i];
        nb += b[i] * b[i];
    }
    const denom = Math.sqrt(na) * Math.sqrt(nb);
    return denom === 0 ? 0 : dot / denom;
}
// ── Ollama client ─────────────────────────────────────────────────────────────
export async function ollamaEmbed(url, model, text) {
    try {
        const res = await fetch(`${url}/api/embeddings`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model, prompt: text }),
            signal: AbortSignal.timeout(30_000),
        });
        if (!res.ok)
            return null;
        const data = await res.json();
        if (!Array.isArray(data.embedding))
            return null;
        return new Float32Array(data.embedding);
    }
    catch {
        return null;
    }
}
export async function ollamaHealthCheck(url) {
    try {
        const res = await fetch(`${url}/api/tags`, { signal: AbortSignal.timeout(3_000) });
        return res.ok;
    }
    catch {
        return false;
    }
}
// ── Vector store (SQLite + BLOB) ──────────────────────────────────────────────
const DEFAULT_DB = path.join(DATA_DIR, "semantic.db");
export class VectorStore {
    db;
    /** in-memory cache, invalidated on upsert */
    cache = null;
    constructor(dbPath = DEFAULT_DB) {
        fsSync.mkdirSync(path.dirname(dbPath), { recursive: true });
        this.db = new Database(dbPath);
        this.db.pragma("journal_mode = WAL");
        this.db.exec(`
      CREATE TABLE IF NOT EXISTS doc_embeddings (
        doc_key      TEXT PRIMARY KEY,
        abs_path     TEXT NOT NULL,
        embedding    BLOB NOT NULL,
        text_preview TEXT,
        model        TEXT,
        indexed_at   TEXT NOT NULL
      )
    `);
    }
    upsert(docKey, absPath, embedding, opts) {
        const buf = Buffer.from(embedding.buffer, embedding.byteOffset, embedding.byteLength);
        this.db.prepare(`
      INSERT OR REPLACE INTO doc_embeddings
        (doc_key, abs_path, embedding, text_preview, model, indexed_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(docKey, absPath, buf, opts?.preview ?? null, opts?.model ?? null, new Date().toISOString());
        this.cache = null;
    }
    hasKey(docKey) {
        return !!this.db.prepare("SELECT 1 FROM doc_embeddings WHERE doc_key = ?").get(docKey);
    }
    loadAll() {
        if (this.cache)
            return this.cache;
        const rows = this.db.prepare("SELECT doc_key, abs_path, embedding FROM doc_embeddings").all();
        this.cache = new Map();
        for (const r of rows) {
            const embedding = new Float32Array(r.embedding.buffer, r.embedding.byteOffset, r.embedding.byteLength / 4);
            this.cache.set(r.doc_key, { embedding, absPath: r.abs_path });
        }
        return this.cache;
    }
    count() {
        return this.db.prepare("SELECT COUNT(*) as n FROM doc_embeddings").get().n;
    }
    getStats() {
        const row = this.db.prepare("SELECT model FROM doc_embeddings LIMIT 1").get();
        return { count: this.count(), dbPath: DEFAULT_DB, model: row?.model ?? null };
    }
    deleteAll() {
        this.db.prepare("DELETE FROM doc_embeddings").run();
        this.cache = null;
    }
    close() { this.db.close(); }
}
export function semanticSearch(queryEmbedding, vectorStore, limit) {
    const all = vectorStore.loadAll();
    const scored = [];
    for (const [docKey, { embedding, absPath }] of all.entries()) {
        scored.push({ docKey, absPath, score: cosineSimilarity(queryEmbedding, embedding) });
    }
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, limit);
}
/**
 * Merge keyword and semantic results.
 * weight: 0.4 × keyword + 0.6 × semantic (semantic prioritised for discovery)
 */
export function hybridMerge(keyword, semantic, limit) {
    const W_KW = 0.4, W_SEM = 0.6;
    const map = new Map();
    for (const h of keyword) {
        map.set(h.key, { key: h.key, keywordScore: h.score, semanticScore: 0, hybridScore: W_KW * h.score });
    }
    for (const h of semantic) {
        const existing = map.get(h.docKey);
        if (existing) {
            existing.semanticScore = h.score;
            existing.hybridScore = W_KW * existing.keywordScore + W_SEM * h.score;
        }
        else {
            map.set(h.docKey, { key: h.docKey, keywordScore: 0, semanticScore: h.score, hybridScore: W_SEM * h.score });
        }
    }
    return [...map.values()]
        .sort((a, b) => b.hybridScore - a.hybridScore)
        .slice(0, limit);
}
// ── Text extraction for indexing ──────────────────────────────────────────────
const MAX_EMBED_CHARS = 2000;
export function extractTextForEmbedding(content, absPath) {
    const lower = absPath.toLowerCase();
    let text;
    if (/\.(htm|html)$/i.test(lower)) {
        text = stripHtml(content);
    }
    else {
        // MD, .mq5, .mqh, .pdf (already plain text via readFileText) — use as-is
        text = content;
    }
    return text.substring(0, MAX_EMBED_CHARS).trim();
}
// ── Singleton ─────────────────────────────────────────────────────────────────
export const vectorStore = new VectorStore();
