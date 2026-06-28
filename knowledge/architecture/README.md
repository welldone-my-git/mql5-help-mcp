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
- [MTF Feature Engine：多周期闭合 K 线特征设计](./mtf-feature-engine.md)
- [Platform Design Source Map：Research → Replay → Paper → Live 资料映射](./platform-design-source-map.md)
- [State Persistence：平台状态持久化设计](./state-persistence.md)

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
