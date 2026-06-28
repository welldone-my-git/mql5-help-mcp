# 后续任务记录

## MQL5 文章知识累积

状态：待持续补充

目标：用户可以逐篇提供 MQL5 网站文章、代码片段或策略说明，将其沉淀为项目知识资产，用于扩展：

- 代码示例库
- EA 模板
- 常用策略示例
- CTrade / 指标 / 订单管理最佳实践
- 常见错误修复与诊断知识

建议每篇文章提供：

```text
1. 来源链接
2. 文章正文、重点段落或代码片段
3. 希望沉淀方向：示例库 / 错误库 / 最佳实践 / 策略模板
4. 如有：已知坑点、回测参数、适用品种/周期
```

处理原则：

- 不直接整篇搬运第三方文章作为再分发内容。
- 保留来源链接和摘要。
- 提取结构化笔记、关键 API、适用场景、常见坑。
- 示例代码优先重写为项目自有版本。
- 有价值的内容可进一步落到 `examples/`、知识库条目、错误库测试或文档索引。

恢复上下文提示：

> 继续“MQL5 文章知识累积”任务。根据用户提供的 MQL5 文章，提取知识、最佳实践和示例代码，并按项目结构沉淀。

### 已处理文章

- `knowledge/articles/adaptive-kalman-smoother-regime-factor.md` — Adaptive Kalman Smoother：把 Kalman Gain 当作市场状态因子
- `knowledge/articles/breakeven-framework-atr-rrr-mql5.md` — BreakEven Framework：ATR / RRR 保本机制的可插拔架构
- `knowledge/articles/chart-object-detector-geometry-layer.md` — Chart Object Detector：从手动画线到 Geometry Layer
- `knowledge/articles/complex-object-geometry-engine.md` — Complex Object Geometry：Fibonacci、Channel、Pitchfork 的几何抽象层
- `knowledge/articles/csv-export-parsing-pipeline-mql5.md` — CSV Data Analysis Part 2：MQL5 到 Python 的 CSV 数据出口层
- `knowledge/articles/csv-data-analysis-series-research-platform.md` — CSV Data Analysis 系列：MT5 → Python 研究平台的数据管线
- `knowledge/articles/afml-microstructure-feature-pipeline-python.md` — Feature Engineering for ML Part 5：微观结构 Feature Pipeline 架构
- `knowledge/articles/afml-microstructure-features-mql5.md` — Feature Engineering for ML Part 6：AFML 微观结构特征工程
- `knowledge/articles/da-cg-lstm-dynamic-feature-attention.md` — DA-CG-LSTM：动态特征注意力与时序注意力
- `knowledge/articles/decorator-pattern-indicator-factor-pipeline.md` — Decorator Pattern in MQL5：从指标包装到因子处理 Pipeline
- `knowledge/articles/deepar-probabilistic-forecasting-python.md` — DeepAR：多序列概率预测在交易研究中的位置
- `knowledge/articles/arima-forecasting-baseline-python.md` — ARIMA：传统时间序列预测 baseline
- `knowledge/articles/dsu-dbn-wizard-signal-event-cluster.md` — MQL5 Wizard Part 95：DSU + DBN Signal 的事件聚类信号架构
- `knowledge/articles/economic-calendar-api-event-feature.md` — Economic Calendar API：从新闻挂单 EA 提炼事件因子模块
- `knowledge/articles/discord-notification-mql5-webhook.md` — Discord Notification：MQL5 到 Discord 的通知桥
- `knowledge/articles/type-safe-event-bus-mql5.md` — Type-Safe Event Bus：用事件总线解耦 EA 组件
- `knowledge/articles/markov-chain-matrix-state-engine.md` — Markov Chain Matrix：从二元频率统计提炼状态引擎骨架
- `knowledge/articles/meta-labeling-adx-hpo-gate-bet-sizing.md` — Meta-Labeling the Classics Part 2：ADX HPO Gate、Meta Model 与 Bet Sizing
- `knowledge/articles/meta-labeling-rsi-primary-meta-bet-sizing.md` — Meta-Labeling the Classics Part 1：RSI 信号过滤与 Bet Sizing
- `knowledge/articles/suffix-autoencoder-confidence-money-management.md` — MQL5 Wizard Part 93：Suffix Automaton + AutoEncoder 的置信度资金管理
- `knowledge/articles/multi-head-attention-ai-framework-architecture.md` — Multi-Head Attention：MQL5 神经网络架构模板
- `knowledge/articles/omegajoctan-author-research-map.md` — Omega J. Msigwa 文章研究路线图
- `knowledge/articles/mql5-bootstrap-file-io-pythonic-facade.md` — MQL5 Bootstrap：Pythonic File IO Facade
- `knowledge/articles/mql5-bootstrap-logging-pythonic-facade.md` — MQL5 Bootstrap：Python-like Logging Facade
- `knowledge/articles/mql5-bootstrap-requests-webrequest-facade.md` — MQL5 Bootstrap：Python Requests / WebRequest Facade
- `knowledge/articles/mql5-bootstrap-schedule-pythonic-facade.md` — MQL5 Bootstrap：Python Schedule 风格定时任务模块
- `knowledge/articles/mql5-bootstrap-sqlite3-facade.md` — MQL5 Bootstrap：SQLite3 Inspired 本地结构化存储
- `knowledge/articles/mql5-bootstrap-position-order-helpers.md` — MQL5 Bootstrap：Positions / Orders 可复用基础库
- `knowledge/articles/fluent-order-builder-trade-framework.md` — Fluent Order Builder：从 COrderBuilder 到可维护下单框架
- `knowledge/articles/mql5-objects-iii-chart-event-gui.md` — From Basic to Intermediate: Objects (III)：MQL5 图表事件与对象交互
- `knowledge/articles/generic-object-pool-high-frequency-mql5.md` — Generic Object Pool in MQL5：高频指标里的对象池基础设施
- `knowledge/articles/g-channel-recursive-trend-channel.md` — G Channel：由价格极值驱动的递推趋势通道
- `knowledge/articles/carry-cost-engine-swap-risk-mql5.md` — Carry Cost Engine：把 Swap 纳入持仓收益和仓位决策
- `knowledge/articles/custom-symbols-synthetic-stress-tests.md` — Custom Symbols / Synthetic Markets：用 MT5 构建研究市场和压力测试
- `knowledge/articles/biased-financial-markets-imbalanced-ml.md` — Biased Financial Markets：金融 ML 的类别不平衡问题
- `knowledge/articles/Better_Programmer.md` — Better Programmer 系列：MQL5 工程习惯与可复用开发方法
- `knowledge/articles/market-structure-graph-ford-fulkerson-liquidity.md` — Graph Theory / Ford-Fulkerson：把 ICT 市场结构转成图网络
- `knowledge/articles/geometry-interaction-event-layer.md` — Geometry Interaction：从几何对象到事件、特征与执行层
- `knowledge/articles/inside-bar-hypothesis-research-ea.md` — 002 - Inside Bar：把 Price Action 模式当作假设验证器
- `knowledge/articles/kyles-lambda-market-impact-liquidity-factor.md` — Institutional Kyle's Lambda Market Impact Engine：市场冲击与流动性因子
- `knowledge/articles/iorkumbulushana-author-priority-map.md` — Ushana Kevin Iorkumbul 文章优先级地图
- `knowledge/articles/local-stop-loss-ea-framework.md` — Local Stop Loss EA：用 HashMap 和对象管理构建 EA Framework
- `knowledge/articles/lgmm-hidden-regime-detection.md` — LGMM：指标数据中的 Hidden Pattern / Regime Detection
- `knowledge/articles/nbeats-time-series-forecasting-python.md` — N-BEATS：深度时间序列预测模型样例
- `knowledge/articles/qnn-markov-feature-pipeline-mql5.md` — Quantum Neural Network in MQL5 Part II：Markov 状态建模与 Feature Pipeline
- `knowledge/articles/repository-pattern-testable-ea-analytics.md` — Repository Pattern in MQL5：可测试 EA Analytics 架构
- `knowledge/articles/regression-causal-inference-confidence-trading.md` — Regression + Causal Inference Trading Pipeline：收益回归与可信度过滤
- `knowledge/articles/recurrence-analysis-library-series.md` — Recurrence Analysis 系列：RQA / CRQA / JRQA / RNA 非线性动力系统特征库
- `knowledge/articles/crqa-cross-recurrence-library.md` — CRQA：两个时间序列之间的 Cross Recurrence 特征库
- `knowledge/articles/jrqa-joint-recurrence-library.md` — JRQA：双系统同步 recurrence 的 Regime 特征库
- `knowledge/articles/rna-recurrence-network-analysis.md` — RNA：从 Recurrence Matrix 到复杂网络特征
- `knowledge/articles/python-mt5-strategy-tester-series.md` — Python-MetaTrader 5 Strategy Tester 系列：Python 研究与 RL 环境基础
- `knowledge/articles/prophet-calendar-forecasting-python.md` — Prophet：带趋势/季节性/日历效应的预测 baseline
- `knowledge/articles/rqa-complete-analysis-library-mql5.md` — RQA Library：Recurrence Quantification Analysis 完整分析组件
- `knowledge/articles/rolling-sharpe-statistical-significance-bands.md` — Rolling Sharpe：带统计显著性区间的策略诊断组件
- `knowledge/articles/session-boxes-session-range-feature.md` — Session Boxes：Session Range 可视化到特征工程骨架
- `knowledge/articles/strategy-state-machine-mql5.md` — Strategy State Machine：用显式状态替代嵌套 if-else
- `knowledge/articles/tda-takens-embedding-point-cloud-distance.md` — TDA Takens Embedding：时间序列到几何对象的基础库
- `knowledge/articles/transformer-trading-sequence-model.md` — Transformer Trading：序列模型研究素材，不是直接 Alpha
- `knowledge/articles/var-multivariate-forecasting-python.md` — VAR：多变量时间序列预测 baseline
- `knowledge/articles/bootstrap-datetime-sqlite-omega.md` — Omega Python-like Modules：Datetime 与 SQLite 基础设施
- `knowledge/articles/tickvalue-compare-broker-risk-diagnostics.md` — TickValue Compare：Broker Tick Value 风控诊断工具
- `knowledge/articles/universal-breakout-study-research-framework.md` — Universal Breakout Study：Session Range 突破策略研究框架
- `knowledge/articles/weekend-gap-state-machine-buffer-interface.md` — Weekend Gap Signal System：市场事件状态机与 EA Buffer 接口
- `knowledge/articles/weekend-gap-object-framework.md` — Weekend Gap Structure Mapping：Chart Object 状态管理框架
- `knowledge/articles/zscore-object-oriented-engine-mql5.md` — Z-Score OOP Engine：EA / Indicator 共用的统计信号引擎
