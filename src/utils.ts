const ENTITY_RE = /&(#\d+|#x[0-9a-f]+|amp|lt|gt|nbsp|quot|apos);/gi;

export function decodeEntities(text: string): string {
  return text.replace(ENTITY_RE, (_, e) => {
    if (e.startsWith("#x")) return String.fromCharCode(parseInt(e.slice(2), 16));
    if (e.startsWith("#")) return String.fromCharCode(parseInt(e.slice(1), 10));
    const m: Record<string, string> = { amp: "&", lt: "<", gt: ">", nbsp: " ", quot: '"', apos: "'" };
    return m[e] ?? _;
  });
}

export function stripHtml(html: string): string {
  return decodeEntities(html
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
    .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim());
}

import TurndownService from "turndown";

const turndown = new TurndownService({
  headingStyle: "atx",
  hr: "---",
  bulletListMarker: "-",
  codeBlockStyle: "fenced",
  emDelimiter: "*",
  strongDelimiter: "**",
  linkStyle: "inlined",
});

export function htmlToMarkdown(html: string): string {
  const cleaned = html
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
    .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, "")
    .replace(/\s*class="[^"]*"/gi, "")
    .replace(/\s*style="[^"]*"/gi, "");
  return decodeEntities(turndown.turndown(cleaned));
}

export interface MigrationHint {
  replacement: string;
  hint: string;
  targetKeys: string[];
}

// MQL4→MQL5 常见迁移映射/别名（供 index.ts 搜索提示与 smart-query.ts 诊断共用）
export const MIGRATION_HINTS: Record<string, MigrationHint> = {
  // CTrade / 订单结果
  "resultcode": {
    replacement: "ResultRetcode",
    hint: "CTrade 结果方法在 MQL5 中改为 ResultRetcode()",
    targetKeys: ["ctrade", "trade"],
  },
  // 预定义变量
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
  "digits()": {
    replacement: "_Digits",
    hint: "预定义变量由 Digits() 迁移为 _Digits",
    targetKeys: ["_digits"],
  },
  "point()": {
    replacement: "_Point",
    hint: "预定义变量由 Point() 迁移为 _Point",
    targetKeys: ["_point"],
  },
  // 指标函数
  "ima": {
    replacement: "iMA / IndicatorCreate",
    hint: "MQL5 中可直接用 iMA() 或通过 IndicatorCreate 构建",
    targetKeys: ["ima", "indicatorcreate", "icustom"],
  },
  "irsi": {
    replacement: "iRSI",
    hint: "MQL5 中 iRSI() 仍可用，但句柄需配合 CopyBuffer 获取数据",
    targetKeys: ["irsi", "copybuffer"],
  },
  "imacd": {
    replacement: "iMACD",
    hint: "MQL5 中 iMACD() 返回句柄，需用 CopyBuffer 取值",
    targetKeys: ["imacd", "copybuffer"],
  },
  "ibands": {
    replacement: "iBands",
    hint: "MQL5 中 iBands() 返回句柄，需用 CopyBuffer 取值",
    targetKeys: ["ibands", "copybuffer"],
  },
  // 订单/持仓管理
  "orderstotal": {
    replacement: "PositionsTotal / OrdersTotal",
    hint: "MQL5 区分持仓(PositionsTotal)与挂单(OrdersTotal)，不同于 MQL4 的统一 OrdersTotal",
    targetKeys: ["positionstotal", "orderstotal"],
  },
  "orderselect": {
    replacement: "PositionSelectByTicket / OrderSelect",
    hint: "MQL5 用 PositionSelectByTicket 选择持仓，OrderSelect 仅用于挂单",
    targetKeys: ["positionselectbyticket", "orderselect"],
  },
  "ordersend": {
    replacement: "CTrade::Buy/Sell/BuyLimit 等",
    hint: "MQL5 推荐用 CTrade 类方法替代裸调 OrderSend，直接调用仍支持但参数结构已变",
    targetKeys: ["ctrade", "ordersend", "trade"],
  },
  "orderprofit": {
    replacement: "PositionGetDouble(POSITION_PROFIT)",
    hint: "MQL5 通过 PositionGetDouble(POSITION_PROFIT) 获取当前持仓盈亏",
    targetKeys: ["positiongetdouble"],
  },
  "orderlots": {
    replacement: "PositionGetDouble(POSITION_VOLUME)",
    hint: "MQL5 通过 PositionGetDouble(POSITION_VOLUME) 获取持仓手数",
    targetKeys: ["positiongetdouble"],
  },
  // 市场信息
  "marketinfo": {
    replacement: "SymbolInfoDouble / SymbolInfoInteger / SymbolInfoString",
    hint: "MQL4 的 MarketInfo() 在 MQL5 拆分为 SymbolInfoDouble/Integer/String 系列函数",
    targetKeys: ["symbolinfodouble", "symbolinfointeger", "symbolinfostring"],
  },
  // 数据刷新
  "refreshrates": {
    replacement: "（已废弃）",
    hint: "RefreshRates() 在 MQL5 中已废弃，价格数据通过 SymbolInfoTick 或直接读取序列获取",
    targetKeys: ["symbolinfotick", "latesttick"],
  },
  // 账户信息
  "accountbalance": {
    replacement: "AccountInfoDouble(ACCOUNT_BALANCE)",
    hint: "MQL5 通过 AccountInfoDouble(ACCOUNT_BALANCE) 获取账户余额",
    targetKeys: ["accountinfodouble"],
  },
  "accountequity": {
    replacement: "AccountInfoDouble(ACCOUNT_EQUITY)",
    hint: "MQL5 通过 AccountInfoDouble(ACCOUNT_EQUITY) 获取账户净值",
    targetKeys: ["accountinfodouble"],
  },
  // 时间序列
  "iseriestype": {
    replacement: "（已废弃）",
    hint: "MQL5 序列默认从最新到最旧，无需 SetIndexStyle 或 isSeries 设置",
    targetKeys: ["copyrates", "copybuffer"],
  },
};
