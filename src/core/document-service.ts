import * as fs from "fs/promises";
import * as path from "path";
import { fileURLToPath } from "url";
import { SmartQueryEngine } from "../smart-query.js";
import { stripHtml, MIGRATION_HINTS } from "../utils.js";
import type { DocEntry, DomainPlugin } from "./plugin.js";
import { DATA_DIR } from "./paths.js";
import { vectorStore, ollamaEmbed, semanticSearch, hybridMerge } from "./embedding.js";
import { readFileText, PDF_EXT } from "./ingestion.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// 配置文件路径
export const CONFIG_PATH = path.join(DATA_DIR, "config.json");

// ── Config v2 schema ──────────────────────────────────────────────────────────

export interface SourceConfig {
  key: string;
  path: string;
  type?: "html" | "md" | "code" | "auto";
  priority?: number;
  description?: string;
  builtin?: boolean;
}

export interface EmbeddingConfig {
  provider: "ollama";
  model: string;           // e.g. "nomic-embed-text"
  url: string;             // e.g. "http://localhost:11434"
}

export interface AppConfig {
  /** v2: 统一来源列表 */
  sources?: SourceConfig[];
  /** v1 兼容：外部库（自动合并进 sources） */
  extraLibraries?: Array<{ key: string; path: string; description?: string }>;
  /** 领域插件名，null 表示不加载任何专有工具 */
  domain_plugin?: string | null;
  /** 语义搜索配置（可选） */
  embedding?: EmbeddingConfig;
}

// 内置默认来源（当 config.sources 未覆盖时使用）
export const DEFAULT_BUILTIN: SourceConfig[] = [
  { key: "MQL5_HELP",            path: path.resolve(__dirname, "..", "..", "MQL5_HELP"),            builtin: true, priority: 1 },
  { key: "MQL5_Algo_Book",       path: path.resolve(__dirname, "..", "..", "MQL5_Algo_Book"),       builtin: true, priority: 2 },
  { key: "Neural_Networks_Book", path: path.resolve(__dirname, "..", "..", "Neural_Networks_Book"), builtin: true, priority: 3 },
];

// 向后兼容：BUILTIN_ROOTS 形状（供 list_libraries 判断是否内置）
export const BUILTIN_ROOTS = DEFAULT_BUILTIN;

export async function loadConfig(): Promise<AppConfig> {
  try {
    const raw = await fs.readFile(CONFIG_PATH, "utf-8");
    return JSON.parse(raw) as AppConfig;
  } catch {
    return {};
  }
}

/** 合并 config 产出最终来源列表（builtin first-wins） */
async function resolveSources(): Promise<SourceConfig[]> {
  const cfg = await loadConfig();
  const result: SourceConfig[] = [];

  // 内置来源（sources 里没显式覆盖时都加入）
  for (const b of DEFAULT_BUILTIN) {
    const override = cfg.sources?.find(s => s.key === b.key);
    result.push(override ?? b);
  }

  // config.sources 里的非内置条目
  if (cfg.sources) {
    for (const s of cfg.sources) {
      if (!DEFAULT_BUILTIN.some(b => b.key === s.key)) {
        result.push(s);
      }
    }
  }

  // v1 兼容：extraLibraries 追加
  if (cfg.extraLibraries) {
    for (const e of cfg.extraLibraries) {
      if (!result.some(r => r.key === e.key)) {
        result.push({ key: e.key, path: e.path, description: e.description });
      }
    }
  }

  return result;
}

/** 加载领域插件（按 config.domain_plugin，默认 "mql5"） */
async function loadPlugin(): Promise<DomainPlugin | null> {
  const cfg = await loadConfig();
  // 明确设为 null 则不加载
  if (cfg.domain_plugin === null) return null;
  const pluginName = cfg.domain_plugin ?? "mql5";
  try {
    const mod = await import(`../plugins/${pluginName}/index.js`);
    const plugin: DomainPlugin = mod[`${pluginName}Plugin`] ?? mod.default;
    console.error(`🔌 已加载领域插件: ${plugin.name}`);
    return plugin;
  } catch (e) {
    console.error(`⚠️  插件 "${pluginName}" 加载失败: ${e}`);
    return null;
  }
}

