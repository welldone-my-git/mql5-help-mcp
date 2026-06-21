import type { SmartQueryResult } from "../smart-query.js";
import type { ErrorRecord, ErrorSearchResult } from "../error-db.js";
import type { FixPattern } from "../fix-patterns.js";

export function formatSmartQuery(query: string, result: SmartQueryResult): string {
  let o = `🔍 智能查询结果\n${"=".repeat(60)}\n\n`;
  o += `📝 查询: ${query}\n`;
  o += `⚙️ 模式: ${result.type === "quick" ? "精简" : "详细"}\n`;
  o += `📊 预计token: ~${result.estimatedTokens}\n\n`;
  o += `${"─".repeat(60)}\n\n`;
  o += `💡 答案:\n${result.answer}\n\n`;

  if (result.syntax) o += `📐 语法:\n${result.syntax}\n\n`;
  if (result.parameters) o += `📋 参数:\n${result.parameters}\n\n`;
  if (result.returns) o += `↩️ 返回值:\n${result.returns}\n\n`;
  if (result.code || result.example) o += `💻 示例代码:\n${result.code || result.example}\n\n`;

  if (result.notes && result.notes.length > 0) {
    o += `⚠️ 注意事项:\n`;
    result.notes.forEach((note, i) => { o += `${i + 1}. ${note}\n`; });
    o += `\n`;
  }

  o += `📚 参考文档: ${result.reference}\n`;

  if (result.relatedDocs && result.relatedDocs.length > 0) {
    o += `\n🔗 相关文档:\n`;
    result.relatedDocs.forEach(doc => { o += `  • ${doc}\n`; });
  }

  return o;
}

export function formatLogError(record: ErrorRecord, dbPath: string): string {
  let o = `✅ 错误已记录到数据库\n${"=".repeat(60)}\n\n`;
  o += `📋 错误代码: ${record.error_code}\n`;
  o += `📝 错误消息: ${record.error_message}\n`;
  o += `🔢 出现次数: ${record.occurrence_count}\n`;
  o += `📅 首次遇到: ${record.first_seen}\n`;
  o += `📅 最后遇到: ${record.last_seen}\n`;

  if (record.solution) o += `\n💡 解决方案:\n${record.solution}\n`;
  if (record.related_docs) o += `\n📚 相关文档:\n${record.related_docs}\n`;

  o += `\n💾 数据库位置: ${dbPath}`;
  return o;
}

export function formatListCommonErrors(errors: ErrorRecord[], stats: { totalErrors: number; totalOccurrences: number; dbPath: string }): string {
  let o = `📊 最常见的MQL5编译错误 (TOP ${errors.length})\n${"=".repeat(60)}\n\n`;

  errors.forEach((error, index) => {
    o += `${index + 1}. ${error.error_code} - ${error.error_message}\n`;
    o += `   🔢 出现次数: ${error.occurrence_count}\n`;
    o += `   📅 最后遇到: ${error.last_seen}\n`;

    if (error.solution) {
      const short = error.solution.length > 100 ? error.solution.substring(0, 100) + "..." : error.solution;
      o += `   💡 解决方案: ${short}\n`;
    }
    o += `\n`;
  });

  o += `${"─".repeat(60)}\n`;
  o += `📈 统计信息:\n`;
  o += `  • 总错误类型: ${stats.totalErrors}\n`;
  o += `  • 总出现次数: ${stats.totalOccurrences}\n`;
  o += `  • 数据库位置: ${stats.dbPath}\n`;
  return o;
}

export function formatErrorDbExport(jsonData: string, anonymize: boolean): string {
  let o = `📤 错误数据库导出成功\n${"=".repeat(60)}\n\n`;
  if (anonymize) o += `🔒 隐私模式: 已移除文件路径信息\n\n`;
  o += `📊 导出数据:\n`;
  o += `\`\`\`json\n${jsonData}\n\`\`\`\n\n`;
  o += `💡 提示: 复制上述JSON数据，使用 manage_error_db(action="import") 导入到其他系统`;
  return o;
}

export function formatErrorDbImport(result: { imported: number; updated: number; errors: number }, stats: { totalErrors: number; totalOccurrences: number }): string {
  let o = `📥 错误数据库导入完成\n${"=".repeat(60)}\n\n`;
  o += `✅ 新导入: ${result.imported} 条\n`;
  o += `🔄 已更新: ${result.updated} 条\n`;
  if (result.errors > 0) o += `⚠️ 失败: ${result.errors} 条\n`;

  o += `\n📈 当前数据库统计:\n`;
  o += `  • 总错误类型: ${stats.totalErrors}\n`;
  o += `  • 总出现次数: ${stats.totalOccurrences}\n`;
  return o;
}

export function formatErrorDbStats(stats: { totalErrors: number; totalOccurrences: number; dbPath: string }): string {
  let o = `📈 错误数据库统计信息\n${"=".repeat(60)}\n\n`;
  o += `📊 数据统计:\n`;
  o += `  • 总错误类型: ${stats.totalErrors}\n`;
  o += `  • 总出现次数: ${stats.totalOccurrences}\n`;
  o += `  • 平均每错误: ${stats.totalErrors > 0 ? (stats.totalOccurrences / stats.totalErrors).toFixed(1) : 0} 次\n\n`;
  o += `💾 数据库信息:\n`;
  o += `  • 位置: ${stats.dbPath}\n\n`;
  o += `💡 提示:\n`;
  o += `  • 使用 list_common_errors 查看高频错误\n`;
  o += `  • 使用 manage_error_db(action="export") 导出错误库\n`;
  o += `  • 使用 smart_query 查询错误时会自动从数据库搜索`;
  return o;
}

