# EventBus

来源：

- 文章：https://www.mql5.com/en/articles/22930
- 标题：Building a Type-Safe Event Bus in MQL5: Decoupling EA Components Without Global Variables
- 作者：Ushana Kevin Iorkumbul

定位：

```text
EA Framework / Typed Publish-Subscribe Event Bus。
```

## 文件

- `EventBusSystem.mqh` — EventBus、事件 payload、listener 接口、SignalEngine、OrderManager、DrawdownMonitor。
- `EventBusDemo.mq5` — 示例 EA，演示 signal → order → drawdown monitor 的事件流。

## 核心结构

```text
SEventPayload
      │
      ▼
CEventBus.Publish()
      │
      ▼
IEventListener.OnEvent()
      │
      ├── COrderManager
      └── CDrawdownMonitor
```

## 值得收藏

- `ENUM_EA_EVENT` 统一事件类型；
- `SEventPayload` 作为轻量事件结构；
- `IEventListener` 抽象监听者接口；
- `CEventBus::Subscribe()` / `Unsubscribe()` / `Publish()`；
- enum-indexed subscription table；
- signal / order / risk 之间没有直接引用；
- drawdown halt 通过事件通知 order manager。

## 适合迁移到框架

```text
MarketDataEvent
SignalEvent
RiskEvent
OrderEvent
TradeEvent
CalendarEvent
DrawdownEvent
```

后续增强点：

- recursive publish guard；
- max queue depth；
- listener priority；
- event tracing；
- async queue / deferred dispatch；
- typed payload 子类化。

## 收藏结论

这是 MQL5 模块化 EA 的核心基础设施样例。价值不在 MA cross demo，而在事件驱动解耦架构。
