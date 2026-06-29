# Architecture Knowledge

这里保存跨文章、跨源码的架构资产。它不是文章摘要库，而是把多篇 MQL5 / Python / OpenAlgo 相关资料提炼成可复用的平台设计模式。

目标：

```text
Article / Source Code
    ↓
Design Pattern
    ↓
Platform Asset
    ↓
quant_platform implementation
```

## 已收录架构资产

- [FSM / Context / State Pattern：从 EA 状态机升级到平台运行状态机](./fsm-context-state-pattern.md)
- [Chart Object Event Monitor：手动画线到 GeometryEvent](./chart-object-event-monitor.md)
- [Live Telemetry Pipeline：Replay / Paper / Live 统一遥测](./live-telemetry-pipeline.md)
- [Market Structure Event Engine：BOS / ChoCH / Sweep / ORB](./market-structure-event-engine.md)
- [Microstructure Feature Engine：TickEvent 到短窗口执行特征](./microstructure-feature-engine.md)
- [Model Production Pipeline：Python Research 到 MQL5 ONNX Runtime](./model-production-pipeline.md)
- [MTF Feature Engine：多周期闭合 K 线特征设计](./mtf-feature-engine.md)
- [Object Pool：热路径对象生命周期管理](./object-pool.md)
- [Platform Design Source Map：Research → Replay → Paper → Live 资料映射](./platform-design-source-map.md)
- [Pattern Event Engine：形态实体到结构化事件](./pattern-event-engine.md)
- [Repository Pattern：交易数据访问抽象](./repository-pattern.md)
- [Signal Buffer Contract：Indicator Buffer 到 SignalEvent 的执行接口](./signal-buffer-contract.md)
- [Statistical Diagnostics：策略与特征统计诊断层](./statistical-diagnostics.md)
- [State Persistence：平台状态持久化设计](./state-persistence.md)
- [Trade Governance：交易纪律与执行前治理层](./trade-governance.md)

## 后续建议资产

```text
Event Model
EventBus
Broker Adapter
Risk Engine
Portfolio
Replay Engine
Storage Schema
Context / Dependency Injection
Repository
Factory / Plugin
Pipeline
Notification
```