export function formatListLibraries(
  configPath: string,
  builtin: Array<{ key: string; fileCount: number }>,
  external: Array<{ key: string; fileCount: number; absPath: string; description?: string }>,
): string {
  let o = `📚 已加载资料库\n${"=".repeat(60)}\n\n`;
  o += `配置文件: ${configPath}\n\n`;

  o += `📖 内置库 (${builtin.length}):\n`;
  for (const lib of builtin) {
    o += `  • ${lib.key.padEnd(22)} ${lib.fileCount} 个文件\n`;
  }

  o += `\n🔌 外部库 (${external.length}):\n`;
  if (external.length === 0) {
    o += `  （未配置）\n\n`;
    o += `💡 在 ${configPath} 中添加：\n`;
    o += `\`\`\`json\n`;
    o += `{\n  "extraLibraries": [\n`;
    o += `    { "key": "MyLib", "path": "/path/to/library", "description": "说明" }\n`;
    o += `  ]\n}\n\`\`\`\n`;
    o += `\n支持文件类型：.htm .html .md .mq5 .mqh\n`;
    o += `搜索外部库文件使用前缀，如 search("mylib_filename")`;
  } else {
    for (const lib of external) {
      o += `  • ${lib.key.padEnd(22)} ${lib.fileCount} 个文件  ${lib.absPath}\n`;
      if (lib.description && lib.description !== "外部库") {
        o += `    ${lib.description}\n`;
      }
    }
    o += `\n💡 搜索外部库文件可加前缀，如 search("${external[0].key.toLowerCase()}_filename")`;
  }
  return o;
}

export function formatAnalyzeCode(
  code: string,
  ctx: { libraryAPISummary: string; detectedPatterns: Array<{ lineNo: number; code: string; hint: string; library: string }> },
  knownFixes: FixPattern[],
): string {
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

  return out.join("\n");
}

export function formatRecordFix(saved: FixPattern): string {
  return `✅ 修复模式已保存 (ID: ${saved.id ?? "已更新"}, 使用次数: ${saved.usage_count})\n\n**问题:** ${saved.pattern_description}\n**修复:** ${saved.fix_description}`;
}

export function formatListFixesSearch(query: string, results: FixPattern[]): string {
  const lines = [`🔍 搜索 "${query}" 的结果 (${results.length} 条):\n`];
  for (const r of results) {
    lines.push(`**[${r.usage_count}次] ${r.pattern_description}**`);
    lines.push(`→ ${r.fix_description}`);
    if (r.library_key) lines.push(`库: ${r.library_key}`);
    if (r.tags) lines.push(`标签: ${r.tags}`);
    if (r.fixed_snippet) lines.push("```mql5\n" + r.fixed_snippet + "\n```");
    lines.push("---");
  }
  return lines.join("\n");
}

export function formatListFixesAll(all: FixPattern[], stats: { total: number; totalUsage: number }): string {
  const lines = [`📋 本地修复模式库 (共 ${stats.total} 条, 累计使用 ${stats.totalUsage} 次)\n`];
  for (const r of all) {
    lines.push(`**#${r.id} [${r.usage_count}次] ${r.pattern_description}**`);
    lines.push(`→ ${r.fix_description}`);
    if (r.library_key) lines.push(`库: ${r.library_key}`);
    lines.push("---");
  }
  return lines.join("\n");
}

export function formatKnowledgeExport(lk: string, result: { fileCount: number; classCount: number; filePath: string }): string {
  return [
    `✅ 已导出库 "${lk}" 的知识包`,
    `   文件数: ${result.fileCount}  类数: ${result.classCount}`,
    `   路径: ${result.filePath}`,
    "",
    "**分享方式:**",
    `1. 将 \`${result.filePath}\` 发送给团队成员`,
    `2. 对方运行: manage_knowledge(action="import", file_path="/path/to/${lk}.knowledge.json")`,
    "3. 对方无需配置 ANTHROPIC_API_KEY 或运行 preprocess_library，直接可用 analyze_code",
  ].join("\n");
}

export function formatKnowledgeImport(result: { libraryKey: string; imported: number; skipped: number; errors: number }): string {
  const lines = [
    `✅ 知识包导入完成 → 库: "${result.libraryKey}"`,
    `   新增: ${result.imported} 个文件`,
    `   已跳过（已存在）: ${result.skipped}`,
    `   失败: ${result.errors}`,
    "",
  ];
  if (result.imported > 0) {
    lines.push(`现在可以直接运行 analyze_code(code, "${result.libraryKey}") 使用导入的知识。`);
  } else {
    lines.push(`提示：若全部跳过，说明该库知识已存在。可删除 ~/.knowledge-mcp/knowledge/${result.libraryKey}/ 后重新导入。`);
  }
  return lines.join("\n");
}

export function formatKnowledgeStats(
  libKeys: string[],
  statsArr: Array<{ key: string; fileCount: number; classCount: number }>,
  fixStats: { total: number },
): string {
  const lines = ["📊 库知识统计:\n"];
  for (const s of statsArr) {
    const icon = s.fileCount > 0 ? "✅" : "⬜";
    lines.push(`${icon} **${s.key}**: ${s.fileCount} 个文件已分析, ${s.classCount} 个类`);
    if (s.fileCount === 0) {
      lines.push(`   → 运行 preprocess_library("${s.key}") 开始预处理`);
    }
  }
  lines.push(`\n💾 **本地修复模式库**: ${fixStats.total} 条记录`);
  return lines.join("\n");
}