export async function getEmbeddingConfig(): Promise<EmbeddingConfig | null> {
  const cfg = await loadConfig();
  return cfg.embedding ?? null;
}

// ── Runtime state ─────────────────────────────────────────────────────────────

// 已加载的库清单（供 list_libraries / preprocess_library 使用）
export const loadedLibraries: Array<{ key: string; absPath: string; description: string; fileCount: number }> = [];
// 外部库文件列表（供 preprocess_library 使用）
export const externalLibFiles = new Map<string, Array<{ absPath: string; relPath: string }>>();
// 已加载的领域插件
export let activePlugin: DomainPlugin | null = null;

// 文档索引缓存

export let docIndex: Map<string, DocEntry> | null = null;
let nameIndex: Map<string, DocEntry> | null = null;
export let queryEngine: SmartQueryEngine | null = null;

// 支持的文件扩展名
const DOC_EXTS  = /\.(htm|html|md)$/i;
const CODE_EXTS = /\.(mq5|mqh)$/i;
const ALL_EXTS  = /\.(htm|html|md|mq5|mqh|pdf)$/i;

// 递归读取目录下的文件
async function walkDir(rootAbs: string, repoKey: string, baseRel = ""): Promise<DocEntry[]> {
  const entries: DocEntry[] = [];
  let dirents;
  try {
    dirents = await fs.readdir(path.join(rootAbs, baseRel), { withFileTypes: true });
  } catch (e) {
    console.debug(`[index] cannot read directory ${path.join(rootAbs, baseRel)}: ${e}`);
    return entries;
  }

  for (const d of dirents) {
    const relPath = path.join(baseRel, d.name);
    const absPath = path.join(rootAbs, relPath);
    if (d.isDirectory()) {
      const sub = await walkDir(rootAbs, repoKey, relPath);
      entries.push(...sub);
    } else if (ALL_EXTS.test(d.name)) {
      entries.push({ absPath, relPath, repo: repoKey });
    }
  }
  return entries;
}

// 构建文档索引（所有来源按 resolveSources 顺序，first-wins）
export async function buildIndex(): Promise<Map<string, DocEntry>> {
  if (docIndex) return docIndex;

  docIndex = new Map();
  nameIndex = new Map();

  // 加载插件（只初始化一次）
  if (!activePlugin) {
    activePlugin = await loadPlugin();
  }

  // 解析所有来源
  const allSources = await resolveSources();
  const roots: Array<{ key: string; abs: string; builtin: boolean; description: string }> = [];
  for (const s of allSources) {
    const absPath = path.resolve(s.path);
    try {
      await fs.access(absPath);
      roots.push({ key: s.key, abs: absPath, builtin: !!s.builtin, description: s.description ?? "" });
    } catch {
      if (!s.builtin) {
        console.error(`⚠️  来源路径不存在，已跳过: ${s.key} (${absPath})`);
      }
    }
  }

  // 遍历并索引
  loadedLibraries.length = 0;
  externalLibFiles.clear();
  for (const r of roots) {
    const files = await walkDir(r.abs, r.key);

    // 非内置库记录文件列表，供 preprocess_library 使用
    if (!r.builtin) {
      externalLibFiles.set(r.key, files.map(f => ({ absPath: f.absPath, relPath: f.relPath })));
    }

    for (const f of files) {
      const base = path.basename(f.relPath).toLowerCase();
      const noExt = base.replace(ALL_EXTS, "");

      // 主键：文件名（无扩展）— first-wins 保证内置库优先
      if (!docIndex.has(noExt)) docIndex.set(noExt, f);
      if (!nameIndex.has(noExt)) nameIndex.set(noExt, f);

      // 非内置库加命名空间前缀（避免冲突）
      if (!r.builtin) {
        const nsKey = `${r.key.toLowerCase()}_${noExt}`;
        docIndex.set(nsKey, f);
      }

      // 类名变体（去掉开头 C）
      if (noExt.startsWith("c") && noExt.length > 2) {
        const shortKey = noExt.substring(1);
        if (!docIndex.has(shortKey)) docIndex.set(shortKey, f);
      }

      // ONNX 相关关键词
      if (noExt.includes("onnx")) {
        if (!docIndex.has("onnx")) docIndex.set("onnx", f);
        if (!docIndex.has("onnx_guide")) docIndex.set("onnx_guide", f);
        if (!docIndex.has("ml")) docIndex.set("ml", f);
        if (!docIndex.has("ai")) docIndex.set("ai", f);
      }

      // 电子书目录粗粒度前缀
      if (f.repo === "MQL5_Algo_Book") docIndex.set(`algo_${noExt}`, f);
      if (f.repo === "Neural_Networks_Book") docIndex.set(`nn_${noExt}`, f);
    }

    loadedLibraries.push({
      key: r.key,
      absPath: r.abs,
      description: r.description || (r.builtin ? "内置" : "外部库"),
      fileCount: files.length,
    });
  }

  console.error(`📚 索引已建立: ${docIndex.size} 个键，${nameIndex.size} 个文件名索引`);
  queryEngine = new SmartQueryEngine(docIndex);
  return docIndex;
}

