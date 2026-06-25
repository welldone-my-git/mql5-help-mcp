# Fluent Order Builder：从 COrderBuilder 到可维护下单框架

## 来源

- 标题：Implementing a Fluent Interface Builder Pattern for MQL5 Order Construction
- 来源：https://www.mql5.com/en/articles/22936
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-12
- 分类：MetaTrader 5 / Trading systems
- 附件：`OrderBuilder.mqh`、`OrderBuilderDemo.mq5`
- 处理日期：2026-06-25

## 用户评审结论

原文价值：

```text
用 Builder 封装 MqlTradeRequest，
提前校验 Volume、SL/TP、Pending Price、OrderCheck、OrderSend 等问题。
```

优化方向：

```text
不要让 Builder 直接负责所有事情。
```

更适合长期 EA 框架的结构：

```text
Signal / Strategy
  ↓
TradeRequestBuilder
  ↓
TradeValidator
  ↓
RiskManager
  ↓
TradeExecutor
```

最终原则：

| 模块 | 职责 |
| --- | --- |
| Builder | 组装订单 |
| Validator | 检查订单是否合法 |
| RiskManager | 检查能不能交易 |
| Executor | 真正发送订单 |
| Logger | 记录交易过程 |
| Strategy | 只产生信号 |

## 原文解决的问题

MQL5 原生下单需要手动填充：

```text
MqlTradeRequest
```

其中字段很多，而且存在语义依赖：

- `action` 和 `type` 必须匹配；
- Buy 的 SL 必须低于入场价；
- Sell 的 SL 必须高于入场价；
- pending order 必须有合理 price；
- market order 不应设置 expiration；
- stop level 必须满足 broker 的 `SYMBOL_TRADE_STOPS_LEVEL`；
- volume 必须满足 min / max / step；
- filling mode 要适配 symbol。

裸写结构体的问题：

```text
编译器只能检查类型，不能检查交易语义。
```

例如：

```text
Buy order + SL above entry
```

语法正确，但交易语义错误。

## 原文 COrderBuilder 的价值

原文用 fluent interface 把订单构造变成：

```text
builder
  .Symbol(_Symbol)
  .Volume(0.10)
  .Buy()
  .AtMarket()
  .StopLoss(sl)
  .TakeProfit(tp)
  .Send(result)
```

优点：

- 代码可读性强；
- 调用链表达订单意图；
- 每个 setter 可以做局部验证；
- `Send()` 做最终一致性检查；
- 避免 action/type 配对错误；
- 提前捕获 SL/TP 方向错误；
- 可在 `OrderSend()` 前调用 `OrderCheck()`。

## MQL5 Method Chaining 细节

MQL5 不支持 C++ 风格的引用返回：

```text
COrderBuilder& Buy()
```

所以链式调用通常返回指针：

```text
COrderBuilder* Buy()
{
  ...
  return this;
}
```

这个细节值得记录，因为很多 C++ 设计模式迁移到 MQL5 时需要改写。

## 原文 Send() 四阶段 Gate

原文 `Send()` 负责：

```text
1. Flag completeness check
2. Cross-field consistency check
3. OrderCheck()
4. OrderSend()
```

也就是：

```text
local validation
  ↓
broker pre-flight
  ↓
server dispatch
```

这是比直接 `OrderSend()` 更可靠的工程做法。

## 原文最大问题：Builder 过重

原文的 `COrderBuilder` 同时负责：

- request 字段构造；
- symbol / volume 验证；
- SL / TP 验证；
- pending price 验证；
- `OrderCheck()`；
- `OrderSend()`；
- error message；
- 部分 execution policy。

这会让 Builder 变成：

```text
大而全的下单类
```

短期示例没问题，长期 EA 框架不建议照搬。

核心问题：

```text
Build request
Validate request
Check risk
Execute order
Log result
```

是五个不同职责，不应该全塞进一个类。

## 优化版架构

建议拆成：

```text
Signal / Strategy
  ↓
CTradeRequestBuilder
  ↓
CTradeValidator
  ↓
CRiskManager
  ↓
CTradeExecutor
  ↓
CTradeLogger
```

### 1. `CTradeRequestBuilder`

只负责构造订单请求。

职责：

- `Symbol`
- `Volume`
- `Buy` / `Sell`
- `BuyLimit` / `SellLimit`
- `BuyStop` / `SellStop`
- `Price`
- `SL` / `TP`
- `Magic`
- `Comment`
- `Filling`
- `Expiration`
- `Build()`

不负责：

- `OrderSend`
- `OrderCheck`
- 账户风险；
- 仓位限制；
- 最大回撤；
- 是否允许交易。

核心接口应该是：

```text
bool Build(MqlTradeRequest &request)
```

而不是：

```text
bool Send(...)
```

Builder 的边界：

```text
Builder 只 Build，不 Send。
```

### 2. `CTradeValidator`

负责订单合法性检查。

验证内容：

- symbol 是否存在；
- volume 是否符合 min / max / step；
- action/type 是否匹配；
- Buy 的 SL 是否低于入场价；
- Buy 的 TP 是否高于入场价；
- Sell 的 SL 是否高于入场价；
- Sell 的 TP 是否低于入场价；
- SL / TP 是否满足 stops level；
- pending price 是否合理；
- expiration 是否只用于 pending order；
- filling mode 是否可用。

这部分应从原文 `ValidateStops()` 中抽离。

### 3. `CRiskManager`

负责风控，不负责请求字段语义。

建议规则：

- 最大点差过滤；
- 最大持仓数；
- 同方向持仓限制；
- 单笔风险限制；
- 日内亏损限制；
- 连续亏损暂停；
- 新闻时间过滤；
- 交易时段过滤；
- symbol exposure limit；
- portfolio exposure limit。

