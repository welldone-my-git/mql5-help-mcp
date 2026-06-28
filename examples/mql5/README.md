# MQL5 示例

## Bootstrap File IO

路径：[Bootstrap_FileIO](./Bootstrap_FileIO/)

定位：

```text
Bootstrap File IO / Python Bridge 基础组件。
```

核心学习点：

- `CFile` 封装 file handle；
- `CFileIO::open()` 模仿 Python open mode；
- `flagsgen()` 统一生成 MQL5 file flags；
- append 模式自动 seek 到文件尾；
- `CSVReader` / `CSVWriter` 与通用 File IO 解耦；
- `FILE_COMMON` 支持 MQL5 与 Python 共享文件。

## Bootstrap Datetime

路径：[Bootstrap_Datetime](./Bootstrap_Datetime/)

定位：

```text
MQL5 Bootstrap / Python-like DateTime Utilities。
```

核心学习点：

- Python-like time/date/datetime facade；
- timezone database；
- `TZInfo`；
- 对 CalendarEngine、session filter、schedule engine 有直接价值。

## Bootstrap Logging

路径：[Bootstrap_Logging](./Bootstrap_Logging/)

定位：

```text
Bootstrap Diagnostics / Python-like Logging 基础组件。
```

核心学习点：

- `CLogger` 封装日志输出；
- `LogLevels` 统一 DEBUG / INFO / WARNING / ERROR / CRITICAL；
- `basicConfig()` 统一配置日志等级、文件名、格式、console、common folder 和缓存模式；
- formatter placeholder 支持时间、等级、程序名、函数名、行号、程序类型和消息；
- file rotation 防止长期运行日志无限增长；
- cache mode 降低高频文件写入成本。

## Bootstrap SQLite

路径：[Bootstrap_SQLite](./Bootstrap_SQLite/)

定位：

```text
MQL5 Bootstrap / SQLite3-inspired Database Facade。
```

核心学习点：

- Python sqlite3-style interface；
- MQL5 database API facade；
- local structured storage；
- state cache；
- tester output storage。

## Bootstrap Requests

路径：[Bootstrap_Requests](./Bootstrap_Requests/)

定位：

```text
Bootstrap Integration / Python requests-style WebRequest 基础组件。
```

核心学习点：

- `CResponse` 统一封装 HTTP status、text、json、headers、content、elapsed、ok 和 reason；
- `CSession` 封装 headers、cookies、basic auth 和请求方法；
- `request()` 作为统一入口；
- `get/post/put/patch/delete_` 提供 Python-like helper；
- `URLEncode()` 与 `BuildUrlWithParams()` 避免手工拼 URL；
- 支持 JSON body 和 multipart file upload；
- `GuessContentType()` 根据扩展名推断 MIME type。

## Bootstrap Schedule

路径：[Bootstrap_Schedule](./Bootstrap_Schedule/)

定位：

```text
MQL5 Bootstrap / Python schedule-style Timer Orchestration。
```

核心学习点：

- 用 Python `schedule` 思路封装 MQL5 `OnTimer()`；
- 将周期任务从 EA 主逻辑中分离；
- 适合 Calendar refresh、Risk check、Storage flush、状态同步；
- 对 `core/clock.py` 和后续 runtime scheduler 有参考价值。

## Better Programmer

路径：[BetterProgrammer](./BetterProgrammer/)

定位：

```text
MQL5 Engineering Practice / Reusable Include 示例。
```

来源：

- Better Programmer Part 06：https://www.mql5.com/en/articles/9923
- 附件源码：`gridmodule.mqh`

核心学习点：

- 把多个 Grid EA 都会重复写的 position helper 提取为 `.mqh`；
- `CGrid::CountPositions(type)` 统计指定方向持仓；
- `CGrid::LastPositionOpenPrice(type)` 获取指定方向最新持仓开仓价；
- `InitializeModule(magic)` 用 Magic Number 约束查询范围；
- 适合学习 include 抽取，不适合直接作为生产级 Grid 模块。

## Bootstrap Trade Helpers

路径：[Bootstrap_TradeHelpers](./Bootstrap_TradeHelpers/)

定位：

```text
EA Bootstrap / Trade Helper Layer 收藏样例。
```

核心学习点：

- `PositionExists()` / `OrderExists()` 通用筛选函数；
- `PositionCount()` / `OrderCount()` 统一计数；
- `PositionClose()` / `CancelOrders()` 批量处理；
- recent / oldest position 和 order 查询；
- 将账户状态扫描从 EA signal 层剥离出来。

