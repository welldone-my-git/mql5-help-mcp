import type { AnalysisResult, Issue } from "./code-analyzer.js";

function appendIssue(lines: string[], issue: Issue, idx: number): void {
  const loc = issue.lines.length > 0 ? `（第 ${issue.lines.slice(0, 3).join(", ")} 行）` : "";
  lines.push(`  ${idx}. [${issue.id}] ${issue.name} ${loc}`);
  lines.push(`     ${issue.detail.replace(/\n/g, "\n     ")}`);
  lines.push(`     → 修复: ${issue.fix.replace(/\n/g, "\n       ")}`);
}

export function formatAnalysisResult(result: AnalysisResult): string {
  const { overview: ov, issues, passed, score } = result;
  const lines: string[] = [];

  const scoreIcon = score >= 80 ? "🟢" : score >= 50 ? "🟡" : "🔴";
  lines.push(`🏗️  MQL5 代码结构分析`);
  lines.push("=".repeat(60));
  lines.push(`${scoreIcon} 代码质量评分: ${score} / 100\n`);

  lines.push("📋 结构概览:");
  lines.push(`  ${ov.hasOnInit       ? "✅" : "⬜"} OnInit`);
  lines.push(`  ${ov.hasOnTick       ? "✅" : "⬜"} OnTick`);
  lines.push(`  ${ov.hasOnDeinit     ? "✅" : "⬜"} OnDeinit`);
  lines.push(`  ${ov.hasOnTrade      ? "✅" : "⬜"} OnTrade`);
  lines.push(`  ${ov.hasOnChartEvent ? "✅" : "⬜"} OnChartEvent`);
  if (ov.indicatorHandles.length > 0)
    lines.push(`  📊 指标句柄: ${ov.indicatorHandles.join(", ")}`);
  if (ov.tradeCalls.length > 0)
    lines.push(`  💹 下单方法: ${ov.tradeCalls.join(", ")}`);
  lines.push("");

  const high   = issues.filter(i => i.severity === "high");
  const medium = issues.filter(i => i.severity === "medium");
  const low    = issues.filter(i => i.severity === "low");

  if (issues.length === 0) {
    lines.push("✅ 未检测到已知结构问题\n");
  } else {
    if (high.length > 0) {
      lines.push(`🔴 高危问题 (${high.length}):`);
      high.forEach((issue, i) => appendIssue(lines, issue, i + 1));
      lines.push("");
    }
    if (medium.length > 0) {
      lines.push(`🟡 中等风险 (${medium.length}):`);
      medium.forEach((issue, i) => appendIssue(lines, issue, i + 1));
      lines.push("");
    }
    if (low.length > 0) {
      lines.push(`🔵 低风险提示 (${low.length}):`);
      low.forEach((issue, i) => appendIssue(lines, issue, i + 1));
      lines.push("");
    }
  }

  if (passed.length > 0) {
    lines.push(`✅ 通过检查 (${passed.length}):`);
    passed.forEach(p => lines.push(`  • ${p}`));
    lines.push("");
  }

  lines.push("─".repeat(60));
  lines.push("💡 此分析基于静态规则，不能替代完整代码审查。建议配合 analyze_code 使用库知识做进一步优化。");

  return lines.join("\n");
}
