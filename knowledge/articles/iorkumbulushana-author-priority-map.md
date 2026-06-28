# Ushana Kevin Iorkumbul 文章优先级地图

来源：

- 作者主页：https://www.mql5.com/en/users/iorkumbulushana
- 作者：Ushana Kevin Iorkumbul
- 核验日期：2026-06-27

## 总体判断

这个作者的高价值文章主要不是交易策略，而是 MQL5 工程基础设施：

```text
Data Pipeline
Calendar / News Filter
State Persistence
Event Bus
Order Builder
Object Pool
Repository / Decorator / State Machine
Statistical Diagnostics
```

对当前目标：

```text
MQL5 + Python + DuckDB + 因子研究 + ML
```

他的文章价值在于补齐 EA 框架的底层模块，而不是寻找单个 Alpha。

## S 级：必须收藏

### 1. News Filtering with MetaTrader 5 Economic Calendar and CSV Fallback

链接：https://www.mql5.com/en/articles/22580

作者主页摘要：

```text
Self-contained news filter module.
Economic calendar API.
Symbol-to-currency mapping.
Pre/post-event trading pauses.
Optional position size reduction.
CSV fallback for Strategy Tester.
Dashboard.
```

收藏价值：★★★★★

应落地模块：

```text
CalendarEngine
│
├── Economic Calendar Provider
├── Symbol → Currency Mapper
├── CSV Fallback Provider
├── Quiet Period Filter
├── High Impact Day Risk Reducer
└── Dashboard / Diagnostics
```

与现有仓库关系：

- 已收录精华：[News Filtering：Economic Calendar + CSV Fallback](./news-filter-calendar-csv-fallback.md)
- 已收录源码：`examples/mql5/NewsFilter/`
- 已有基础版：[Economic Calendar API](./economic-calendar-api-event-feature.md)
- 已有示例：`examples/mql5/EconomicCalendarAPI/CalendarEngine.mqh`

后续可继续升级：

- 增加 Strategy Tester CSV fallback；
- 增加 symbol-to-currency mapping；
- 增加 position size reduction hook；
- 增加 dashboard diagnostics。

### 2. Keeping Memory Across Restarts: EA State Persistence Using Binary Files in MQL5

链接：https://www.mql5.com/en/articles/22277

作者主页摘要：

```text
Serialize EA internal state into local binary files.
Prevent data resets during platform restarts.
Persist trade counts, multipliers and volatile tracking metrics.
Alternative to terminal Global Variables.
```

收藏价值：★★★★★

已收录：

- 精华：[State Persistence：Binary EA State Manager](./state-persistence-binary-files-mql5.md)
- 源码：`examples/mql5/StatePersistence/`

应落地模块：

```text
StateManager
│
├── Save()
├── Load()
├── Reset()
├── Version()
├── Validate()
└── AtomicWrite()
```

适合保存：

- martingale level；
- grid state；
- trade count；
- recovery mode；
- last signal；
- last processed ticket；
- per-magic strategy state；
- drawdown guard state。

关键判断：

```text
这是 EA 框架必需基础设施。
很多 EA 回测正常，实盘重启后失效，本质就是缺少状态持久化。
```

### 3. CSV Data Analysis 系列

链接总览：[CSV Data Analysis 系列](./csv-data-analysis-series-research-platform.md)

收藏价值：★★★★★

已收录：

- Part 2 单篇：[CSV Export / Parsing Pipeline](./csv-export-parsing-pipeline-mql5.md)
- 系列总览：[CSV Data Analysis 系列：MT5 → Python 研究平台的数据管线](./csv-data-analysis-series-research-platform.md)

长期方向：

```text
CSV → DuckDB / Socket / IPC
```

核心价值：

- optimization export；
- production CSV IO；
- Python analytics；
- baseline comparison；
- walk-forward；
- live streaming；
- dashboard。

## A 级：框架强相关

### 4. Building a Type-Safe Event Bus in MQL5

链接：https://www.mql5.com/en/articles/22930