## TickValue Compare

路径：[TickValueCompare](./TickValueCompare/)

定位：

```text
Risk Management / Broker Diagnostics 开发工具。
```

核心学习点：

- 读取 `SYMBOL_TRADE_TICK_VALUE`；
- 读取 `SYMBOL_TRADE_TICK_VALUE_LOSS`；
- 读取 `SYMBOL_TRADE_TICK_VALUE_PROFIT`；
- 使用 `SymbolsTotal(true)` / `SymbolName(i,true)` 遍历 Market Watch；
- 分类 tick value 一致性；
- CSV 导出供 Python 做 broker audit。

## Chart Object Detector

路径：[ChartObjectDetector](./ChartObjectDetector/)

定位：

```text
Chart Geometry Layer / Object Abstraction 基础样例。
```

核心学习点：

- `ObjectsTotal()` / `ObjectName()` 枚举图表对象；
- `ObjectFind()` 做安全检查；
- `OBJPROP_TYPE` 读取对象类型；
- `ObjectGetInteger()` / `ObjectGetDouble()` 读取 anchor；
- `SChartObjectInfo` 统一不同对象的数据结构；
- `CChartObjectDetector::Detect()` 作为 scanner / normalizer 统一入口。

## Complex Object Geometry

路径：[ComplexObjectGeometry](./ComplexObjectGeometry/)

定位：

```text
Chart Geometry Engine / Complex Analytical Object Collector。
```

核心学习点：

- `IsAnalyticalObject()` 过滤复杂分析对象；
- `SComplexObjectInfo` 继承 `SChartObjectInfo` 扩展复杂几何字段；
- `CComplexObjectDetector` 继承基础 detector；
- Fibonacci levels 解析为 ratio 和 actual price；
- Channel 三个 anchor 点采集；
- Pitchfork handle、median point、additional levels 采集；
- demo 中 `LineValueAtTime()` / `PitchforkMedianValue()` 展示几何投影计算。

## Geometry Interaction

路径：[GeometryInteraction](./GeometryInteraction/)

定位：

```text
Chart Geometry Interaction / Event Layer 样例。
```

核心学习点：

- `ENUM_INTERACTION` 统一 interaction 类型；
- `SInteraction` 将几何交互变成事件记录；
- `CInteractionDetector` 从复杂对象检测 Touch / Cross / Breakout；
- per-object state tracking 避免重复触发；
- `AlertManager` 做 duplicate suppression；
- `TradeExecutor` 演示 signal 与 execution 分离；
- `TestInteractionEA` 展示 detector → alert → trade 的完整管线。

## Economic Calendar API

路径：[EconomicCalendarAPI](./EconomicCalendarAPI/)

定位：

```text
Event Feature / Economic Calendar API 使用样例。
```

核心学习点：

- `CalendarValueHistory()` 读取时间区间内的经济日历值；
- `CalendarEventByCurrency()` 查询指定货币事件；
- `CalendarEventById()` 获取事件名称和 importance；
- `CALENDAR_IMPORTANCE_HIGH` 做红色新闻过滤；
- `CalendarEngine.mqh` 封装缓存、过滤、NextNews、QuietPeriod 和 RedNews 判断；
- 新闻发布时间与 `TimeTradeServer()` 的窗口判断；
- 将新闻事件重构为 `CalendarEngine`、`IsQuietPeriod()` 和 `RedNewsWithin()`；
- 作为 ML / Meta Label 的 `minutes_to_news`、`news_importance`、`is_red_news_window` 事件特征。

## EventBus

路径：[EventBus](./EventBus/)

定位：

```text
EA Framework / Typed Publish-Subscribe Event Bus。
```

核心学习点：

- `ENUM_EA_EVENT` 统一事件类型；
- `SEventPayload` 作为轻量事件结构；
- `IEventListener::OnEvent()` 抽象监听接口；
- `CEventBus::Subscribe()` / `Unsubscribe()` / `Publish()`；
- signal、order、drawdown monitor 通过事件通信，避免 global variable 和交叉引用。

## Discord Notification

路径：[DiscordNotification](./DiscordNotification/)

定位：

```text
MQL5 Notification Adapter / Webhook Alert。
```

核心学习点：

