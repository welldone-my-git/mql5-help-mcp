/**
 * MQL5 Domain Plugin
 * Owns: diagnose_error, analyze_structure
 * Enhances: smart_query (via preprocessQuery)
 */

import { DomainPlugin, PluginContext, ToolDefinition, PluginResult, EnrichedQuery } from "../../core/plugin.js";
import { DiagnoseEngine } from "../../diagnose-engine.js";
import { codeStructureAnalyzer } from "../../code-analyzer.js";
import { formatAnalysisResult } from "../../code-analyzer-formatter.js";
import { MIGRATION_HINTS } from "../../utils.js";

class Mql5Plugin implements DomainPlugin {
  readonly name = "mql5";

  getToolDefinitions(): ToolDefinition[] {
    return [
      {
        name: "diagnose_error",
        description: "🔬 编译日志批量诊断：粘贴 MetaEditor 完整编译输出，自动解析所有 error/warning 行，去重后逐条匹配 MQL4→MQL5 迁移映射与历史解决方案，输出结构化诊断报告。",
        inputSchema: {
          type: "object",
          properties: {
            compile_log: {
              type: "string",
              description: "MetaEditor 编译窗口的完整输出文本（可包含多个错误）",
            },
          },
          required: ["compile_log"],
        },
      },
      {
        name: "analyze_structure",
        description: "🏗️ MQL5 代码结构静态分析：检测句柄泄漏、OnTick无保护开仓、无魔术数字、固定手数、缺少错误检查等6类问题，输出带行号的评分报告。完全本地，零API成本。",
        inputSchema: {
          type: "object",
          properties: {
            code: {
              type: "string",
              description: "需要分析的 MQL5 代码（EA 或指标）",
            },
          },
          required: ["code"],
        },
      },
    ];
  }

  async handleToolCall(toolName: string, args: unknown, ctx: PluginContext): Promise<PluginResult> {
    switch (toolName) {
      case "diagnose_error": {
        const { compile_log } = args as { compile_log: string };
        const engine = new DiagnoseEngine(ctx.docIndex);
        const report = await engine.diagnose(compile_log);
        return { content: [{ type: "text", text: report }] };
      }

      case "analyze_structure": {
        const { code } = args as { code: string };
        const result = codeStructureAnalyzer.analyze(code);
        const report = formatAnalysisResult(result);

        const issueText = result.issues.map(i => i.detail + " " + i.id).join(" ");
        const knownFixes = issueText.length > 10
          ? ctx.fixPatternsDb.search(issueText.substring(0, 400))
          : [];

        const out: string[] = [report];
        if (knownFixes.length > 0) {
          out.push("\n\n📚 **本地已记录的修复模式（直接可用）:**");
          for (const fix of knownFixes.slice(0, 3)) {
            out.push(`\n**${fix.pattern_description}**`);
            out.push(`修复: ${fix.fix_description}`);
            if (fix.fixed_snippet) {
              out.push("```mql5\n" + fix.fixed_snippet + "\n```");
            }
          }
        }

        return { content: [{ type: "text", text: out.join("\n") }] };
      }

      default:
        return {
          content: [{ type: "text", text: `❌ MQL5 插件未知工具: ${toolName}` }],
          isError: true,
        };
    }
  }

  preprocessQuery(query: string, _ctx: PluginContext): EnrichedQuery {
    const lower = query.toLowerCase().replace(/[^a-z0-9_]/g, "");
    const matched = MIGRATION_HINTS[lower];
    if (matched) {
      return {
        original: query,
        expanded: matched.targetKeys.join(" ") + " " + query,
        hint: `MQL4→MQL5 迁移提示：${matched.hint}（推荐改用 ${matched.replacement}）`,
      };
    }
    return { original: query, expanded: query };
  }
}

export const mql5Plugin: DomainPlugin = new Mql5Plugin();
