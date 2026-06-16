/**
 * Fix Patterns 数据库
 * 存储 "检测到的问题 → 已验证的修复" 映射
 * 每次 analyze_code 优先查这里，命中则直接返回修复，无需 API
 */
import Database from "better-sqlite3";
import { join } from "path";
import { mkdirSync, existsSync } from "fs";
import { DATA_DIR } from "./core/paths.js";
export class FixPatternsDb {
    db = null;
    dbPath;
    constructor() {
        if (!existsSync(DATA_DIR))
            mkdirSync(DATA_DIR, { recursive: true });
        this.dbPath = join(DATA_DIR, "fix_patterns.db");
    }
    init() {
        if (this.db)
            return this.db;
        this.db = new Database(this.dbPath);
        this.db.pragma("journal_mode = WAL");
        this.db.exec(`
      CREATE TABLE IF NOT EXISTS fix_patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pattern_description TEXT NOT NULL,
        original_snippet TEXT,
        fixed_snippet TEXT,
        fix_description TEXT NOT NULL,
        library_key TEXT,
        tags TEXT,
        usage_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        last_used TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_fp_usage ON fix_patterns(usage_count DESC);
    `);
        return this.db;
    }
    record(data) {
        const db = this.init();
        const now = new Date().toISOString();
        // 去重：pattern_description 完全相同则更新
        const existing = db.prepare("SELECT * FROM fix_patterns WHERE LOWER(pattern_description) = LOWER(?)").get(data.pattern_description);
        if (existing) {
            db.prepare(`
        UPDATE fix_patterns SET
          usage_count = usage_count + 1,
          last_used = ?,
          fixed_snippet = COALESCE(?, fixed_snippet),
          fix_description = COALESCE(?, fix_description),
          tags = COALESCE(?, tags)
        WHERE id = ?
      `).run(now, data.fixed_snippet, data.fix_description, data.tags, existing.id);
            return { ...existing, usage_count: existing.usage_count + 1, last_used: now };
        }
        const result = db.prepare(`
      INSERT INTO fix_patterns
        (pattern_description, original_snippet, fixed_snippet, fix_description, library_key, tags, usage_count, created_at, last_used)
      VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
    `).run(data.pattern_description, data.original_snippet, data.fixed_snippet, data.fix_description, data.library_key, data.tags, now, now);
        return { id: result.lastInsertRowid, ...data, usage_count: 1, created_at: now, last_used: now };
    }
    /** 关键词模糊搜索（OR 逻辑，按命中数排序） */
    search(keywords) {
        const db = this.init();
        const terms = keywords.toLowerCase().split(/\s+/).filter(t => t.length > 2);
        if (terms.length === 0)
            return [];
        const conds = terms.map(() => `(LOWER(pattern_description) LIKE ? OR LOWER(fix_description) LIKE ? OR LOWER(tags) LIKE ?)`).join(" OR ");
        const params = terms.flatMap(t => [`%${t}%`, `%${t}%`, `%${t}%`]);
        const rows = db.prepare(`
      SELECT * FROM fix_patterns WHERE ${conds}
      ORDER BY usage_count DESC LIMIT 10
    `).all(...params);
        return rows.map(row => ({
            ...row,
            relevance: terms.filter(t => (row.pattern_description + " " + row.fix_description + " " + (row.tags ?? ""))
                .toLowerCase().includes(t)).length / terms.length,
        })).sort((a, b) => b.relevance - a.relevance);
    }
    list(limit = 20) {
        return this.init()
            .prepare("SELECT * FROM fix_patterns ORDER BY usage_count DESC, created_at DESC LIMIT ?")
            .all(limit);
    }
    getStats() {
        const db = this.init();
        const { total, totalUsage } = db.prepare("SELECT COUNT(*) as total, SUM(usage_count) as totalUsage FROM fix_patterns").get();
        return { total, totalUsage, dbPath: this.dbPath };
    }
    close() {
        this.db?.close();
        this.db = null;
    }
}
export const fixPatternsDb = new FixPatternsDb();
