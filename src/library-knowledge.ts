/**
 * 库知识预处理与上下文组装
 *
 * 设计：
 *   - LibraryPreprocessor  用 Claude Haiku 分析 .mqh，结果写入本地 JSON 缓存（一次性）
 *   - KnowledgeStore       读写 ~/.mql5-help-mcp/knowledge/<key>/<hash>.json
 *   - ContextAssembler     从缓存中提取与用户代码相关的 API 摘要，供 Claude 推理
 */

import Anthropic from "@anthropic-ai/sdk";
import * as fs from "fs/promises";
import * as fssync from "fs";
import * as path from "path";
import { homedir } from "os";

// ========== 数据结构 ==========

export interface MethodKnowledge {
  name: string;
  signature: string;
  purpose: string;
  example?: string;
}

export interface ClassKnowledge {
  name: string;
  solves: string;
  use_when: string;
  extends?: string;
  methods: MethodKnowledge[];
}

export interface FileKnowledge {
  file: string;         // relPath
  library: string;      // library key
  processedAt: string;
  classes: ClassKnowledge[];
  standalone_functions: MethodKnowledge[];
  key_patterns: Array<{ pattern: string; benefit: string }>;
  typical_usage?: string;
}

// ========== KnowledgeStore ==========

const KNOWLEDGE_DIR = path.join(homedir(), ".mql5-help-mcp", "knowledge");

export class KnowledgeStore {
  private mem = new Map<string, FileKnowledge>();

  private jsonPath(libraryKey: string, absPath: string): string {
    const safe = absPath.replace(/[/\\:]/g, "_").replace(/_{2,}/g, "_");
    return path.join(KNOWLEDGE_DIR, libraryKey, safe + ".json");
  }

  async get(libraryKey: string, absPath: string): Promise<FileKnowledge | null> {
    const key = `${libraryKey}::${absPath}`;
    if (this.mem.has(key)) return this.mem.get(key)!;

    const jsonFile = this.jsonPath(libraryKey, absPath);
    try {
      const [raw, srcStat, jsonStat] = await Promise.all([
        fs.readFile(jsonFile, "utf-8"),
        fs.stat(absPath),
        fs.stat(jsonFile),
      ]);
      if (srcStat.mtimeMs > jsonStat.mtimeMs) return null; // 源文件已更新
      const data = JSON.parse(raw) as FileKnowledge;
      this.mem.set(key, data);
      return data;
    } catch {
      return null;
    }
  }

  async save(libraryKey: string, absPath: string, data: FileKnowledge): Promise<void> {
    const jsonFile = this.jsonPath(libraryKey, absPath);
    fssync.mkdirSync(path.dirname(jsonFile), { recursive: true });
    await fs.writeFile(jsonFile, JSON.stringify(data, null, 2));
    this.mem.set(`${libraryKey}::${absPath}`, data);
  }

  /** 加载某个库的所有已缓存知识 */
  async loadLibrary(libraryKey: string): Promise<FileKnowledge[]> {
    const dir = path.join(KNOWLEDGE_DIR, libraryKey);
    return this.readJsonDir(dir);
  }

  /** 加载所有库的知识（用于 analyze_code 跨库分析） */
  async loadAll(libraryKeys: string[]): Promise<FileKnowledge[]> {
    const all: FileKnowledge[] = [];
    for (const k of libraryKeys) all.push(...await this.loadLibrary(k));
    return all;
  }

  private async readJsonDir(dir: string): Promise<FileKnowledge[]> {
    const results: FileKnowledge[] = [];
    try {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      for (const e of entries) {
        if (!e.isFile() || !e.name.endsWith(".json")) continue;
        try {
          const raw = await fs.readFile(path.join(dir, e.name), "utf-8");
          results.push(JSON.parse(raw) as FileKnowledge);
        } catch {}
      }
    } catch {}
    return results;
  }
}

// ========== LibraryPreprocessor ==========