- Discord webhook message 封装；
- JSON payload 构造；
- emoji / formatting；
- 可迁移为 trade alert、risk alert、exception alert；
- 后续可扩展为 Telegram / Email / Webhook notification service。

## OrderBuilder

路径：[OrderBuilder](./OrderBuilder/)

定位：

```text
Execution Layer / Fluent Order Request Builder。
```

核心学习点：

- fluent chaining 封装 `MqlTradeRequest`；
- volume min/max/step 校验；
- market / pending order helper；
- buy/sell 方向性 SL/TP 检查；
- broker stop-level 检查；
- `OrderCheck()` 前置到 `OrderSend()` 之前。

## ObjectPool

路径：[ObjectPool](./ObjectPool/)

定位：

```text
Performance Infrastructure / Generic Object Pool。
```

核心学习点：

- `CObjectPool<T>` 模板对象池；
- fixed-capacity free-list；
- O(1) `Acquire()` / `Release()`；
- pooled object metadata；
- double-release protection；
- `GetMicrosecondCount()` benchmark。

## Strategy State Machine

路径：[StrategyStateMachine](./StrategyStateMachine/)

定位：

```text
EA Framework / Formal State Machine。
```

核心学习点：

- `IState` 生命周期接口；
- `CStrategyContext` 作为 mediator；
- `OnEnter()` / `Evaluate()` / `OnExit()`；
- `SetState()` 集中处理状态切换；
- declaration / implementation 分离解决 include 循环依赖。

## Carry Cost Engine

路径：[CarryCostEngine](./CarryCostEngine/)

定位：

```text
Risk / Holding Cost / Carry-Aware Position Management。
```

核心学习点：

- `SYMBOL_SWAP_LONG` / `SYMBOL_SWAP_SHORT`；
- `SYMBOL_SWAP_MODE`；
- swap 换算到账户货币；
- Wednesday triple swap 估算；
- `ExpectedSwapForPosition()`；
- `IsWorthHolding()`；
- `CarryAdjustedLotSize()`。

## Session Boxes

路径：[SessionBoxes](./SessionBoxes/)

定位：

```text
Session Range / Chart Tool / Feature Engineering Seed。
```

核心学习点：

- H1 `CopyRates()` 构建 session high / low；
- `InpBrokerGMTOffset` 做 broker time → GMT；
- `IsHourInSession()` 支持跨午夜 session；
- `OBJ_RECTANGLE` 绘制 Asia / London / New York boxes；
- prefix 对象命名和 `ObjectsDeleteAll()` 生命周期清理；
- 可升级为 SessionFeatureEngine。

## Custom Symbols Stress Tests

路径：[CustomSymbolsStressTests](./CustomSymbolsStressTests/)

定位：

```text
MQL5 Research Infrastructure / Custom Symbols / Synthetic Data / Stress Testing。
```

核心学习点：

- MT5 custom symbols API；
- Renko / Range / Equal-Volume bar generation；
- synthetic tick generator；
- spread widening stress test；
- custom symbol order routing 到真实 symbol。

## BreakEven Framework

路径：[BreakEven_Framework](./BreakEven_Framework/)

定位：

```text
Trade Management / BreakEven Plugin Framework 收藏样例。
```

核心学习点：

- `CBreakEvenBase` 抽象基类；
- `CBreakEvenSimple` / `CBreakEvenAtr` / `CBreakEvenRR` 多态策略；
- `CBreakEven` Manager 与 `CreateBreakEven()` Factory；
- `MqlParam[]` 统一参数系统；
- ATR handle 生命周期管理；
- ticket 级 `position_be` 状态缓存。

## Local Stop Loss EA

路径：[Local_Stop_Loss](./Local_Stop_Loss/)

定位：

```text
EA 架构收藏样例，不是重点交易策略。
```

核心学习点：

- `CHashMap<ulong,double>` 管理 ticket → stop price；
- `PositionsCheck()` 扫描仓位；
- `ProcessPosition()` / `CheckProcessedPosition()` 表达仓位状态机；
- chart object 统一命名和清理；
- helper functions 拆分业务逻辑。

## MSNR Clean Edition

路径：[MSNR_CleanEdition](./MSNR_CleanEdition/)

定位：

```text
收藏版 / 二次开发模板，不是直接实盘 EA。
```

保留模块：

- Signal Layer / Confluence Engine
- Price Cluster
- Session Filter
- Spread Filter
- Risk Percent LotSizer
- Drawdown Guard
- Trade Executor 骨架
- CSV Logger
- Dashboard 骨架