// ── 关键词搜索（内部，返回结构化结果）────────────────────────────────────────

function keywordSearch(
  query: string,
  index: Map<string, DocEntry>
): Array<{ key: string; entry: DocEntry; score: number }> {
  const queryLower = query.toLowerCase();

  const expansionKeys = new Set<string>();
  for (const [k, v] of Object.entries(MIGRATION_HINTS)) {
    if (queryLower.includes(k)) v.targetKeys.forEach((t) => expansionKeys.add(t));
  }
  const ident = extractUndeclaredIdent(queryLower);
  if (ident) MIGRATION_HINTS[ident]?.targetKeys.forEach((t) => expansionKeys.add(t));

  const results: Array<{ key: string; entry: DocEntry; score: number }> = [];
  for (const [key, entry] of index.entries()) {
    let score = 0;
    if (key === queryLower) score = 1.0;
    else if (key.includes(queryLower)) score = queryLower.length / Math.max(2, key.length);
    else if (expansionKeys.has(key)) score = 0.95;
    if (score > 0) results.push({ key, entry, score });
  }
  results.sort((a, b) => b.score - a.score);
  return results;
}

// 匹配 "undeclared identifier 'name'" 或 "undeclared identifier name"
const UNDECLARED_RE = /undeclared\s+identifier\s+'?"?([a-z_][a-z0-9_]*)'?"?/i;
const UNDECLARED_RE_NQ = /undeclared\s+identifier\s+([a-z_][a-z0-9_]*)/i;

/** 从查询中提取 undeclared identifier 的变量名 */
function extractUndeclaredIdent(query: string): string | undefined {
  return query.match(UNDECLARED_RE)?.[1] ?? query.match(UNDECLARED_RE_NQ)?.[1];
}

// 构建迁移提示行
function buildSmartHints(query: string): string[] {
  const queryLower = query.toLowerCase();
  const hints: string[] = [];
  const missing = extractUndeclaredIdent(queryLower);
  if (missing) {
    const h = MIGRATION_HINTS[missing];
    if (h) hints.push(`🩺 诊断：未声明标识符 '${missing}' → 可能应改为 '${h.replacement}'（${h.hint}）`);
  }
  for (const [k, v] of Object.entries(MIGRATION_HINTS)) {
    if (queryLower.includes(k)) hints.push(`🔁 迁移建议：'${k}' → '${v.replacement}'（${v.hint}）`);
  }
  return hints;
}

// ── 搜索文档（关键词 or 混合）────────────────────────────────────────────────