const HAIKU_SYSTEM = `You are an expert MQL5 library analyst. Analyze the provided .mqh file and extract structured knowledge.
Return ONLY valid JSON — no markdown fences, no explanation.`;

const HAIKU_USER = (relPath: string, content: string) => `
File: ${relPath}

\`\`\`mql5
${content.length > 30000 ? content.slice(0, 30000) + "\n// ...(truncated)" : content}
\`\`\`

Return JSON with this exact shape:
{
  "classes": [
    {
      "name": "string",
      "solves": "string — what problem this solves (1-2 sentences)",
      "use_when": "string — when should a developer use this",
      "extends": "string or null",
      "methods": [
        { "name": "string", "signature": "string", "purpose": "string", "example": "string or null" }
      ]
    }
  ],
  "standalone_functions": [
    { "name": "string", "signature": "string", "purpose": "string", "example": "string or null" }
  ],
  "key_patterns": [
    { "pattern": "string — raw MQL5 API pattern this replaces", "benefit": "string" }
  ],
  "typical_usage": "string or null — one representative usage snippet"
}

Include only public classes and important methods. Skip internal/private details.
`.trim();

export class LibraryPreprocessor {
  private client: Anthropic;
  private store: KnowledgeStore;

  constructor(apiKey: string, store: KnowledgeStore) {
    this.client = new Anthropic({ apiKey });
    this.store = store;
  }

  async processFile(
    libraryKey: string,
    absPath: string,
    relPath: string
  ): Promise<FileKnowledge | null> {
    // 命中缓存直接返回
    const cached = await this.store.get(libraryKey, absPath);
    if (cached) return cached;

    try {
      const content = await fs.readFile(absPath, "utf-8");
      if (content.trim().length < 80) return null; // 太小，跳过

      const msg = await this.client.messages.create({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 2048,
        system: HAIKU_SYSTEM,
        messages: [{ role: "user", content: HAIKU_USER(relPath, content) }],
      });

      const text = msg.content[0].type === "text" ? msg.content[0].text : "";
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) return null;

      const parsed = JSON.parse(jsonMatch[0]);
      const knowledge: FileKnowledge = {
        file: relPath,
        library: libraryKey,
        processedAt: new Date().toISOString(),
        classes: parsed.classes ?? [],
        standalone_functions: parsed.standalone_functions ?? [],
        key_patterns: parsed.key_patterns ?? [],
        typical_usage: parsed.typical_usage ?? undefined,
      };

      await this.store.save(libraryKey, absPath, knowledge);
      return knowledge;
    } catch (err) {
      console.error(`[preprocess] failed ${relPath}: ${err}`);
      return null;
    }
  }

  /** 批量处理一个库的所有 .mqh 文件，返回进度报告 */
  async processLibrary(
    libraryKey: string,
    files: Array<{ absPath: string; relPath: string }>,
    onProgress: (msg: string) => void
  ): Promise<{ processed: number; cached: number; failed: number; totalCost: string }> {
    const mqh = files.filter(f => /\.mqh$/i.test(f.absPath));
    let processed = 0, cached = 0, failed = 0;

    onProgress(`📦 ${libraryKey}: 共 ${mqh.length} 个 .mqh 文件需分析`);

    for (let i = 0; i < mqh.length; i++) {
      const f = mqh[i];

      const hit = await this.store.get(libraryKey, f.absPath);
      if (hit) { cached++; continue; }

      onProgress(`  [${i + 1}/${mqh.length}] ${f.relPath}`);

      const result = await this.processFile(libraryKey, f.absPath, f.relPath);
      if (result) processed++;
      else failed++;

      // 简单限速，避免触发 API 速率限制
      if (i < mqh.length - 1) await delay(150);
    }

    // Haiku 成本估算：约 $0.25/M input + $1.25/M output
    const estCost = ((processed * 2000 * 0.25 + processed * 800 * 1.25) / 1_000_000).toFixed(4);

    return { processed, cached, failed, totalCost: `~$${estCost}` };
  }
}

