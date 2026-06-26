# TickValue Compare：Broker Tick Value 风控诊断工具

来源：

- MQL5 CodeBase: <https://www.mql5.com/en/code/73211>
- File: `TickValue_Compare.mq5`
- Author: Vinicius Pereira De Oliveira
- Local source: [TickValueCompare](../../examples/mql5/TickValueCompare/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 交易策略 | ☆☆☆☆☆ |
| 指标价值 | ☆☆☆☆☆ |
| MQL5 技巧 | ⭐⭐⭐⭐⭐ |
| 风控知识 | ⭐⭐⭐⭐⭐ |
| 架构设计 | ⭐☆☆☆☆ |
| 收藏价值 | ⭐⭐⭐⭐☆ |

一句话总结：

> 这是开发诊断工具，不是策略；核心价值是提醒 EA 风控不要盲信 `SYMBOL_TRADE_TICK_VALUE`。

## 它解决的问题

很多 EA 的手数计算会写成：

```text
Lots = RiskMoney / (SL_Points * TickValue)
```

其中 `TickValue` 常常直接取：

```text
SYMBOL_TRADE_TICK_VALUE
```

问题是 MT5 还有两个更具体的属性：

```text
SYMBOL_TRADE_TICK_VALUE_LOSS
SYMBOL_TRADE_TICK_VALUE_PROFIT
```

在某些经纪商、交叉盘、CFD、黄金、指数、期货上，这三者可能不完全一致。

如果止损金额估算用错 tick value，实际风险会偏离预期。

## 源码做了什么

脚本遍历 Market Watch：

```text
SymbolsTotal(true)
SymbolName(i, true)
```

对每个 symbol 读取：

```text
SYMBOL_TRADE_TICK_VALUE
SYMBOL_TRADE_TICK_VALUE_LOSS
SYMBOL_TRADE_TICK_VALUE_PROFIT
SYMBOL_CURRENCY_MARGIN
SYMBOL_CURRENCY_PROFIT
```

然后分类：

```text
ALL_EQUAL
TV_MATCHES_PROFIT
TV_MATCHES_LOSS
ALL_DIFFER
```

最后输出汇总，并可选导出 CSV。

## 最值得收藏的知识点

### 1. 风控应优先使用 loss-side tick value

用于止损风险估算时，更稳妥的是：

```text
SYMBOL_TRADE_TICK_VALUE_LOSS
```

因为你计算的是亏损场景下每 tick 损失多少钱，而不是盈利场景。

这条规则应进入 `RiskManager::CalcLots()`。

### 2. Broker Diagnostics 应独立于策略

这个脚本不应该嵌进交易信号。

更合理的位置：

```text
BrokerDiagnostics
    ↓
SymbolAudit
    ↓
RiskManager
```

先检查经纪商 symbol 属性，再决定实际 EA 的手数计算策略。

### 3. Market Watch Scanner 模板

源码用：

```text
SymbolsTotal(true)
SymbolName(i, true)
```

这是做多品种扫描、组合 EA、broker audit 的基础写法。

### 4. CSV 输出适合 Python 端分析

脚本可导出：

```text
Symbol;MarginCcy;ProfitCcy;TV;LOSS;PROFIT;Category
```

这可以直接给 Python / DuckDB / Polars 做跨经纪商对比。

## 可复用模块

建议抽取成：

```text
Framework/Risk/
├── TickValueDiagnostics.mqh
├── BrokerSymbolAudit.mqh
├── PositionSizing.mqh
└── RiskManager.mqh
```

核心接口可以是：

```text
double LossTickValue(symbol)
double ProfitTickValue(symbol)
bool   IsTickValueConsistent(symbol)
AuditResult AnalyzeSymbol(symbol)
```

## 不足

### 1. 只是诊断，不是自动修正

源码指出差异，但不会替换你的 lot sizing。

真正框架里应该把结论接入：

```text
CalcLotsByRisk()
```

### 2. 没有加入 contract size / tick size 交叉验证

更严谨的 broker audit 还应检查：

```text
SYMBOL_TRADE_CONTRACT_SIZE
SYMBOL_TRADE_TICK_SIZE
SYMBOL_POINT
SYMBOL_DIGITS
SYMBOL_CURRENCY_PROFIT
SYMBOL_CURRENCY_MARGIN
```

### 3. 没有实单或模拟订单验证

最终风险金额最好用实际订单利润模型验证：

```text
OrderCalcProfit()
```

这比只读 symbol property 更可靠。

## 推荐升级版

可以做成：

```text
Broker Audit Pipeline
    │
    ├── Symbol property audit
    ├── Tick value consistency audit
    ├── Spread / commission audit
    ├── Swap audit
    ├── OrderCalcProfit cross-check
    └── CSV / JSON export
```

Python 侧再做：

```text
Broker A vs Broker B
Symbol-level risk consistency
Lot sizing error estimate
```

## 最终结论

建议收藏到：

```text
Risk Management / Broker Diagnostics
```

不要归类为策略或指标。

它的价值是帮助你构建可靠的底层风控基础设施，尤其是跨经纪商、跨品种时的 position sizing。

## 标签

```text
MQL5 CodeBase
Risk Management
Broker Diagnostics
Tick Value
Position Sizing
Market Watch Scanner
CSV Export
Developer Utility
```
