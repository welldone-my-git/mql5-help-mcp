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
  BUILTIN_ROOTS, CONFIG_PATH, activePlugin, buildIndex, docIndex,
  externalLibFiles, getEmbeddingConfig, getDoc, loadedLibraries,
  queryEngine, searchDocs,
} from "./document-service.js";

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
  const lines = [`📋 本地修复模式库 (共 ${stats.total} 条, 累计使用 ${stats.totalUsage} 次)\n`];
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
}