export async function searchDocs(query: string, limit: number = 10): Promise<string> {
  const index = await buildIndex();
  const kwResults = keywordSearch(query, index);
  const smartHints = buildSmartHints(query);
  const exact = index.get(query.toLowerCase());

  let searchMode = "关键词";
  let finalResults: Array<{ key: string; entry: DocEntry; displayScore?: number }> = kwResults.slice(0, limit);

  // 混合搜索：embedding 已配置且 vectorStore 有数据
  const embCfg = await getEmbeddingConfig();
  if (embCfg && vectorStore.count() > 0) {
    const queryVec = await ollamaEmbed(embCfg.url, embCfg.model, query);
    if (queryVec) {
      const semHits = semanticSearch(queryVec, vectorStore, limit * 2);
      const kwHits = kwResults.map(r => ({ key: r.key, score: r.score }));
      const merged = hybridMerge(kwHits, semHits, limit);
      finalResults = merged.map(h => ({
        key: h.key,
        entry: index.get(h.key)!,
        displayScore: h.hybridScore,
      })).filter(r => r.entry != null);
      searchMode = "混合（关键词 + 语义）";
    }
  }

  let out = `🔍 搜索: "${query}"  [${searchMode}]\n\n`;
  if (smartHints.length) out += smartHints.map((s) => `• ${s}`).join("\n") + "\n\n";
  if (exact) out += `✅ 精确匹配: ${exact.relPath}  (来源: ${exact.repo})\n\n`;

  if (finalResults.length > 0) {
    out += `📋 相关文档 (${finalResults.length})：\n`;
    finalResults.forEach((m, i) => {
      const score = m.displayScore != null ? `  [${(m.displayScore * 100).toFixed(0)}%]` : "";
      out += `  ${i + 1}. ${m.entry.relPath}  (${m.entry.repo})${score}\n`;
    });
  } else if (!exact) {
    out += "❌ 未找到匹配文档\n";
    if (searchMode === "关键词") {
      out += "💡 提示: 使用英文关键字，或运行 build_semantic_index 开启语义搜索（可用中文查询）";
    }
  }

  return out;
}

// 读取文档内容（多目录，含代码文件）
export async function getDoc(filename: string): Promise<string> {
  const index = await buildIndex();
  const raw = filename.trim();
  const lower = raw.toLowerCase();

  // 1) 按 key（无扩展）
  let entry = index.get(lower.replace(ALL_EXTS, ""));

  // 2) 按文件名（无扩展）
  if (!entry && nameIndex) {
    const nameKey = path.basename(lower).replace(ALL_EXTS, "");
    entry = nameIndex.get(nameKey) || undefined;
  }

  if (!entry) {
    const search = await searchDocs(filename, 5);
    return `❌ 未找到文件: ${filename}\n\n${search}`;
  }

  try {
    const header = `📄 ${entry.relPath} (${entry.repo})\n${"=".repeat(60)}\n\n`;
    const footer = `\n\n${"=".repeat(60)}`;

    if (CODE_EXTS.test(entry.absPath)) {
      // .mq5 / .mqh — 原始代码，保留格式
      const content = await fs.readFile(entry.absPath, "utf-8");
      const truncated = content.length > 12000
        ? content.substring(0, 12000) + "\n\n// ... (内容过长，已截断)"
        : content;
      return header + "```mql5\n" + truncated + "\n```" + footer;
    }

    if (/\.(md)$/i.test(entry.absPath)) {
      const content = await fs.readFile(entry.absPath, "utf-8");
      const truncated = content.length > 15000
        ? content.substring(0, 15000) + "\n\n... (内容过长，已截断)"
        : content;
      return header + truncated + footer;
    }

    if (PDF_EXT.test(entry.absPath)) {
      const text = await readFileText(entry.absPath);
      const truncated = text.length > 12000
        ? text.substring(0, 12000) + "\n\n... (内容过长，已截断)"
        : text;
      return header + truncated + footer;
    }

    // HTML 文档
    const content = await fs.readFile(entry.absPath, "utf-8");
    const text = stripHtml(content);
    const truncated = text.length > 10000 ? text.substring(0, 10000) + "..." : text;
    return header + truncated + footer;
  } catch (error) {
    return `❌ 读取失败: ${error}`;
  }
}
