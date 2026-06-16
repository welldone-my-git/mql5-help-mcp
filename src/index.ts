#!/usr/bin/env node

/**
 * MQL5 Help MCP Server
 * 文档/电子书一体化检索，基础迁移/错误提示
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
import { SmartQueryEngine } from "./smart-query.js";
import { getErrorDb, closeErrorDb } from "./error-db.js";
import { stripHtml } from "./utils.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 文档根目录（多资料库）：MQL5_HELP（官方）、两本电子书（可选）
const ROOT_CANDIDATES = [
  { key: "MQL5_HELP", abs: path.resolve(__dirname, "..", "MQL5_HELP") },
  { key: "MQL5_Algo_Book", abs: path.resolve(__dirname, "..", "MQL5_Algo_Book") },
  { key: "Neural_Networks_Book", abs: path.resolve(__dirname, "..", "Neural_Networks_Book") },
];

// 文档索引缓存
type DocEntry = { absPath: string; relPath: string; repo: string };
let docIndex: Map<string, DocEntry> | null = null; // key -> entry（key为检索键）
let nameIndex: Map<string, DocEntry> | null = null; // 文件名（无扩展）-> entry
let queryEngine: SmartQueryEngine | null = null;   // 单例，随索引一同初始化

// MQL4→MQL5 常见迁移映射/别名（用于智能搜索提示）
const MIGRATION_HINTS: Record<string, { replacement: string; hint: string; targetKeys: string[] }> = {
  "resultcode": {
    replacement: "ResultRetcode",
    hint: "CTrade 结果方法在 MQL5 中改为 ResultRetcode()",
    targetKeys: ["ctrade", "trade"],
  },
  "symbol()": {
    replacement: "_Symbol",
    hint: "预定义变量由 Symbol() 迁移为 _Symbol",
    targetKeys: ["_symbol", "symbol"],
  },
  "period()": {
    replacement: "_Period",
    hint: "预定义变量由 Period() 迁移为 _Period",
    targetKeys: ["_period", "period"],
  },
  "ima": {
    replacement: "IndicatorCreate",
    hint: "iMA 在 MQL5 中通常通过 IndicatorCreate 构建",
    targetKeys: ["indicatorcreate", "icustom"],
  },
};

// 递归读取目录下的文件
async function walkDir(rootAbs: string, repoKey: string, baseRel = ""): Promise<DocEntry[]> {
  const entries: DocEntry[] = [];
  let dirents;
  try {
    dirents = await fs.readdir(path.join(rootAbs, baseRel), { withFileTypes: true });
  } catch {
    return entries; // 目录不存在则跳过
  }

  for (const d of dirents) {
    const relPath = path.join(baseRel, d.name);
    const absPath = path.join(rootAbs, relPath);
    if (d.isDirectory()) {
      const sub = await walkDir(rootAbs, repoKey, relPath);
      entries.push(...sub);
    } else if (/\.(htm|html|md)$/i.test(d.name)) {
      entries.push({ absPath, relPath, repo: repoKey });
    }
  }
  return entries;
}

// 构建文档索引（多根目录、递归）
async function buildIndex(): Promise<Map<string, DocEntry>> {
  if (docIndex) return docIndex;

  docIndex = new Map();
  nameIndex = new Map();

  // 构建有效根目录列表
  const roots: { key: string; abs: string }[] = [];
  for (const c of ROOT_CANDIDATES) {
    try { await fs.access(c.abs); roots.push({ key: c.key, abs: c.abs }); } catch {}
  }

  // 遍历并索引
  for (const r of roots) {
    const files = await walkDir(r.abs, r.key);
    for (const f of files) {
      const base = path.basename(f.relPath).toLowerCase();
      const noExt = base.replace(/\.(htm|html|md)$/i, "");

      // 主键：文件名（无扩展）— first-wins 保证 MQL5_HELP 优先
      if (!docIndex.has(noExt)) docIndex.set(noExt, f);
      if (!nameIndex.has(noExt)) nameIndex.set(noExt, f);

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

      // 电子书目录粗粒度前缀（专用命名空间，无冲突风险）
      if (f.repo === "MQL5_Algo_Book") docIndex.set(`algo_${noExt}`, f);
      if (f.repo === "Neural_Networks_Book") docIndex.set(`nn_${noExt}`, f);
    }
  }

  console.error(`📚 索引已建立: ${docIndex.size} 个键，${nameIndex.size} 个文件名索引`);
  queryEngine = new SmartQueryEngine(docIndex);
  return docIndex;
}

// 搜索文档（含错误文本与迁移提示）
async function searchDocs(query: string, limit: number = 10): Promise<string> {
  const index = await buildIndex();
  const queryLower = query.toLowerCase();

  // 智能错误识别（undeclared identifier ...）
  const smartHints: string[] = [];
  const undeclaredMatch = queryLower.match(/undeclared\s+identifier\s+'?"?([a-z_][a-z0-9_]*)'?"?/i) ||
                          queryLower.match(/undeclared\s+identifier\s+([a-z_][a-z0-9_]*)/i);
  if (undeclaredMatch && undeclaredMatch[1]) {
    const missing = undeclaredMatch[1].toLowerCase();
    if (MIGRATION_HINTS[missing]) {
      const h = MIGRATION_HINTS[missing];
      smartHints.push(`🩺 诊断：未声明标识符 '${missing}' → 可能应改为 '${h.replacement}'（${h.hint}）`);
    }
  }

  // 迁移建议（直接包含左侧关键词时）
  for (const [k, v] of Object.entries(MIGRATION_HINTS)) {
    if (queryLower.includes(k)) smartHints.push(`🔁 迁移建议：'${k}' → '${v.replacement}'（${v.hint}）`);
  }

  // 精确匹配
  const exact = index.get(queryLower);

  // 模糊匹配 + 迁移目标扩展
  const expansionKeys = new Set<string>();
  for (const [k, v] of Object.entries(MIGRATION_HINTS)) {
    if (queryLower.includes(k)) v.targetKeys.forEach((t) => expansionKeys.add(t));
  }
  if (undeclaredMatch && undeclaredMatch[1]) {
    const m = undeclaredMatch[1].toLowerCase();
    if (MIGRATION_HINTS[m]) MIGRATION_HINTS[m].targetKeys.forEach((t) => expansionKeys.add(t));
  }

  const results: Array<{ entry: DocEntry; key: string; score: number }> = [];
  for (const [key, entry] of index.entries()) {
    let matched = false;
    let score = 0;
    if (key === queryLower) { matched = true; score = 1.0; }
    else if (key.includes(queryLower)) { matched = true; score = queryLower.length / Math.max(2, key.length); }
    else if (expansionKeys.has(key)) { matched = true; score = 0.95; }
    if (matched) results.push({ entry, key, score });
  }
  results.sort((a, b) => b.score - a.score);

  let out = `🔍 搜索: "${query}"\n\n`;
  if (smartHints.length) out += smartHints.map((s) => `• ${s}`).join("\n") + "\n\n";
  if (exact) out += `✅ 精确匹配: ${exact.relPath}  (来源: ${exact.repo})\n\n`;

  if (results.length > 0) {
    out += `📋 相关文档 (${Math.min(results.length, limit)} / ${results.length})：\n`;
    results.slice(0, limit).forEach((m, i) => {
      out += `  ${i + 1}. ${m.entry.relPath}  (${m.entry.repo})\n`;
    });
  } else if (!exact) {
    out += `❌ 未找到匹配文档\n`;
    out += `💡 提示: 使用英文关键字，如 OrderSend, CopyBuffer；或尝试更短关键词`;
  }

  return out;
}

// 读取文档内容（多目录）
async function getDoc(filename: string): Promise<string> {
  const index = await buildIndex();
  const raw = filename.trim();
  const lower = raw.toLowerCase();

  // 1) 优先按 key（无扩展）
  let entry = index.get(lower.replace(/\.(htm|html|md)$/i, ""));

  // 2) 按文件名（无扩展）
  if (!entry && nameIndex) {
    const nameKey = path.basename(lower).replace(/\.(htm|html|md)$/i, "");
    entry = nameIndex.get(nameKey) || undefined;
  }

  if (!entry) {
    const search = await searchDocs(filename, 5);
    return `❌ 未找到文件: ${filename}\n\n${search}`;
  }

  try {
    const content = await fs.readFile(entry.absPath, "utf-8");
    const isMd = /\.(md)$/i.test(entry.absPath);

    if (isMd) {
      const truncated = content.length > 15000 ? content.substring(0, 15000) + "\n\n... (内容过长，已截断)" : content;
      return `📄 ${entry.relPath} (${entry.repo})\n${"=".repeat(60)}\n\n${truncated}\n\n${"=".repeat(60)}`;
    }

    const text = stripHtml(content);
    const truncated = text.length > 10000 ? text.substring(0, 10000) + "..." : text;
    return `📄 ${entry.relPath} (${entry.repo})\n${"=".repeat(60)}\n\n${truncated}\n\n${"=".repeat(60)}`;
  } catch (error) {
    return `❌ 读取失败: ${error}`;
  }
}

// 浏览分类（仍以官方主题分类为主）
function browseCategories(category?: string): string {
  const categories: Record<string, string[]> = {
    trading: ["ordersend", "ordercheck", "ctrade", "positionselect"],
    indicators: ["icustom", "copybuffer", "indicatorcreate", "setindexbuffer"],
    math: ["mathabs", "mathsin", "mathcos", "mathrandom", "mathpow"],
    array: ["arrayresize", "arraycopy", "arraysort", "arrayinitialize"],
    string: ["stringfind", "stringsplit", "stringreplace", "stringformat"],
    datetime: ["timecurrent", "timelocal", "timetostruct", "timegmt"],
    files: ["fileopen", "fileclose", "filewrite", "fileread"],
    chart: ["chartopen", "chartredraw", "chartid", "chartsetinteger"],
    objects: ["objectcreate", "objectdelete", "objectsetinteger"],
    onnx: ["onnxcreate", "onnxrun", "onnxrelease", "MQL5_ONNX_Integration_Guide"],
  };

  if (!category) {
    let result = "📚 MQL5 文档分类\n" + "=".repeat(60) + "\n\n";
    for (const [cat, docs] of Object.entries(categories)) {
      result += `📁 ${cat}: ${docs.length} 个文档\n`;
    }
    result += "\n💡 使用 category 参数查看具体分类";
    return result;
  }

  const docs = categories[category.toLowerCase()];
  if (!docs) {
    return `❌ 未知分类: ${category}\n\n可用: ${Object.keys(categories).join(", ")}`;
  }

  let result = `📁 ${category.toUpperCase()}\n${"=".repeat(60)}\n\n`;
  docs.forEach((doc) => {
    result += `  • ${doc}.htm\n`;
  });
  return result;
}

// 创建MCP服务器
const server = new Server(
  {
    name: "mql5-help-mcp",
    version: "1.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// 注册工具列表
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "smart_query",
        description: "🎯 智能查询工具（推荐）：输入错误信息、函数名或问题，自动搜索并返回精简答案。完全本地化，零API成本，节省80%+ token。适用于：错误诊断、函数查询、快速学习。",
        inputSchema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "查询内容：1) 错误信息如 'error 256: undeclared identifier ResultCode' 2) 函数名如 'OrderSend' 3) 类名如 'CTrade' 4) 问题如 'how to send order'",
            },
            mode: {
              type: "string",
              enum: ["quick", "detailed"],
              description: "返回模式: quick=精简答案(~500 tokens,推荐), detailed=详细说明(~1500 tokens)",
              default: "quick",
            },
          },
          required: ["query"],
        },
      },
      {
        name: "search",
        description: "搜索MQL5文档（函数名、类名、关键字）。返回文档列表，需再调用get获取内容。如需直接答案请用smart_query。",
        inputSchema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "搜索关键词或错误文本",
            },
            limit: {
              type: "number",
              description: "返回结果数量",
              default: 10,
            },
          },
          required: ["query"],
        },
      },
      {
        name: "get",
        description: "获取指定文档的详细内容（完整HTML，~3000 tokens）。如需精简答案请用smart_query。",
        inputSchema: {
          type: "object",
          properties: {
            filename: {
              type: "string",
              description: "文档名（可不带扩展）",
            },
          },
          required: ["filename"],
        },
      },
      {
        name: "browse",
        description: "浏览文档分类目录",
        inputSchema: {
          type: "object",
          properties: {
            category: {
              type: "string",
              description: "分类名（可选）: trading, indicators, math, array, string, datetime, files, chart, objects, onnx",
            },
          },
        },
      },
      {
        name: "log_error",
        description: "📝 记录MQL5编译错误到本地数据库。用于收集常见错误及解决方案，下次遇到相同错误时可快速查询。",
        inputSchema: {
          type: "object",
          properties: {
            error_code: {
              type: "string",
              description: "错误代码（如 E512, E308）",
            },
            error_message: {
              type: "string",
              description: "完整错误消息",
            },
            file_path: {
              type: "string",
              description: "发生错误的文件路径（可选，隐私考虑）",
            },
            solution: {
              type: "string",
              description: "解决方案描述（可选）",
            },
            related_docs: {
              type: "string",
              description: "相关文档列表，JSON数组格式（可选）",
            },
          },
          required: ["error_code", "error_message"],
        },
      },
      {
        name: "list_common_errors",
        description: "📊 列出最常见的MQL5编译错误（按出现频率排序）。帮助快速了解常见问题。",
        inputSchema: {
          type: "object",
          properties: {
            limit: {
              type: "number",
              description: "返回错误数量（默认10）",
              default: 10,
            },
          },
        },
      },
      {
        name: "manage_error_db",
        description: "🔧 管理错误数据库：导出/导入错误记录，查看数据库统计信息。支持团队共享错误库。",
        inputSchema: {
          type: "object",
          properties: {
            action: {
              type: "string",
              enum: ["export", "import", "stats"],
              description: "操作类型：export=导出为JSON, import=从JSON导入, stats=查看统计",
            },
            data: {
              type: "string",
              description: "导入时的JSON数据（action=import时必需）",
            },
            anonymize: {
              type: "boolean",
              description: "导出时是否移除文件路径（保护隐私，默认false）",
              default: false,
            },
          },
          required: ["action"],
        },
      },
    ],
  };
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
        const result = browseCategories(category);
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

      default:
        throw new Error(`未知工具: ${name}`);
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

  const rootsInfo: string[] = [];
  for (const c of ROOT_CANDIDATES) {
    try { await fs.access(c.abs); rootsInfo.push(`${c.key}:${c.abs}`); } catch {}
  }
  console.error(`📂 文档目录: ${rootsInfo.join(" | ") || "(无可用目录)"}`);

  // 初始化错误数据库
  const errorDb = getErrorDb();
  const stats = errorDb.getStats();
  console.error(`💾 错误数据库: ${stats.totalErrors} 条记录 (${stats.dbPath})`);

  const transport = new StdioServerTransport();
  await server.connect(transport);

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
}

main().catch((error) => {
  console.error("❌ 启动失败:", error);
  closeErrorDb();
  process.exit(1);
});
