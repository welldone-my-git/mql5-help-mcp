import type { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs/promises";
import { homedir } from "os";
import { getErrorDb } from "../error-db.js";
import { LibraryPreprocessor, knowledgeStore, contextAssembler } from "../library-knowledge.js";
import { fixPatternsDb } from "../fix-patterns.js";
import { vectorStore, ollamaEmbed, ollamaHealthCheck, extractTextForEmbedding } from "./embedding.js";
import { CORE_TOOL_DEFINITIONS } from "./tool-definitions.js";
import { browseDocuments } from "./browse.js";
import { readFileText } from "./ingestion.js";
import {
  BUILTIN_ROOTS, CONFIG_PATH, getEmbeddingConfig,
} from "./config.js";
import {
  activePlugin, buildIndex, docIndex,
  externalLibFiles, getDoc, loadedLibraries,
  queryEngine, searchDocs,
} from "./document-service.js";
import {
  formatSmartQuery, formatLogError, formatListCommonErrors,
  formatErrorDbExport, formatErrorDbImport, formatErrorDbStats,
  formatListLibraries, formatAnalyzeCode, formatRecordFix,
  formatListFixesSearch, formatListFixesAll,
  formatKnowledgeExport, formatKnowledgeImport, formatKnowledgeStats,
} from "./tool-formatters.js";

export function registerToolHandlers(server: Server): void {
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
          
          return { content: [{ type: "text", text: formatSmartQuery(query, result) }] };
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
          const result = await browseDocuments(category, buildIndex);
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
  
          return { content: [{ type: "text", text: formatLogError(record, errorDb.getStats().dbPath) }] };
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

          const stats = errorDb.getStats();
          return { content: [{ type: "text", text: formatListCommonErrors(commonErrors, stats) }] };
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
            return { content: [{ type: "text", text: formatErrorDbExport(jsonData, anonymize) }] };
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
              const stats = errorDb.getStats();
              return { content: [{ type: "text", text: formatErrorDbImport(result, stats) }] };
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
            return { content: [{ type: "text", text: formatErrorDbStats(stats) }] };
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
            } catch (e) {
              console.error(`[build_semantic_index] failed ${key}: ${e}`);
              failed++;
            }
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
  
          const builtin = loadedLibraries.filter(l =>
            BUILTIN_ROOTS.some(b => b.key === l.key)
          );
          const external = loadedLibraries.filter(l =>
            !BUILTIN_ROOTS.some(b => b.key === l.key)
          );

          return { content: [{ type: "text", text: formatListLibraries(CONFIG_PATH, builtin, external) }] };
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
  
          const knownFixes = fixPatternsDb.search(code.substring(0, 500));
          return { content: [{ type: "text", text: formatAnalyzeCode(code, ctx, knownFixes) }] };
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
  
          return { content: [{ type: "text", text: formatRecordFix(saved) }] };
        }
  
        case "list_fixes": {
          const { query, limit = 20 } = args as { query?: string; limit?: number };
  
          if (query) {
            const results = fixPatternsDb.search(query);
            if (results.length === 0) {
              return { content: [{ type: "text", text: `🔍 未找到匹配 "${query}" 的修复模式` }] };
            }
            return { content: [{ type: "text", text: formatListFixesSearch(query, results) }] };
          }
  
          const all = fixPatternsDb.list(limit);
          if (all.length === 0) {
            return {
              content: [{ type: "text", text: "📭 暂无已记录的修复模式。使用 record_fix 工具开始记录。" }],
            };
          }
          const stats = fixPatternsDb.getStats();
          return { content: [{ type: "text", text: formatListFixesAll(all, stats) }] };
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
            return { content: [{ type: "text", text: formatKnowledgeExport(lk, result) }] };
          }
  
          if (action === "import") {
            if (!fp) {
              return { content: [{ type: "text", text: "❌ import 操作需要提供 file_path（.knowledge.json 文件的绝对路径）" }], isError: true };
            }
            const result = await knowledgeStore.importLibrary(fp, import_as);
            return { content: [{ type: "text", text: formatKnowledgeImport(result) }] };
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
          const fixStats = fixPatternsDb.getStats();
          return { content: [{ type: "text", text: formatKnowledgeStats(libKeys, statsArr, fixStats) }] };
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
}
