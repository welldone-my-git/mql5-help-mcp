# 示例代码库

这里保存从文章、代码片段和用户提供源码中整理出的可复用示例。

原则：

- 示例代码用于学习、二次开发和框架抽取，不默认代表可直接实盘交易。
- 第三方来源应保留原始说明、来源背景和适用边界。
- 如果后续改写为项目自有实现，应补充测试、风险说明和版本记录。

## MQL5

- [Bootstrap File IO](./mql5/Bootstrap_FileIO/) — MQL5 Bootstrap 文件 IO facade，重点是 `CFile`、`CFileIO::open()`、Python-like mode、CSVReader/CSVWriter 和 `FILE_COMMON` bridge。
- [Bootstrap Datetime](./mql5/Bootstrap_Datetime/) — Python-like time/date/datetime 模块，重点是 timezone、session/calendar/schedule 相关时间处理。
- [Bootstrap Logging](./mql5/Bootstrap_Logging/) — MQL5 Bootstrap 日志 facade，重点是 `CLogger`、日志等级、formatter、file rotation、cache mode 和 `FILE_COMMON` diagnostics。
- [Bootstrap Requests](./mql5/Bootstrap_Requests/) — MQL5 Bootstrap WebRequest facade，重点是 `CSession`、`CResponse`、HTTP verbs、JSON、multipart、headers/cookies 和 Python API bridge。
- [Bootstrap SQLite](./mql5/Bootstrap_SQLite/) — Python sqlite3-inspired MQL5 database facade，重点是本地结构化存储、cache 和 state persistence。
- [Bootstrap Trade Helpers](./mql5/Bootstrap_TradeHelpers/) — MQL5 Bootstrap 基础库样例，重点是 positions/orders 通用筛选、计数、关闭、取消、recent/oldest 查询。
- [Chart Object Detector](./mql5/ChartObjectDetector/) — Chart Geometry Layer 基础样例，重点是图表对象扫描、类型识别、属性读取和 `SChartObjectInfo` 标准化结构。
- [Complex Object Geometry](./mql5/ComplexObjectGeometry/) — Chart Geometry Engine 核心样例，重点是复杂分析对象过滤、Fib level 解析、Channel 三点采集和 Pitchfork 结构化。
- [Geometry Interaction](./mql5/GeometryInteraction/) — Chart Geometry Interaction 样例，重点是 `SInteraction`、Touch/Cross/Breakout 检测、状态去重、AlertManager 和 TradeExecutor 分层。
- [Economic Calendar API](./mql5/EconomicCalendarAPI/) — MT5 官方经济日历 API 与 `CalendarEngine` 骨架，重点是 `CalendarValueHistory()`、`CalendarEventById()`、High Impact 新闻过滤、QuietPeriod 和事件因子化。
- [EventBus](./mql5/EventBus/) — Type-safe publish-subscribe EA 事件总线，重点是 `IEventListener`、`SEventPayload`、enum-indexed subscription table 和组件解耦。
- [OrderBuilder](./mql5/OrderBuilder/) — Fluent `MqlTradeRequest` 构造器，重点是链式接口、字段完整性、方向性 SL/TP、stop-level 和 `OrderCheck()` 前置。
- [ObjectPool](./mql5/ObjectPool/) — 高频对象池基础设施，重点是 templated pool、free-list、O(1) acquire/release、double-release protection 和 benchmark。
- [Strategy State Machine](./mql5/StrategyStateMachine/) — 显式 EA 状态机样例，重点是 `IState`、`CStrategyContext`、`OnEnter/Evaluate/OnExit` 和 include 循环依赖拆分。
- [Carry Cost Engine](./mql5/CarryCostEngine/) — Swap / Carry 风控组件，重点是 swap 换算、预期持仓成本、是否值得持有和 carry-adjusted lot。
- [Custom Symbols Stress Tests](./mql5/CustomSymbolsStressTests/) — Custom Symbols / Synthetic Markets 样例，重点是 Renko/Range/Volume bars、synthetic ticks、spread stress test 和 custom order routing。
- [BreakEven Framework](./mql5/BreakEven_Framework/) — ATR / RRR / Simple 保本机制的可插拔 Trade Management 样例，重点是 Base、Manager、Factory、`MqlParam[]` 参数系统和多态策略。
- [Local Stop Loss EA](./mql5/Local_Stop_Loss/) — 本地止损 EA 架构样例，重点是 HashMap 仓位缓存、Position 状态机、Chart Object 生命周期和 Cleanup 管理。
- [MSNR Clean Edition](./mql5/MSNR_CleanEdition/) — 从 `MSNR_v531Plus_AEU1.mq5` 抽取的收藏版框架模板，包含 Signal Layer、Confluence Engine、Risk Guard、Trade Executor、CSV Logger 和 Dashboard 骨架。
- [RQA Library](./mql5/RQA_Library/) — Recurrence Quantification Analysis 完整库，重点是 recurrence matrix、RQA metrics、epsilon selection、rolling window 和 facade API。
- [Rolling Sharpe](./mql5/RollingSharpe/) — 统计分析组件样例，重点是 `CReturnBuffer`、O(1) rolling stats、Lo 标准误和 Sharpe 置信带。
- [Session Boxes](./mql5/SessionBoxes/) — Session Range 可视化指标，重点是 Asia/London/NY high-low box、GMT offset、跨午夜 session 判断和 session feature seed。
- [TDA Takens Embedding](./mql5/TDA_TakensEmbedding/) — TDA 基础库样例，重点是 Takens embedding、Point Cloud、flattened arrays 和 pairwise distance matrix。
- [TickValue Compare](./mql5/TickValueCompare/) — Broker 风控诊断工具，重点是三种 Tick Value 对比、Market Watch 扫描和 CSV 导出。
- [Weekend Gap Indicator](./mql5/WeekendGapIndicator/) — Chart Object Framework 样例，重点是 Entity、状态机、Visual Layer、对象生命周期和 Prefix 命名规范。
- [ZScore Source Essence](./mql5/ZScore_Source_Essence/) — Z-Score Signal Engine 样例，重点是 Engine 与 EA/Indicator 解耦、OncePerBar、生命周期管理和统一 `Value()` 接口。

