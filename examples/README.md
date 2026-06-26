# 示例代码库

这里保存从文章、代码片段和用户提供源码中整理出的可复用示例。

原则：

- 示例代码用于学习、二次开发和框架抽取，不默认代表可直接实盘交易。
- 第三方来源应保留原始说明、来源背景和适用边界。
- 如果后续改写为项目自有实现，应补充测试、风险说明和版本记录。

## MQL5

- [Bootstrap File IO](./mql5/Bootstrap_FileIO/) — MQL5 Bootstrap 文件 IO facade，重点是 `CFile`、`CFileIO::open()`、Python-like mode、CSVReader/CSVWriter 和 `FILE_COMMON` bridge。
- [Bootstrap Logging](./mql5/Bootstrap_Logging/) — MQL5 Bootstrap 日志 facade，重点是 `CLogger`、日志等级、formatter、file rotation、cache mode 和 `FILE_COMMON` diagnostics。
- [Bootstrap Requests](./mql5/Bootstrap_Requests/) — MQL5 Bootstrap WebRequest facade，重点是 `CSession`、`CResponse`、HTTP verbs、JSON、multipart、headers/cookies 和 Python API bridge。
- [Bootstrap Trade Helpers](./mql5/Bootstrap_TradeHelpers/) — MQL5 Bootstrap 基础库样例，重点是 positions/orders 通用筛选、计数、关闭、取消、recent/oldest 查询。
- [BreakEven Framework](./mql5/BreakEven_Framework/) — ATR / RRR / Simple 保本机制的可插拔 Trade Management 样例，重点是 Base、Manager、Factory、`MqlParam[]` 参数系统和多态策略。
- [Local Stop Loss EA](./mql5/Local_Stop_Loss/) — 本地止损 EA 架构样例，重点是 HashMap 仓位缓存、Position 状态机、Chart Object 生命周期和 Cleanup 管理。
- [MSNR Clean Edition](./mql5/MSNR_CleanEdition/) — 从 `MSNR_v531Plus_AEU1.mq5` 抽取的收藏版框架模板，包含 Signal Layer、Confluence Engine、Risk Guard、Trade Executor、CSV Logger 和 Dashboard 骨架。
- [RQA Library](./mql5/RQA_Library/) — Recurrence Quantification Analysis 完整库，重点是 recurrence matrix、RQA metrics、epsilon selection、rolling window 和 facade API。
- [Rolling Sharpe](./mql5/RollingSharpe/) — 统计分析组件样例，重点是 `CReturnBuffer`、O(1) rolling stats、Lo 标准误和 Sharpe 置信带。
- [TDA Takens Embedding](./mql5/TDA_TakensEmbedding/) — TDA 基础库样例，重点是 Takens embedding、Point Cloud、flattened arrays 和 pairwise distance matrix。
- [Weekend Gap Indicator](./mql5/WeekendGapIndicator/) — Chart Object Framework 样例，重点是 Entity、状态机、Visual Layer、对象生命周期和 Prefix 命名规范。
- [ZScore Source Essence](./mql5/ZScore_Source_Essence/) — Z-Score Signal Engine 样例，重点是 Engine 与 EA/Indicator 解耦、OncePerBar、生命周期管理和统一 `Value()` 接口。

## Research

- [Microstructure Feature Pipeline](./research/microstructure-feature-pipeline/) — AFML Chapter 19 微观结构特征工程 Python 原型，包含 bar-level / tick-level 两层 Feature Pipeline、Numba kernels 和统一 Feature Matrix 输出。