作者主页摘要：

```text
Typed publish-subscribe event bus.
No global variables.
Signal engine, order manager and drawdown monitor communicate through bus.
Enum-indexed subscription table.
Dispatch overhead, pointer validation and recursive publish risks.
```

收藏价值：★★★★★

应落地模块：

```text
EventBus
│
├── Subscribe(event_type, listener)
├── Publish(event)
├── Unsubscribe(listener)
├── GuardRecursivePublish()
└── DispatchDiagnostics()
```

适合当前框架：

```text
MarketDataEvent
SignalEvent
RiskEvent
OrderEvent
TradeEvent
CalendarEvent
DrawdownEvent
```

判断：

```text
如果后续要做模块化 EA，这是核心基础设施。
```

### 5. Implementing a Fluent Interface Builder Pattern for MQL5 Order Construction

链接：https://www.mql5.com/en/articles/22936

作者主页摘要：

```text
Manual MqlTradeRequest population creates silent misconfiguration.
COrderBuilder adds pointer-based method chaining.
Per-field validation.
Directional SL/TP checks.
Broker stop-level constraints.
Four-stage gate: flag completeness, cross-field consistency, OrderCheck, OrderSend.
```

收藏价值：★★★★★

应落地模块：

```text
OrderBuilder
│
├── Symbol()
├── Type()
├── Volume()
├── Price()
├── StopLoss()
├── TakeProfit()
├── Magic()
├── Comment()
├── Validate()
├── Check()
└── Send()
```

价值：

- 避免手写 `MqlTradeRequest`；
- 避免方向性 SL/TP 错误；
- 将 broker stop-level 检查前置；
- 让 Execution Layer 可测试。

### 6. A Generic Object Pool in MQL5

链接：https://www.mql5.com/en/articles/22947

作者主页摘要：

```text
Generic templated object pool.
Free-list index array.
O(1) Acquire / Release.
Double-release protection.
Strict separation of payload state from pool metadata.
Fixed-capacity free list.
Benchmark with GetMicrosecondCount().
```

收藏价值：★★★★☆

应落地模块：

```text
ObjectPool<T>
│
├── Acquire()
├── Release()
├── ResetPayload()
├── Capacity()
├── ActiveCount()
└── FreeCount()
```

适用：

- 高频 indicator；
- tick feature objects；
- chart object wrappers；
- event objects；
- temporary signal records。

判断：

```text
不是所有 EA 都需要，但高频/复杂框架需要。
```

### 7. Designing a Strategy State Machine in MQL5

链接：https://www.mql5.com/en/articles/22950

作者主页摘要：

```text
Replace nested if-else logic with formal states.
IState interface.
CStrategyContext mediator.
Four concrete states.
Three-file include structure resolves circular dependencies.
```

收藏价值：★★★★★

应落地模块：

```text
StrategyStateMachine
│
├── IState
├── StrategyContext
├── Transition()
├── OnEnter()
├── OnTick()
└── OnExit()
```

适合：

- grid / recovery mode；
- news-risk state；
- session state；
- drawdown state；
- signal lifecycle；
- position lifecycle。

### 8. Carry Trade Logic in MQL5

链接：https://www.mql5.com/en/articles/22175

作者主页摘要：

```text
Retrieve real-time swap data.
Convert swap into account-currency profit/loss.
Determine whether long-term trade is worth holding.
Adjust position size based on expected interest.
```

收藏价值：★★★★☆

应落地模块：

```text
CarryCostEngine
│
├── LongSwap()
├── ShortSwap()
├── EstimateHoldingCost(days)
├── NetExpectedCarry()
├── AdjustPositionSize()
└── ShouldHold()
```

适用：

- trend following；
- multi-day breakout；
- carry basket；
- portfolio holding decision；
- overnight risk filter。

判断：

```text
短线策略价值一般，隔夜/中长线策略必须考虑。
```

## A- 级：已收录或部分收录的工程模式

### Repository Pattern