// ========== ContextAssembler ==========

export interface AssembledContext {
  libraryAPISummary: string;   // 相关 API 的结构化摘要
  detectedPatterns: Array<{    // 在用户代码中检测到的可改进模式
    lineNo: number;
    code: string;
    hint: string;
    library: string;
  }>;
  hasKnowledge: boolean;
}

export class ContextAssembler {
  private store: KnowledgeStore;

  constructor(store: KnowledgeStore) {
    this.store = store;
  }

  async assemble(
    userCode: string,
    libraryKeys: string[]
  ): Promise<AssembledContext> {
    const allKnowledge = await this.store.loadAll(libraryKeys);
    if (allKnowledge.length === 0) {
      return { libraryAPISummary: "", detectedPatterns: [], hasKnowledge: false };
    }

    const lines = userCode.split("\n");

    // 1. 从知识库里提取所有类名、方法名 → 用于检测用户代码中的"原始写法"
    const detected: AssembledContext["detectedPatterns"] = [];

    for (const fk of allKnowledge) {
      for (const kp of fk.key_patterns) {
        // key_pattern.pattern 描述了"原始 MQL5 写法"，转成宽松正则
        const tokens = kp.pattern.match(/\b[A-Za-z_][A-Za-z0-9_]{2,}\b/g) ?? [];
        if (tokens.length === 0) continue;
        const re = new RegExp(tokens.map(t => `\\b${t}\\b`).join(".*"), "i");
        lines.forEach((line, idx) => {
          if (re.test(line) && !line.trim().startsWith("//")) {
            detected.push({
              lineNo: idx + 1,
              code: line.trim().substring(0, 80),
              hint: `可用 ${fk.library} 改写：${kp.benefit}`,
              library: fk.library,
            });
          }
        });
      }
    }

    // 2. 组装 API 摘要（给 Claude 看，让它做精准推理）
    const sections: string[] = ["【已加载库的 API 知识摘要】"];

    for (const fk of allKnowledge) {
      if (fk.classes.length === 0 && fk.standalone_functions.length === 0) continue;

      sections.push(`\n▸ ${fk.library} / ${fk.file}`);

      for (const cls of fk.classes) {
        sections.push(`  class ${cls.name}${cls.extends ? ` extends ${cls.extends}` : ""}`);
        sections.push(`    用途: ${cls.solves}`);
        sections.push(`    适用: ${cls.use_when}`);
        if (cls.methods.length > 0) {
          sections.push(`    方法:`);
          for (const m of cls.methods.slice(0, 8)) {
            sections.push(`      ${m.signature}`);
            sections.push(`        → ${m.purpose}`);
            if (m.example) sections.push(`        示例: ${m.example}`);
          }
        }
      }

      for (const fn of fk.standalone_functions.slice(0, 5)) {
        sections.push(`  fn ${fn.signature}`);
        sections.push(`    → ${fn.purpose}`);
      }

      if (fk.typical_usage) {
        sections.push(`  典型用法: ${fk.typical_usage}`);
      }
    }

    if (detected.length > 0) {
      sections.push("\n【在用户代码中检测到的可优化点】");
      for (const d of detected) {
        sections.push(`  第 ${d.lineNo} 行: ${d.code}`);
        sections.push(`    → ${d.hint}`);
      }
    }

    sections.push("\n【说明】");
    sections.push("以上是本地预处理的库知识，请结合用户代码给出具体、可编译的改进建议。");

    return {
      libraryAPISummary: sections.join("\n"),
      detectedPatterns: detected,
      hasKnowledge: true,
    };
  }
}

// ========== 单例 ==========

export const knowledgeStore = new KnowledgeStore();
export const contextAssembler = new ContextAssembler(knowledgeStore);

function delay(ms: number) { return new Promise(r => setTimeout(r, ms)); }
