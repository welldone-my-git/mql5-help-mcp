/**
 * MQL5 代码结构静态分析器
 * 完全本地，零 API 成本
 */

// ========== 数据结构 ==========

export type Severity = "high" | "medium" | "low";

export interface Issue {
  id: string;
  name: string;
  severity: Severity;
  lines: number[];      // 相关行号（1-based）
  detail: string;       // 问题描述
  fix: string;          // 修复建议
}

export interface StructureOverview {
  hasOnInit: boolean;
  hasOnTick: boolean;
  hasOnDeinit: boolean;
  hasOnTrade: boolean;
  hasOnChartEvent: boolean;
  usesCTrade: boolean;
  usesIndicators: boolean;
  indicatorHandles: string[];   // 检测到的句柄变量名
  tradeCalls: string[];         // 检测到的下单调用
}

export interface AnalysisResult {
  overview: StructureOverview;
  issues: Issue[];
  passed: string[];             // 通过检查的项目
  score: number;                // 0-100，越高越好
}

// ========== 代码解析工具 ==========

function getLines(code: string): string[] {
  return code.split("\n");
}

/** 提取指定函数体（含大括号） */
function extractFunctionBody(code: string, funcName: string): string {
  const re = new RegExp(`\\b${funcName}\\b[^{]*\\{`, "m");
  const match = re.exec(code);
  if (!match) return "";

  const braceStart = match.index + match[0].lastIndexOf("{");
  let depth = 0;
  for (let i = braceStart; i < code.length; i++) {
    if (code[i] === "{") depth++;
    else if (code[i] === "}") {
      depth--;
      if (depth === 0) return code.slice(braceStart, i + 1);
    }
  }
  return "";
}

/** 找出某个模式在代码中出现的行号（1-based） */
function findLines(lines: string[], pattern: RegExp): number[] {
  const result: number[] = [];
  lines.forEach((line, idx) => {
    if (pattern.test(line) && !line.trim().startsWith("//")) {
      result.push(idx + 1);
    }
  });
  return result;
}

/** 简单去重 */
function unique<T>(arr: T[]): T[] {
  return [...new Set(arr)];
}

// ========== 结构概览 ==========