这些规则不应放进 Builder。

### 4. `CTradeExecutor`

只负责执行流程。

执行顺序：

```text
1. Validator.Validate()
2. RiskManager.Check()
3. OrderCheck()
4. OrderSend()
5. Logger.Record()
```

职责边界：

```text
Executor 不构造 request；
Executor 不计算 signal；
Executor 不决定 strategy；
Executor 只把已构造、已验证、已过风控的 request 发出去。
```

### 5. `CTradeLogger`

记录：

- request snapshot；
- validation error；
- risk rejection reason；
- `OrderCheck()` retcode；
- `OrderSend()` retcode；
- deal / order ticket；
- latency；
- magic / strategy id；
- signal context。

这对回测调试和实盘审计都很重要。

## 推荐调用方式

优化后调用：

```text
MqlTradeRequest request;
MqlTradeResult  result;
string error;

CTradeRequestBuilder builder;

bool ok = builder.Reset()
                 .Symbol(_Symbol)
                 .Volume(0.10)
                 .Buy()
                 .StopLoss(sl)
                 .TakeProfit(tp)
                 .Magic(100001)
                 .Comment("trend entry")
                 .Build(request);

if(!ok)
{
  Print(builder.ErrorMessage());
  return;
}

if(!executor.Send(request, result, error))
{
  Print(error);
  return;
}
```

这个架构比原文更干净：

```text
构造失败 → Builder 报错
合法性失败 → Validator 报错
风控失败 → RiskManager 报错
执行失败 → Executor 报错
```

错误来源清晰。

## 推荐目录结构

```text
MQL5/
└── Include/
    └── TradeFramework/
        ├── TradeRequestBuilder.mqh
        ├── TradeValidator.mqh
        ├── RiskManager.mqh
        ├── TradeExecutor.mqh
        ├── TradeLogger.mqh
        └── TradeTypes.mqh
```

EA：

```text
Experts/
└── MyEA/
    └── MyEA.mq5
```

## 和原文相比的关键改进

| 原文 `COrderBuilder` | 优化版 |
| --- | --- |
| Builder 构造并发送订单 | Builder 只构造 request |
| `Send()` 内部做所有检查 | Validator / Risk / Executor 分层 |
| validation 与 execution 耦合 | validation 可单元测试 |
| 风控容易继续塞进 Builder | 风控独立为 `CRiskManager` |
| 日志逻辑不清晰 | `CTradeLogger` 专门负责 |
| 示例级别设计 | 框架级别设计 |

## 为什么这种拆分更适合长期 EA

不同策略共享：

```text
TradeValidator
RiskManager
TradeExecutor
TradeLogger
```

策略只替换：

```text
Signal / Strategy
```

因此同一套下单框架可以服务：

- 趋势 EA；
- 突破 EA；
- 网格 EA；
- 机器学习信号 EA；
- 多品种 EA；
- 手工交易辅助工具。

这符合：

```text
Open for extension, closed for modification
```

## 与已有知识条目的关系

这篇可以和以下条目形成完整 EA 工程层：

- Repository Pattern：交易历史和统计数据访问抽象；
- Object Pool：高频对象生命周期管理；
- Decorator Pattern：日志、计时、过滤、缓存等横切功能；
- Universal Breakout Study：策略研究流程和订单生命周期；
- DSU + DBN Signal：Signal 类架构；
- G Channel：Signal / Filter 模块；
- Weekend Gap：indicator buffer → EA 接口。

组合后可形成：

```text
SignalEngine
  ↓
TradeRequestBuilder
  ↓
TradeValidator
  ↓
RiskManager
  ↓
TradeExecutor
  ↓
Repository / Logger / Analytics
```

## 实战注意点

### 1. `OrderCheck()` 不能保证 `OrderSend()` 必然成功

市场条件可能在两者之间变化。

所以执行层仍要处理：

- requote；
- invalid price；
- market closed；
- no money；
- invalid stops；
- filling unsupported；
- trade context busy。

### 2. Builder 状态复用必须谨慎

如果 Builder 不自动 reset，可能出现 stale state。

建议：

```text
每次 Build 前显式 Reset()
```

或者将 Builder 设计为：

```text
Build() 后不可复用，必须 Reset()
```

### 3. 风控用实时账户状态

风控不应使用 EA 启动时缓存的 balance。

应在 `RiskManager.Check()` 中实时读取：

- `ACCOUNT_BALANCE`
- `ACCOUNT_EQUITY`
- margin；
- current exposure；
- floating PnL；
- daily realized PnL。

### 4. 多品种 EA 必须传入 symbol context

不要依赖全局 `_Symbol`。

建议：

```text
SymbolContext
├── symbol
├── point
├── digits
├── tick_size
├── tick_value
├── min_lot
├── max_lot
├── lot_step
└── stops_level
```

Validator / Risk / Executor 都基于 context 工作。

## 最终结论

原文 `COrderBuilder` 是高质量 MQL5 工程文章，值得学习 fluent interface、状态机验证、stop level 校验和 `OrderCheck()` 前置。

但如果目标是搭长期 EA 框架，不建议原样照搬。

更好的版本是：

```text
CTradeRequestBuilder
CTradeValidator
CRiskManager
CTradeExecutor
CTradeLogger
```

一句话沉淀：

```text
Builder 的职责是把交易意图安全地组装成 MqlTradeRequest；
是否允许交易、是否符合风控、是否发送成功，应交给 Validator、RiskManager 和 Executor。
```

## 标签

- MQL5
- Fluent Interface
- Builder Pattern
- MqlTradeRequest
- OrderSend
- OrderCheck
- Trade Framework
- RiskManager
- TradeExecutor
- EA Architecture