链接：https://www.mql5.com/en/articles/22958

已收录：

- [Repository Pattern in MQL5：可测试 EA Analytics 架构](./repository-pattern-testable-ea-analytics.md)

价值：

```text
将 History API 从 analytics 中抽离，支持 live repository 和 mock repository。
```

### Decorator Pattern

链接：https://www.mql5.com/en/articles/22962

已收录：

- [Decorator Pattern in MQL5：从指标包装到因子处理 Pipeline](./decorator-pattern-indicator-factor-pipeline.md)

价值：

```text
Logging / timing / threshold filtering 不侵入 indicator 本体。
```

### Rolling Sharpe

链接：https://www.mql5.com/en/articles/22978

已收录：

- [Rolling Sharpe：带统计显著性区间的策略诊断组件](./rolling-sharpe-statistical-significance-bands.md)

价值：

```text
O(1) rolling stats + statistical significance bands。
```

### Kalman Smoother

链接：https://www.mql5.com/en/articles/23016

已收录：

- [Adaptive Kalman Smoother：把 Kalman Gain 当作市场状态因子](./adaptive-kalman-smoother-regime-factor.md)

价值：

```text
Kalman Gain 作为 regime / confidence feature。
```

## B 级：按需收藏

### Leak-Free Multi-Timeframe Engine with Closed-Bar Reads

链接：https://www.mql5.com/en/articles/22363

收藏价值：★★★★☆

已收录：

- 精华：[Leak-Free MTF Engine：闭合 K 线多周期特征引擎](./leak-free-mtf-engine-closed-bar.md)
- 源码：`examples/mql5/MTFEngine/`

应落地模块：

```text
MTFEngine
│
├── Handle Registry
├── ClosedBarRead(index=1)
├── ReleaseAll()
├── NoRepaintGuard()
└── MultiTF Snapshot
```

价值：

- 避免 indicator handle 泄漏；
- 默认读取闭合 K 线；
- 避免 forming bar repaint；
- 多周期信号一致性。

### Linear Regression Prediction Channels

链接：https://www.mql5.com/en/articles/23130

收藏价值：★★★★☆

价值：

- rolling OLS；
- Student's t confidence band；
- prediction band；
- leverage-driven widening；
- 比固定标准差通道更严谨。

建议归类：

```text
Statistical Channels / Regression Diagnostics
```

## 推荐落地顺序

如果按当前框架缺口排序：

| 优先级 | 模块 | 对应文章 |
|---:|---|---|
| 1 | CalendarEngine v2 + CSV Fallback | News Filtering |
| 2 | StateManager | Keeping Memory Across Restarts |
| 3 | EventBus | Type-Safe Event Bus |
| 4 | OrderBuilder | Fluent Interface Builder |
| 5 | StrategyStateMachine | Strategy State Machine |
| 6 | MTFEngine | Leak-Free MTF Engine |
| 7 | ObjectPool | Generic Object Pool |
| 8 | CarryCostEngine | Carry Trade Logic |
| 9 | RegressionChannelEngine | Linear Regression Prediction Channels |

## 建议框架归档

```text
examples/mql5/
│
├── EconomicCalendarAPI/        # 已有基础版
├── StatePersistence/
├── EventBus/
├── OrderBuilder/
├── StrategyStateMachine/
├── MTFEngine/
├── ObjectPool/
├── CarryCostEngine/
└── RegressionChannels/
```

Python 研究侧：

```text
research/
│
├── event_features/
├── stateful_backtest/
├── execution_sim/
├── walkforward/
├── diagnostics/
└── reports/
```

## 最终判断

Ushana Kevin Iorkumbul 的高价值文章可以归纳为一句话：

```text
他写的不是“策略”，而是把 MT5 变成可维护研究/执行平台所需的基础设施。
```

对当前项目，优先收藏顺序应是：

```text
Calendar / State / EventBus / OrderBuilder / Data Pipeline
```

其次才是具体指标、通道或交易逻辑。
