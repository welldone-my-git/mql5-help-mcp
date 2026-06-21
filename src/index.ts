#!/usr/bin/env node

/**
 * Knowledge Base MCP Server
 * 通用文档/代码库检索引擎，可通过 domain_plugin 加载领域专有能力
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs/promises";
import * as path from "path";
import { fileURLToPath } from "url";
import { homedir } from "os";
import { SmartQueryEngine } from "./smart-query.js";
import { getErrorDb, closeErrorDb } from "./error-db.js";
import { stripHtml, MIGRATION_HINTS } from "./utils.js";
import {
  LibraryPreprocessor,
  knowledgeStore,
  contextAssembler,
} from "./library-knowledge.js";
import { fixPatternsDb } from "./fix-patterns.js";
import type { DomainPlugin } from "./core/plugin.js";
import { DATA_DIR } from "./core/paths.js";
import {
  vectorStore,
  ollamaEmbed,
  ollamaHealthCheck,
  semanticSearch,
  hybridMerge,
  extractTextForEmbedding,
} from "./core/embedding.js";
import { readFileText, PDF_EXT } from "./core/ingestion.js";
import { CORE_TOOL_DEFINITIONS } from "./core/tool-definitions.js";
import { browseDocuments } from "./core/browse.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 配置文件路径
const CONFIG_PATH = path.join(DATA_DIR, "config.json");

// ── Config v2 schema ──────────────────────────────────────────────────────────

interface SourceConfig {
  key: string;
  path: string;
  type?: "html" | "md" | "code" | "auto";
  priority?: number;
  description?: string;
  builtin?: boolean;
}

interface EmbeddingConfig {
  provider: "ollama";
  model: string;           // e.g. "nomic-embed-text"
  url: string;             // e.g. "http://localhost:11434"
}

interface AppConfig {
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
const DEFAULT_BUILTIN: SourceConfig[] = [
  { key: "MQL5_HELP",            path: path.resolve(__dirname, "..", "MQL5_HELP"),            builtin: true, priority: 1 },
  { key: "MQL5_Algo_Book",       path: path.resolve(__dirname, "..", "MQL5_Algo_Book"),       builtin: true, priority: 2 },
  { key: "Neural_Networks_Book", path: path.resolve(__dirname, "..", "Neural_Networks_Book"), builtin: true, priority: 3 },
];

// 向后兼容：BUILTIN_ROOTS 形状（供 list_libraries 判断是否内置）
const BUILTIN_ROOTS = DEFAULT_BUILTIN;

async function loadConfig(): Promise<AppConfig> {
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
    const mod = await import(`./plugins/${pluginName}/index.js`);
    const plugin: DomainPlugin = mod[`${pluginName}Plugin`] ?? mod.default;
    console.error(`🔌 已加载领域插件: ${plugin.name}`);
    return plugin;
  } catch (e) {
    console.error(`⚠️  插件 "${pluginName}" 加载失败: ${e}`);
    return null;
  }
}

async function getEmbeddingConfig(): Promise<EmbeddingConfig | null> {
  const cfg = await loadConfig();
  return cfg.embedding ?? null;
}

// ── Runtime state ─────────────────────────────────────────────────────────────

// 已加载的库清单（供 list_libraries / preprocess_library 使用）
const loadedLibraries: Array<{ key: string; absPath: string; description: string; fileCount: number }> = [];
// 外部库文件列表（供 preprocess_library 使用）
const externalLibFiles = new Map<string, Array<{ absPath: string; relPath: string }>>();
// 已加载的领域插件
let activePlugin: DomainPlugin | null = null;

// 文档索引缓存
type DocEntry = { absPath: string; relPath: string; repo: string };
let docIndex: Map<string, DocEntry> | null = null;
let nameIndex: Map<string, DocEntry> | null = null;
let queryEngine: SmartQueryEngine | null = null;

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
  } catch {
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
async function buildIndex(): Promise<Map<string, DocEntry>> {
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
  const undeclaredMatch =
    queryLower.match(/undeclared\s+identifier\s+'?"?([a-z_][a-z0-9_]*)'?"?/i) ||
    queryLower.match(/undeclared\s+identifier\s+([a-z_][a-z0-9_]*)/i);
  if (undeclaredMatch?.[1]) {
    const m = undeclaredMatch[1].toLowerCase();
    MIGRATION_HINTS[m]?.targetKeys.forEach((t) => expansionKeys.add(t));
  }

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

// 构建迁移提示行
function buildSmartHints(query: string): string[] {
  const queryLower = query.toLowerCase();
  const hints: string[] = [];
  const undeclaredMatch =
    queryLower.match(/undeclared\s+identifier\s+'?"?([a-z_][a-z0-9_]*)'?"?/i) ||
    queryLower.match(/undeclared\s+identifier\s+([a-z_][a-z0-9_]*)/i);
  if (undeclaredMatch?.[1]) {
    const missing = undeclaredMatch[1].toLowerCase();
    const h = MIGRATION_HINTS[missing];
    if (h) hints.push(`🩺 诊断：未声明标识符 '${missing}' → 可能应改为 '${h.replacement}'（${h.hint}）`);
  }
  for (const [k, v] of Object.entries(MIGRATION_HINTS)) {
    if (queryLower.includes(k)) hints.push(`🔁 迁移建议：'${k}' → '${v.replacement}'（${v.hint}）`);
  }
  return hints;
}

// ── 搜索文档（关键词 or 混合）────────────────────────────────────────────────

async function searchDocs(query: string, limit: number = 10): Promise<string> {
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
async function getDoc(filename: string): Promise<string> {
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
const browseCategories = (category?: string) => browseDocuments(category, buildIndex);

// 创建MCP服务器
export const server = new Server(
  {
    name: "knowledge-mcp",
    version: "2.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// 注册工具列表
server.setRequestHandler(ListToolsRequestSchema, async () => {
  // 确保插件已初始化
  await buildIndex();

  // 核心工具（与域无关）
  const coreTools = CORE_TOOL_DEFINITIONS;

  // 插件工具动态追加（插件未加载时为空）
  const pluginTools = activePlugin?.getToolDefinitions() ?? [];

  return { tools: [...coreTools, ...pluginTools] };
});

// 处理工具调用
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    const { name, arguments: args } = request.params;

    switch (name) {
      case "smart_query": {
        const { query, mode = "quick" } = args as { query: string; mode?: "quick" | "detailed" };
        
        // 确保索引和引擎已初始化
        await buildIndex();
        const engine = queryEngine!;

        // 执行智能查询
        const result = await engine.query(query, mode);
        
        // 格式化输出
        let output = `🔍 智能查询结果\n${"=".repeat(60)}\n\n`;
        output += `📝 查询: ${query}\n`;
        output += `⚙️ 模式: ${result.type === "quick" ? "精简" : "详细"}\n`;
        output += `📊 预计token: ~${result.estimatedTokens}\n\n`;
        output += `${"─".repeat(60)}\n\n`;
        
        output += `💡 答案:\n${result.answer}\n\n`;
        
        if (result.syntax) {
          output += `📐 语法:\n${result.syntax}\n\n`;
        }
        
        if (result.parameters) {
          output += `📋 参数:\n${result.parameters}\n\n`;
        }
        
        if (result.returns) {
          output += `↩️ 返回值:\n${result.returns}\n\n`;
        }
        
        if (result.code || result.example) {
          output += `💻 示例代码:\n${result.code || result.example}\n\n`;
        }
        
        if (result.notes && result.notes.length > 0) {
          output += `⚠️ 注意事项:\n`;
          result.notes.forEach((note, i) => {
            output += `${i + 1}. ${note}\n`;
          });
          output += `\n`;
        }
        
        output += `📚 参考文档: ${result.reference}\n`;
        
        if (result.relatedDocs && result.relatedDocs.length > 0) {
          output += `\n🔗 相关文档:\n`;
          result.relatedDocs.forEach((doc) => {
            output += `  • ${doc}\n`;
          });
        }
        
        return { content: [{ type: "text", text: output }] };
      }

      case "search": {
        const { query, limit = 10 } = args as { query: string; limit?: number };
        const result = await searchDocs(query, limit);
        return { content: [{ type: "text", text: result }] };
      }

      case "get": {
        const { filename } = args as { filename: string };
        const result = await getDoc(filename);
        return { content: [{ type: "text", text: result }] };
      }

      case "browse": {
        const { category } = args as { category?: string };
        const result = await browseCategories(category);
        return { content: [{ type: "text", text: result }] };
      }

      case "log_error": {
        const { error_code, error_message, file_path, solution, related_docs } = args as {
          error_code: string;
          error_message: string;
          file_path?: string;
          solution?: string;
          related_docs?: string;
        };

        const errorDb = getErrorDb();
        const record = errorDb.addError({
          error_code,
          error_message,
          file_path,
          solution,
          related_docs,
        });

        let output = `✅ 错误已记录到数据库\n${"=".repeat(60)}\n\n`;
        output += `📋 错误代码: ${record.error_code}\n`;
        output += `📝 错误消息: ${record.error_message}\n`;
        output += `🔢 出现次数: ${record.occurrence_count}\n`;
        output += `📅 首次遇到: ${record.first_seen}\n`;
        output += `📅 最后遇到: ${record.last_seen}\n`;
        
        if (record.solution) {
          output += `\n💡 解决方案:\n${record.solution}\n`;
        }
        
        if (record.related_docs) {
          output += `\n📚 相关文档:\n${record.related_docs}\n`;
        }

        output += `\n💾 数据库位置: ${errorDb.getStats().dbPath}`;

        return { content: [{ type: "text", text: output }] };
      }

      case "list_common_errors": {
        const { limit = 10 } = args as { limit?: number };

        const errorDb = getErrorDb();
        const commonErrors = errorDb.listCommonErrors(limit);

        if (commonErrors.length === 0) {
          return { 
            content: [{ 
              type: "text", 
              text: "📊 错误数据库为空\n\n💡 提示: 使用 log_error 工具记录遇到的编译错误" 
            }] 
          };
        }

        let output = `📊 最常见的MQL5编译错误 (TOP ${commonErrors.length})\n${"=".repeat(60)}\n\n`;

        commonErrors.forEach((error, index) => {
          output += `${index + 1}. ${error.error_code} - ${error.error_message}\n`;
          output += `   🔢 出现次数: ${error.occurrence_count}\n`;
          output += `   📅 最后遇到: ${error.last_seen}\n`;
          
          if (error.solution) {
            const shortSolution = error.solution.length > 100 
              ? error.solution.substring(0, 100) + "..." 
              : error.solution;
            output += `   💡 解决方案: ${shortSolution}\n`;
          }
          
          output += `\n`;
        });

        const stats = errorDb.getStats();
        output += `${"─".repeat(60)}\n`;
        output += `📈 统计信息:\n`;
        output += `  • 总错误类型: ${stats.totalErrors}\n`;
        output += `  • 总出现次数: ${stats.totalOccurrences}\n`;
        output += `  • 数据库位置: ${stats.dbPath}\n`;

        return { content: [{ type: "text", text: output }] };
      }

      case "manage_error_db": {
        const { action, data, anonymize = false } = args as {
          action: "export" | "import" | "stats";
          data?: string;
          anonymize?: boolean;
        };

        const errorDb = getErrorDb();

        if (action === "export") {
          const jsonData = errorDb.exportErrors(anonymize);
          let output = `📤 错误数据库导出成功\n${"=".repeat(60)}\n\n`;
          
          if (anonymize) {
            output += `🔒 隐私模式: 已移除文件路径信息\n\n`;
          }
          
          output += `📊 导出数据:\n`;
          output += `\`\`\`json\n${jsonData}\n\`\`\`\n\n`;
          output += `💡 提示: 复制上述JSON数据，使用 manage_error_db(action="import") 导入到其他系统`;

          return { content: [{ type: "text", text: output }] };
        }

        if (action === "import") {
          if (!data) {
            return {
              content: [{ type: "text", text: "❌ 错误: 导入操作需要提供 data 参数（JSON格式）" }],
              isError: true,
            };
          }

          try {
            const result = errorDb.importErrors(data);
            let output = `📥 错误数据库导入完成\n${"=".repeat(60)}\n\n`;
            output += `✅ 新导入: ${result.imported} 条\n`;
            output += `🔄 已更新: ${result.updated} 条\n`;
            
            if (result.errors > 0) {
              output += `⚠️ 失败: ${result.errors} 条\n`;
            }
            
            const stats = errorDb.getStats();
            output += `\n📈 当前数据库统计:\n`;
            output += `  • 总错误类型: ${stats.totalErrors}\n`;
            output += `  • 总出现次数: ${stats.totalOccurrences}\n`;

            return { content: [{ type: "text", text: output }] };
          } catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            return {
              content: [{ type: "text", text: `❌ 导入失败: ${message}` }],
              isError: true,
            };
          }
        }

        if (action === "stats") {
          const stats = errorDb.getStats();
          let output = `📈 错误数据库统计信息\n${"=".repeat(60)}\n\n`;
          output += `📊 数据统计:\n`;
          output += `  • 总错误类型: ${stats.totalErrors}\n`;
          output += `  • 总出现次数: ${stats.totalOccurrences}\n`;
          output += `  • 平均每错误: ${stats.totalErrors > 0 ? (stats.totalOccurrences / stats.totalErrors).toFixed(1) : 0} 次\n\n`;
          output += `💾 数据库信息:\n`;
          output += `  • 位置: ${stats.dbPath}\n\n`;
          output += `💡 提示:\n`;
          output += `  • 使用 list_common_errors 查看高频错误\n`;
          output += `  • 使用 manage_error_db(action="export") 导出错误库\n`;
          output += `  • 使用 smart_query 查询错误时会自动从数据库搜索`;

          return { content: [{ type: "text", text: output }] };
        }

        throw new Error(`未知操作: ${action}`);
      }

      case "build_semantic_index": {
        const { force_reindex = false, limit: docLimit } = args as {
          force_reindex?: boolean;
          limit?: number;
        };

        const embCfg = await getEmbeddingConfig();
        if (!embCfg) {
          return {
            content: [{ type: "text", text: [
              "❌ 未配置 embedding。请在 ~/.knowledge-mcp/config.json 中添加：",
              "```json",
              '{',
              '  "embedding": {',
              '    "provider": "ollama",',
              '    "model": "nomic-embed-text",',
              '    "url": "http://localhost:11434"',
              '  }',
              '}',
              "```",
              "",
              "然后安装 Ollama：https://ollama.ai  并运行：",
              "  ollama pull nomic-embed-text",
            ].join("\n") }],
            isError: true,
          };
        }

        // 检查 Ollama 是否在线
        const healthy = await ollamaHealthCheck(embCfg.url);
        if (!healthy) {
          return {
            content: [{ type: "text", text: `❌ Ollama 服务不可达 (${embCfg.url})\n\n请确认 Ollama 已启动：ollama serve` }],
            isError: true,
          };
        }

        if (force_reindex) {
          vectorStore.deleteAll();
        }

        await buildIndex();
        const allEntries = [...docIndex!.entries()];
        const toIndex = allEntries.filter(([key]) => !vectorStore.hasKey(key));
        const limited = docLimit ? toIndex.slice(0, docLimit) : toIndex;

        if (limited.length === 0) {
          const stats = vectorStore.getStats();
          return {
            content: [{ type: "text", text: `✅ 所有文档已有索引（共 ${stats.count} 个）。使用 force_reindex=true 强制重建。` }],
          };
        }

        const lines: string[] = [
          `🔮 开始构建语义索引`,
          `   模型: ${embCfg.model}  服务: ${embCfg.url}`,
          `   待处理: ${limited.length} 个文档（已有 ${vectorStore.count()} 个）`,
          "",
        ];

        let succeeded = 0, skipped = 0, failed = 0;
        const t0 = Date.now();

        for (let i = 0; i < limited.length; i++) {
          const [key, entry] = limited[i];

          // 进度日志每50个输出一次
          if (i > 0 && i % 50 === 0) {
            lines.push(`  [${i}/${limited.length}] 已处理 ${succeeded} 成功, ${failed} 失败...`);
          }

          try {
            const raw = await readFileText(entry.absPath);
            const text = extractTextForEmbedding(raw, entry.absPath);
            if (text.length < 30) { skipped++; continue; }

            const embedding = await ollamaEmbed(embCfg.url, embCfg.model, text);
            if (!embedding) { failed++; continue; }

            vectorStore.upsert(key, entry.absPath, embedding, {
              preview: text.substring(0, 120),
              model: embCfg.model,
            });
            succeeded++;
          } catch { failed++; }
        }

        const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
        lines.push(`✅ 完成！耗时 ${elapsed}s`);
        lines.push(`   成功: ${succeeded}  跳过: ${skipped}  失败: ${failed}`);
        lines.push(`   向量库总量: ${vectorStore.count()} 个文档`);
        lines.push("");
        lines.push("现在 search / smart_query 将自动使用混合搜索模式（中文查询可命中英文文档）。");

        return { content: [{ type: "text", text: lines.join("\n") }] };
      }

      case "list_libraries": {
        await buildIndex();

        let out = `📚 已加载资料库\n${"=".repeat(60)}\n\n`;
        out += `配置文件: ${CONFIG_PATH}\n\n`;

        const builtin = loadedLibraries.filter(l =>
          BUILTIN_ROOTS.some(b => b.key === l.key)
        );
        const external = loadedLibraries.filter(l =>
          !BUILTIN_ROOTS.some(b => b.key === l.key)
        );

        out += `📖 内置库 (${builtin.length}):\n`;
        for (const lib of builtin) {
          out += `  • ${lib.key.padEnd(22)} ${lib.fileCount} 个文件\n`;
        }

        out += `\n🔌 外部库 (${external.length}):\n`;
        if (external.length === 0) {
          out += `  （未配置）\n\n`;
          out += `💡 在 ${CONFIG_PATH} 中添加：\n`;
          out += `\`\`\`json\n`;
          out += `{\n  "extraLibraries": [\n`;
          out += `    { "key": "MyLib", "path": "/path/to/library", "description": "说明" }\n`;
          out += `  ]\n}\n\`\`\`\n`;
          out += `\n支持文件类型：.htm .html .md .mq5 .mqh\n`;
          out += `搜索外部库文件使用前缀，如 search("mylib_filename")`;
        } else {
          for (const lib of external) {
            out += `  • ${lib.key.padEnd(22)} ${lib.fileCount} 个文件  ${lib.absPath}\n`;
            if (lib.description && lib.description !== "外部库") {
              out += `    ${lib.description}\n`;
            }
          }
          out += `\n💡 搜索外部库文件可加前缀，如 search("${external[0].key.toLowerCase()}_filename")`;
        }

        return { content: [{ type: "text", text: out }] };
      }

      case "preprocess_library": {
        const { library_key } = args as { library_key?: string };

        const apiKey = process.env.ANTHROPIC_API_KEY;
        if (!apiKey) {
          return {
            content: [{
              type: "text",
              text: "❌ 未设置 ANTHROPIC_API_KEY 环境变量。\n\n请在启动 MCP server 前设置：\n  export ANTHROPIC_API_KEY=sk-ant-...",
            }],
            isError: true,
          };
        }

        await buildIndex();
        const preprocessor = new LibraryPreprocessor(apiKey, knowledgeStore);

        // 确定要处理的库
        const targets = loadedLibraries.filter(lib => {
          const isExternal = !BUILTIN_ROOTS.some(b => b.key === lib.key);
          if (!isExternal) return false;
          if (library_key) return lib.key === library_key;
          return true;
        });

        if (targets.length === 0) {
          return {
            content: [{
              type: "text",
              text: library_key
                ? `❌ 未找到外部库 "${library_key}"，请检查 config.json 中的 key。`
                : "❌ 未配置任何外部库，请先在 ~/.knowledge-mcp/config.json 中添加 extraLibraries。",
            }],
            isError: true,
          };
        }

        const logLines: string[] = [`🤖 开始预处理外部库（模型: claude-haiku）\n`];

        for (const lib of targets) {
          const files = externalLibFiles.get(lib.key) ?? [];
          const report = await preprocessor.processLibrary(
            lib.key,
            files,
            msg => logLines.push(msg)
          );
          logLines.push(
            `\n✅ ${lib.key} 完成：新处理 ${report.processed} 个，已缓存 ${report.cached} 个，失败 ${report.failed} 个`
          );
          logLines.push(`💰 本次 API 消耗估算: ${report.totalCost}`);
        }

        logLines.push("\n📌 知识已缓存到本地，后续 analyze_code 零 API 成本。");
        return { content: [{ type: "text", text: logLines.join("\n") }] };
      }

      case "analyze_code": {
        const { code, library_key } = args as { code: string; library_key?: string };

        await buildIndex();

        const externalLibKeys = loadedLibraries
          .filter(lib => !BUILTIN_ROOTS.some(b => b.key === lib.key))
          .filter(lib => !library_key || lib.key === library_key)
          .map(lib => lib.key);

        if (externalLibKeys.length === 0) {
          return {
            content: [{
              type: "text",
              text: "❌ 未找到可分析的外部库。请先：\n1. 在 config.json 中配置 extraLibraries\n2. 运行 preprocess_library 生成本地知识缓存",
            }],
            isError: true,
          };
        }

        const ctx = await contextAssembler.assemble(code, externalLibKeys);

        if (!ctx.hasKnowledge) {
          return {
            content: [{
              type: "text",
              text: `❌ 未找到预处理的库知识。\n\n请先运行：preprocess_library${library_key ? `("${library_key}")` : "()"}\n\n这会调用 Claude Haiku 分析库文件并缓存到本地（一次性操作）。`,
            }],
            isError: true,
          };
        }

        const out: string[] = [
          "🧠 代码分析上下文",
          "=".repeat(60),
          "",
          `📋 用户代码 (${code.split("\n").length} 行):`,
          "```mql5",
          code.length > 3000 ? code.substring(0, 3000) + "\n// ...(已截断)" : code,
          "```",
          "",
          ctx.libraryAPISummary,
        ];

        if (ctx.detectedPatterns.length > 0) {
          out.push(`\n🔍 自动检测到 ${ctx.detectedPatterns.length} 处可优化点（已包含在上方摘要中）`);
        }

        // 查询本地 fix patterns DB，附上已知修复提示
        const knownFixes = fixPatternsDb.search(code.substring(0, 500));
        if (knownFixes.length > 0) {
          out.push("\n📚 本地已记录的相关修复模式（无需 API）:");
          for (const fix of knownFixes.slice(0, 3)) {
            out.push(`  • [${fix.usage_count}次] ${fix.pattern_description}`);
            out.push(`    → ${fix.fix_description}`);
            if (fix.fixed_snippet) {
              out.push(`    修复示例:\n\`\`\`mql5\n${fix.fixed_snippet}\n\`\`\``);
            }
          }
        }

        out.push("\n" + "─".repeat(60));
        out.push("💡 请根据以上库知识和用户代码，给出具体可编译的改进建议。");

        return { content: [{ type: "text", text: out.join("\n") }] };
      }

      case "record_fix": {
        const { pattern_description, fix_description, original_snippet, fixed_snippet, library_key: lk, tags } = args as {
          pattern_description: string;
          fix_description: string;
          original_snippet?: string;
          fixed_snippet?: string;
          library_key?: string;
          tags?: string;
        };

        const saved = fixPatternsDb.record({
          pattern_description,
          fix_description,
          original_snippet,
          fixed_snippet,
          library_key: lk,
          tags,
        });

        return {
          content: [{
            type: "text",
            text: `✅ 修复模式已保存 (ID: ${saved.id ?? "已更新"}, 使用次数: ${saved.usage_count})\n\n**问题:** ${saved.pattern_description}\n**修复:** ${saved.fix_description}`,
          }],
        };
      }

      case "list_fixes": {
        const { query, limit = 20 } = args as { query?: string; limit?: number };

        if (query) {
          const results = fixPatternsDb.search(query);
          if (results.length === 0) {
            return { content: [{ type: "text", text: `🔍 未找到匹配 "${query}" 的修复模式` }] };
          }
          const lines = [`🔍 搜索 "${query}" 的结果 (${results.length} 条):\n`];
          for (const r of results) {
            lines.push(`**[${r.usage_count}次] ${r.pattern_description}**`);
            lines.push(`→ ${r.fix_description}`);
            if (r.library_key) lines.push(`库: ${r.library_key}`);
            if (r.tags) lines.push(`标签: ${r.tags}`);
            if (r.fixed_snippet) lines.push("```mql5\n" + r.fixed_snippet + "\n```");
            lines.push("---");
          }
          return { content: [{ type: "text", text: lines.join("\n") }] };
        }

        const all = fixPatternsDb.list(limit);
        if (all.length === 0) {
          return {
            content: [{ type: "text", text: "📭 暂无已记录的修复模式。使用 record_fix 工具开始记录。" }],
          };
        }
        const stats = fixPatternsDb.getStats();
        const lines = [`📋 本地修复模式库 (共 ${stats.total} 条, 累计使用 ${stats.totalUsage ?? 0} 次)\n`];
        for (const r of all) {
          lines.push(`**#${r.id} [${r.usage_count}次] ${r.pattern_description}**`);
          lines.push(`→ ${r.fix_description}`);
          if (r.library_key) lines.push(`库: ${r.library_key}`);
          lines.push("---");
        }
        return { content: [{ type: "text", text: lines.join("\n") }] };
      }

      case "manage_knowledge": {
        const { action, library_key: lk, file_path: fp, import_as } = args as {
          action: "export" | "import" | "stats";
          library_key?: string;
          file_path?: string;
          import_as?: string;
        };

        if (action === "export") {
          if (!lk) {
            return { content: [{ type: "text", text: "❌ export 操作需要提供 library_key" }], isError: true };
          }
          const result = await knowledgeStore.exportLibrary(lk);
          if (result.fileCount === 0) {
            return {
              content: [{ type: "text", text: `❌ 库 "${lk}" 尚无已预处理的知识。请先运行 preprocess_library("${lk}")。` }],
              isError: true,
            };
          }
          return {
            content: [{
              type: "text",
              text: [
                `✅ 已导出库 "${lk}" 的知识包`,
                `   文件数: ${result.fileCount}  类数: ${result.classCount}`,
                `   路径: ${result.filePath}`,
                "",
                "**分享方式:**",
                `1. 将 \`${result.filePath}\` 发送给团队成员`,
                `2. 对方运行: manage_knowledge(action="import", file_path="/path/to/${lk}.knowledge.json")`,
                "3. 对方无需配置 ANTHROPIC_API_KEY 或运行 preprocess_library，直接可用 analyze_code",
              ].join("\n"),
            }],
          };
        }

        if (action === "import") {
          if (!fp) {
            return { content: [{ type: "text", text: "❌ import 操作需要提供 file_path（.knowledge.json 文件的绝对路径）" }], isError: true };
          }
          const result = await knowledgeStore.importLibrary(fp, import_as);
          return {
            content: [{
              type: "text",
              text: [
                `✅ 知识包导入完成 → 库: "${result.libraryKey}"`,
                `   新增: ${result.imported} 个文件`,
                `   已跳过（已存在）: ${result.skipped}`,
                `   失败: ${result.errors}`,
                "",
                result.imported > 0
                  ? `现在可以直接运行 analyze_code(code, "${result.libraryKey}") 使用导入的知识。`
                  : "提示：若全部跳过，说明该库知识已存在。可删除 ~/.knowledge-mcp/knowledge/${result.libraryKey}/ 后重新导入。",
              ].join("\n"),
            }],
          };
        }

        // action === "stats"
        await buildIndex();
        const libKeys = loadedLibraries
          .filter(lib => !BUILTIN_ROOTS.some(b => b.key === lib.key))
          .map(lib => lib.key);

        if (libKeys.length === 0) {
          return { content: [{ type: "text", text: "📊 暂无外部库（仅有内置 MQL5 文档）。在 config.json 中配置 extraLibraries 后重启。" }] };
        }

        const statsArr = await knowledgeStore.stats(libKeys);
        const lines = ["📊 库知识统计:\n"];
        for (const s of statsArr) {
          const statusIcon = s.fileCount > 0 ? "✅" : "⬜";
          lines.push(`${statusIcon} **${s.key}**: ${s.fileCount} 个文件已分析, ${s.classCount} 个类`);
          if (s.fileCount === 0) {
            lines.push(`   → 运行 preprocess_library("${s.key}") 开始预处理`);
          }
        }
        const fixStats = fixPatternsDb.getStats();
        lines.push(`\n💾 **本地修复模式库**: ${fixStats.total} 条记录`);

        return { content: [{ type: "text", text: lines.join("\n") }] };
      }

      default: {
        // 路由给领域插件
        if (activePlugin) {
          const pluginToolNames = activePlugin.getToolDefinitions().map(t => t.name);
          if (pluginToolNames.includes(name)) {
            await buildIndex();
            const r = await activePlugin.handleToolCall(name, args, {
              docIndex: docIndex!,
              knowledgeStore,
              fixPatternsDb,
              loadedLibraries: loadedLibraries.map(l => ({
                key: l.key,
                fileCount: l.fileCount,
                rootPath: l.absPath,
              })),
            });
            // 解构为对象字面量，让 TS 推断为 MCP SDK 兼容类型
            return { content: r.content, isError: r.isError };
          }
        }
        throw new Error(`未知工具: ${name}`);
      }
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text: `❌ 错误: ${message}` }],
      isError: true,
    };
  }
});

// 启动服务器
async function main() {
  console.error("🚀 MQL5 Help MCP Server 启动中...");

  // Attach stdio before any startup I/O so an eager client can initialize
  // while the document index is being prepared.
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // 预构建索引，同时输出库信息
  await buildIndex();
  for (const lib of loadedLibraries) {
    const tag = BUILTIN_ROOTS.some(b => b.key === lib.key) ? "内置" : "外部";
    console.error(`📂 [${tag}] ${lib.key}: ${lib.fileCount} 个文件`);
  }
  if (loadedLibraries.length === 0) {
    console.error("📂 (无可用文档目录)");
  }

  // 初始化错误数据库
  const errorDb = getErrorDb();
  const stats = errorDb.getStats();
  console.error(`💾 错误数据库: ${stats.totalErrors} 条记录 (${stats.dbPath})`);

  console.error("✅ 服务器就绪，等待连接...");

  // 优雅退出时关闭数据库
  process.on('SIGINT', () => {
    console.error("🛑 正在关闭服务器...");
    closeErrorDb();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    console.error("🛑 正在关闭服务器...");
    closeErrorDb();
    process.exit(0);
  });

  // A piped stdin does not reliably keep Node's event loop alive on every
  // supported runtime. The client transport terminates us with SIGTERM when it
  // disconnects, so retain one event-loop handle for the server lifetime.
  setInterval(() => {}, 24 * 60 * 60 * 1000);
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  main().catch((error) => {
    console.error("❌ 启动失败:", error);
    closeErrorDb();
    process.exit(1);
  });
}