## Research

- [Biased Financial Markets](./research/biased-financial-markets/) — 金融 ML 类别不平衡样例，重点是 resampling、metrics、ONNX 输出流程和时间序列验证风险。
- [DeepAR Forecasting](./research/deepar-forecasting/) — DeepAR 多序列概率预测样例，重点是 autoregressive neural forecasting、forecast uncertainty 和 Python research layer。
- [Microstructure Feature Pipeline](./research/microstructure-feature-pipeline/) — AFML Chapter 19 微观结构特征工程 Python 原型，包含 bar-level / tick-level 两层 Feature Pipeline、Numba kernels 和统一 Feature Matrix 输出。
- [Meta-Labeling ADX Pipeline](./research/meta-labeling-adx/) — Meta Labeling 系列 ADX 样例，重点是 ADX/DI primary signal、Optuna HPO Gate、ADX 特征、Triple Barrier、Meta Model 和 Bet Sizing。
- [Meta-Labeling RSI Pipeline](./research/meta-labeling-rsi/) — Lopez de Prado Meta Labeling 研究样例，重点是 Primary Signal、Triple Barrier、Meta Model、Probability Filter 和 Bet Sizing。
- [Python-MT5 Strategy Tester](./research/python-mt5-strategy-tester/) — Omega Python Strategy Tester 系列源码，重点是 MT5-like Python backtester、bars/ticks、trade simulator、多品种多周期和 RL 环境基础。
- [Transformer Trading](./research/transformer-trading/) — Transformer 序列模型交易实验，重点是 sequence tensor、attention encoder、feature extraction 和严格 walk-forward 验证。
