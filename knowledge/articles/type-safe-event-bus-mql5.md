# Type-Safe Event Bus：用事件总线解耦 EA 组件

来源：

- 文章：https://www.mql5.com/en/articles/22930
- 标题：Building a Type-Safe Event Bus in MQL5: Decoupling EA Components Without Global Variables
- 作者：Ushana Kevin Iorkumbul
- 发布时间：2026-06-12
- 附件：`EventBusSystem.mqh`、`EventBusDemo.mq5`

## 结论

这篇文章是 EA Framework 级别文章，核心不是 MA cross demo，而是：

```text
Signal / Order / Risk / Monitor 之间通过 EventBus 通信
```

价值：★★★★★

## 核心设计

```text
Publisher
   │
   ▼
SEventPayload
   │
   ▼
CEventBus.Publish()
   │
   ▼
IEventListener.OnEvent()
   │
   ├── OrderManager
   └── DrawdownMonitor
```

事件类型由 `ENUM_EA_EVENT` 管理，listener 通过 `Subscribe()` 注册。

## 值得收藏

- `IEventListener` 抽象接口；
- `SEventPayload` 统一事件结构；
- enum-indexed subscription table；
- `Subscribe()` / `Unsubscribe()` / `Publish()`；
- order manager 不直接依赖 signal engine；
- drawdown monitor 可通过事件暂停交易；
- 组件间没有 global variable 和交叉引用。

## 可迁移到当前框架

```text
EventBus
│
├── MarketDataEvent
├── SignalEvent
├── RiskEvent
├── OrderEvent
├── TradeEvent
├── CalendarEvent
└── DrawdownEvent
```

与已有模块关系：

- `CalendarEngine` 发布 `CalendarEvent`；
- `RiskManager` 监听 `CalendarEvent` / `DrawdownEvent`；
- `OrderBuilder` 监听 `OrderRequestEvent`；
- `TradeJournal` 发布 `TradeClosedEvent`；
- `StateMachine` 根据事件切换状态。

## 需要升级的地方

原始实现适合作为骨架，但生产级还需要：

- recursive publish guard；
- dispatch depth limit；
- listener priority；
- listener 生命周期管理；
- event tracing / audit log；
- typed payload 分层；
- 可选 deferred queue，避免在 listener 内同步触发复杂链路。

## 示例源码

已收录：

- `examples/mql5/EventBus/EventBusSystem.mqh`
- `examples/mql5/EventBus/EventBusDemo.mq5`

## 最终判断

这是模块化 EA 的核心基础设施之一。后续如果构建完整 MQL5 交易框架，应优先将它提炼为通用 `EventBus.mqh`。