function buildOverview(code: string, lines: string[]): StructureOverview {
  const INDICATOR_CALLS = /\bi(MA|RSI|MACD|Bands|ATR|Stochastic|CCI|Momentum|DeMarker|Force|AO|AMA|DEMA|TEMA|FRAMA|VIDYA|Bears|Bulls|BW|Candles|Chaikin|SAR|Envelopes|Fractals|Gator|Ichimoku|OBV|Volumes|WPR|AD|ADX|ADXW|Alligator)\s*\(/i;
  const HANDLE_ASSIGN = /\b(int\s+)?(\w+)\s*=\s*i[A-Z]\w*\s*\(/;

  const handles: string[] = [];
  lines.forEach(line => {
    const m = HANDLE_ASSIGN.exec(line);
    if (m && !line.trim().startsWith("//")) handles.push(m[2]);
  });

  const tradeCalls: string[] = [];
  const tradeRe = /\btrade\.(Buy|Sell|BuyLimit|SellLimit|BuyStop|SellStop|PositionClose|PositionModify|OrderDelete)\s*\(/gi;
  let tm: RegExpExecArray | null;
  while ((tm = tradeRe.exec(code)) !== null) tradeCalls.push(tm[1]);

  return {
    hasOnInit:       /\bOnInit\b/.test(code),
    hasOnTick:       /\bOnTick\b/.test(code),
    hasOnDeinit:     /\bOnDeinit\b/.test(code),
    hasOnTrade:      /\bOnTrade\b/.test(code),
    hasOnChartEvent: /\bOnChartEvent\b/.test(code),
    usesCTrade:      /\bCTrade\b|\btrade\.(Buy|Sell)\b/.test(code),
    usesIndicators:  INDICATOR_CALLS.test(code),
    indicatorHandles: unique(handles),
    tradeCalls: unique(tradeCalls),
  };
}

// ========== 规则定义 ==========

interface Rule {
  id: string;
  name: string;
  severity: Severity;
  passLabel: string;
  check(code: string, lines: string[], overview: StructureOverview): Issue | null;
}

const RULES: Rule[] = [
  // ── HIGH ──────────────────────────────────────────────────────────
  {
    id: "handle_leak",
    name: "指标句柄未释放",
    severity: "high",
    passLabel: "指标句柄在 OnDeinit 中正确释放",
    check(code, lines, ov) {
      if (!ov.usesIndicators || ov.indicatorHandles.length === 0) return null;
      if (/\bIndicatorRelease\s*\(/.test(code)) return null;

      const handleLines = findLines(lines, /\b(i[A-Z]\w*|IndicatorCreate)\s*\(/);
      return {
        id: "handle_leak",
        name: "指标句柄未释放",
        severity: "high",
        lines: handleLines,
        detail: `检测到句柄变量 [${ov.indicatorHandles.join(", ")}]，但未找到 IndicatorRelease() 调用。每次 EA 初始化都会泄漏一个句柄，长期运行会消耗系统资源。`,
        fix: `在 OnDeinit 中添加：\n  ${ov.indicatorHandles.map(h => `IndicatorRelease(${h});`).join("\n  ")}`,
      };
    },
  },
  {
    id: "unguarded_open",
    name: "OnTick 中无保护开仓",
    severity: "high",
    passLabel: "OnTick 开仓前检查了持仓数量",
    check(code, lines, ov) {
      const onTickBody = extractFunctionBody(code, "OnTick");
      if (!onTickBody) return null;

      const hasTrade = /\btrade\.(Buy|Sell|BuyLimit|SellLimit|BuyStop|SellStop)\s*\(/.test(onTickBody)
        || /\bOrderSend\s*\(/.test(onTickBody);
      if (!hasTrade) return null;

      const hasGuard = /\bPositionsTotal\s*\(\)|\bOrdersTotal\s*\(\)|\bpositions\b|\bposCount\b/i.test(onTickBody);
      if (hasGuard) return null;

      const tradeLines = findLines(lines, /\btrade\.(Buy|Sell|BuyLimit|SellLimit)\s*\(|\bOrderSend\s*\(/);
      return {
        id: "unguarded_open",
        name: "OnTick 中无保护开仓",
        severity: "high",
        lines: tradeLines,
        detail: "OnTick 中发现下单调用，但未检测到持仓数量保护（PositionsTotal() 等）。每次 tick 触发都可能重复开仓。",
        fix: `在下单前添加检查：\n  if(PositionsTotal() > 0) return;\n  // 或：\n  if(PositionSelect(_Symbol)) return;`,
      };
    },
  },

  // ── MEDIUM ────────────────────────────────────────────────────────
  {
    id: "no_magic_number",
    name: "未设置 Magic Number",
    severity: "medium",
    passLabel: "已设置 Magic Number",
    check(code, _lines, ov) {
      if (!ov.usesCTrade) return null;
      if (/\bSetExpertMagicNumber\s*\(/.test(code)) return null;
      return {
        id: "no_magic_number",
        name: "未设置 Magic Number",
        severity: "medium",
        lines: [],
        detail: "检测到 CTrade 对象，但未调用 SetExpertMagicNumber()。EA 将无法区分自己下的单和其他来源的单，OnTrade 回调也无法过滤。",
        fix: `在 OnInit 中添加：\n  trade.SetExpertMagicNumber(MAGIC_NUMBER);\n\n并在全局定义：\n  input int MAGIC_NUMBER = 12345;`,
      };
    },
  },
  {
    id: "fixed_lot",
    name: "硬编码固定手数",
    severity: "medium",
    passLabel: "手数计算使用动态方式",
    check(code, lines, ov) {
      if (!ov.usesCTrade) return null;
      // 找 trade.Buy/Sell(0.x, 或 trade.Buy/Sell(N,
      const fixedLotRe = /\btrade\.(Buy|Sell|BuyLimit|SellLimit|BuyStop|SellStop)\s*\(\s*\d+(\.\d+)?\s*,/;
      if (!fixedLotRe.test(code)) return null;
      if (/\bAccountInfoDouble\s*\(\s*ACCOUNT_BALANCE\b|\bNormalizeDouble\b.*\blot\b/i.test(code)) return null;

      const lotLines = findLines(lines, /\btrade\.(Buy|Sell|BuyLimit|SellLimit)\s*\(\s*\d/);
      return {
        id: "fixed_lot",
        name: "硬编码固定手数",
        severity: "medium",
        lines: lotLines,
        detail: "下单时使用了字面数值手数（如 0.1），不随账户余额或风险比例变化，在不同账户规模下行为不一致。",
        fix: `建议基于风险比例计算手数：\n  double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100.0;\n  double lot = NormalizeDouble(riskAmount / stopLossPoints / tickValue, 2);`,
      };
    },
  },
  {
    id: "no_trade_error_check",
    name: "下单后未检查返回码",
    severity: "medium",
    passLabel: "下单后检查了 ResultRetcode",
    check(code, lines, ov) {
      if (!ov.usesCTrade) return null;
      const hasTrade = /\btrade\.(Buy|Sell|BuyLimit|SellLimit)\s*\(/.test(code);
      if (!hasTrade) return null;
      if (/\bResultRetcode\s*\(\)|\bResultRetcodeDescription\s*\(/.test(code)) return null;

      const tradeLines = findLines(lines, /\btrade\.(Buy|Sell|BuyLimit|SellLimit)\s*\(/);
      return {
        id: "no_trade_error_check",
        name: "下单后未检查返回码",
        severity: "medium",
        lines: tradeLines,
        detail: "调用了 CTrade::Buy/Sell 等方法，但未检查 ResultRetcode()。下单失败时 EA 会静默继续执行。",
        fix: `在下单后添加：\n  if(trade.ResultRetcode() != TRADE_RETCODE_DONE)\n    Print("下单失败: ", trade.ResultRetcodeDescription());`,
      };
    },
  },

  // ── LOW ───────────────────────────────────────────────────────────
  {
    id: "missing_arraysetseries",
    name: "CopyBuffer 后未设置数组方向",
    severity: "low",
    passLabel: "CopyBuffer 数组方向正确设置",
    check(code, lines, _ov) {
      if (!/\bCopyBuffer\s*\(/.test(code)) return null;
      if (/\bArraySetAsSeries\s*\(/.test(code)) return null;

      const copyLines = findLines(lines, /\bCopyBuffer\s*\(/);
      return {
        id: "missing_arraysetseries",
        name: "CopyBuffer 后未设置数组方向",
        severity: "low",
        lines: copyLines,
        detail: "使用了 CopyBuffer 但未找到 ArraySetAsSeries() 调用。默认数组方向为正向（索引0=最旧），通常需要设为反向（索引0=最新）。",
        fix: `在 CopyBuffer 之前添加：\n  double buf[];\n  ArraySetAsSeries(buf, true);\n  CopyBuffer(handle, 0, 0, 3, buf);`,
      };
    },
  },
  {
    id: "nodeinit_missing",
    name: "有 OnInit 但无 OnDeinit",
    severity: "low",
    passLabel: "OnInit / OnDeinit 配对定义",
    check(_code, _lines, ov) {
      if (!ov.hasOnInit || ov.hasOnDeinit) return null;
      if (!ov.usesIndicators && !ov.usesCTrade) return null;
      return {
        id: "nodeinit_missing",
        name: "有 OnInit 但无 OnDeinit",
        severity: "low",
        lines: [],
        detail: "定义了 OnInit 但缺少 OnDeinit。若 OnInit 中分配了资源（指标句柄、对象等），OnDeinit 是释放它们的标准位置。",
        fix: `添加 OnDeinit 函数：\n  void OnDeinit(const int reason)\n  {\n    // IndicatorRelease / 对象清理\n  }`,
      };
    },
  },
];

// ========== 分析器主类 ==========

export class CodeStructureAnalyzer {
  analyze(code: string): AnalysisResult {
    const lines = getLines(code);
    const overview = buildOverview(code, lines);

    const issues: Issue[] = [];
    const passed: string[] = [];

    for (const rule of RULES) {
      const issue = rule.check(code, lines, overview);
      if (issue) {
        issues.push(issue);
      } else {
        // 只有在规则适用时才记录"通过"
        const applicable = this.isApplicable(rule.id, overview);
        if (applicable) passed.push(rule.passLabel);
      }
    }

    // 评分：从100开始，按严重程度扣分
    let score = 100;
    for (const issue of issues) {
      if (issue.severity === "high")   score -= 25;
      if (issue.severity === "medium") score -= 10;
      if (issue.severity === "low")    score -= 5;
    }
    score = Math.max(0, score);

    return { overview, issues, passed, score };
  }

  private isApplicable(ruleId: string, ov: StructureOverview): boolean {
    switch (ruleId) {
      case "handle_leak":         return ov.usesIndicators;
      case "unguarded_open":      return ov.hasOnTick;
      case "no_magic_number":     return ov.usesCTrade;
      case "fixed_lot":           return ov.usesCTrade;
      case "no_trade_error_check":return ov.usesCTrade;
      case "missing_arraysetseries": return true;
      case "nodeinit_missing":    return ov.hasOnInit;
      default: return true;
    }
  }

}

export const codeStructureAnalyzer = new CodeStructureAnalyzer();