推荐导入 MT5 的方式：

```text
MQL5/Include/MSNR_Clean/
MQL5/Experts/MSNR_CleanCollector.mq5
```

单文件版：

```text
MSNR_CleanEdition/MSNR_CleanEdition_SingleFile.mq5
```

## RQA Library

路径：[RQA_Library](./RQA_Library/)

定位：

```text
Nonlinear Dynamics / Recurrence Feature Engine 收藏样例。
```

核心学习点：

- `CRQAMatrix` 构建 recurrence matrix；
- `CRQAMetrics` 输出 RR、DET、LAM、ENTR、TREND 等指标；
- `CRQAEpsilon` 管理 fixed / std fraction / range fraction / RR target；
- `CRQAWindow` 输出 rolling metric series；
- `CRQA` facade 提供统一入口；
- `SRQAResult` 统一承载完整 RQA 指标。

## CRQA Library

路径：[CRQA_Library](./CRQA_Library/)

定位：

```text
Nonlinear Dynamics / Cross Recurrence Feature Engine。
```

核心学习点：

- dual-series embedding；
- cross recurrence matrix；
- CRR / CDET / CLAM / CENTR；
- rolling CRQA；
- pair trading / intermarket / lead-lag research 特征。

## JRQA Library

路径：[JRQA_Library](./JRQA_Library/)

定位：

```text
Nonlinear Dynamics / Joint Recurrence Feature Engine。
```

核心学习点：

- joint recurrence matrix；
- dual epsilon configuration；
- JRR / JDET / JLAM / JENTR / JTREND；
- OpenCL acceleration + CPU fallback；
- regime synchronization / market resonance。

## RNA Library

路径：[RNA_Library](./RNA_Library/)

定位：

```text
Nonlinear Dynamics / Recurrence Network Feature Engine。
```

核心学习点：

- recurrence matrix → adjacency matrix；
- clustering coefficient；
- average path length；
- betweenness；
- assortativity；
- density；
- rolling RNA / joint RNA；
- complex network regime features。

## Rolling Sharpe

路径：[RollingSharpe](./RollingSharpe/)

定位：

```text
Statistical Analytics 收藏样例，不是交易策略。
```

核心学习点：

- `CReturnBuffer.mqh` 固定长度循环缓冲；
- `m_sum` / `m_sumSq` 增量维护 rolling mean / variance；
- `CSharpeCalculator.mqh` 负责 Sharpe 与标准误计算；
- `SSharpeResult` 统一返回结果、置信带和有效标志；
- `ComputeBar()` 无状态计算适配 MT5 完整重算行为。

## TDA Takens Embedding

路径：[TDA_TakensEmbedding](./TDA_TakensEmbedding/)

定位：

```text
Quant Research / Geometry Feature Engine 基础库样例。
```

核心学习点：

- `CTDAPointCloud` 把一维价格序列转成 Takens point cloud；
- `CTDADistance` 把 point cloud 转成 pairwise distance matrix；
- `m_points[i * embDim + d]` 平铺点云存储；
- `m_D[i * N + j]` 平铺距离矩阵；
- `ENUM_TDA_NORM` 管理 Euclidean / Manhattan / Chebyshev；
- `Build()` 接口让对象可重复使用。

## Weekend Gap Indicator

路径：[WeekendGapIndicator](./WeekendGapIndicator/)

定位：

```text
Chart Object Framework / Visual State Machine 示例。
```

核心学习点：

- `WeekendGapRecord` Entity；
- `ENUM_GAP_STATE` 状态机；
- 一个业务对象由多个 chart objects 组成；
- `CreateGapObjects()` / `UpdateGapVisuals()` / `ObjectsDeleteAll()` 生命周期；
- `VisualSettings` 外观配置；
- `WG_` prefix 命名规范。

## ZScore Source Essence

路径：[ZScore_Source_Essence](./ZScore_Source_Essence/)

定位：

```text
Signal Engine / Feature Engine 收藏样例，不是完整交易策略。
```

核心学习点：

- `SignalEngineBase.mqh` 抽象统一信号接口；
- `ZScoreEngine_Essence.mqh` 把数学计算从 EA / Indicator 中拆出；
- `OncePerBar.mqh` 让 EA 每根新 K 线只执行一次；
- `CopyClose()` 返回值和零标准差保护；
- `new` / `delete` 与 `OnInit()` / `OnDeinit()` 生命周期管理。
