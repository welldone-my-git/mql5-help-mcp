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
- `knowledge/articles/afml-microstructure-feature-pipeline-python.md` — Feature Engineering for ML Part 5：微观结构 Feature Pipeline 架构
- `knowledge/articles/afml-microstructure-features-mql5.md` — Feature Engineering for ML Part 6：AFML 微观结构特征工程
- `knowledge/articles/da-cg-lstm-dynamic-feature-attention.md` — DA-CG-LSTM：动态特征注意力与时序注意力
- `knowledge/articles/decorator-pattern-indicator-factor-pipeline.md` — Decorator Pattern in MQL5：从指标包装到因子处理 Pipeline
- `knowledge/articles/dsu-dbn-wizard-signal-event-cluster.md` — MQL5 Wizard Part 95：DSU + DBN Signal 的事件聚类信号架构
- `knowledge/articles/fluent-order-builder-trade-framework.md` — Fluent Order Builder：从 COrderBuilder 到可维护下单框架
- `knowledge/articles/mql5-objects-iii-chart-event-gui.md` — From Basic to Intermediate: Objects (III)：MQL5 图表事件与对象交互
- `knowledge/articles/generic-object-pool-high-frequency-mql5.md` — Generic Object Pool in MQL5：高频指标里的对象池基础设施
- `knowledge/articles/g-channel-recursive-trend-channel.md` — G Channel：由价格极值驱动的递推趋势通道
- `knowledge/articles/market-structure-graph-ford-fulkerson-liquidity.md` — Graph Theory / Ford-Fulkerson：把 ICT 市场结构转成图网络
- `knowledge/articles/inside-bar-hypothesis-research-ea.md` — 002 - Inside Bar：把 Price Action 模式当作假设验证器
- `knowledge/articles/kyles-lambda-market-impact-liquidity-factor.md` — Institutional Kyle's Lambda Market Impact Engine：市场冲击与流动性因子
- `knowledge/articles/qnn-markov-feature-pipeline-mql5.md` — Quantum Neural Network in MQL5 Part II：Markov 状态建模与 Feature Pipeline
- `knowledge/articles/repository-pattern-testable-ea-analytics.md` — Repository Pattern in MQL5：可测试 EA Analytics 架构
- `knowledge/articles/universal-breakout-study-research-framework.md` — Universal Breakout Study：Session Range 突破策略研究框架
- `knowledge/articles/weekend-gap-state-machine-buffer-interface.md` — Weekend Gap Signal System：市场事件状态机与 EA Buffer 接口
