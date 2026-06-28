# Strategy State Machine：用显式状态替代嵌套 if-else

来源：

- 文章：https://www.mql5.com/en/articles/22950
- 标题：Designing a Strategy State Machine in MQL5: Replacing Nested If-Else Logic with Formal States
- 作者：Ushana Kevin Iorkumbul
- 发布时间：2026-06-25
- 附件：`IState.mqh`、`StrategyContext.mqh`、`StrategyContextImpl.mqh`、`States.mqh`、`StateMachineEA.mq5`

## 结论

这篇属于 EA 行为架构文章。

核心价值：

```text
把隐式状态显式化。
```

不是让 MA 示例更好，而是避免复杂 EA 的 `OnTick()` 变成不可维护的 nested if-else。

## 核心结构

```text
IState
│
├── OnEnter(ctx)
├── Evaluate(ctx)
└── OnExit(ctx)
        ▲
        │
CStrategyContext
│
├── current_state
├── SetState(next)
└── shared dependencies
```

## 值得收藏

- `IState` 生命周期接口；
- `CStrategyContext` 作为 mediator；
- 状态切换集中在 `SetState()`；
- `OnExit()` / `OnEnter()` 顺序明确；
- declaration / implementation 分离解决循环 include；
- 每个状态只负责自己的行为。

## 对当前框架的价值

适合抽象：

```text
Idle
SignalDetected
EntryPending
InPosition
ExitPending
NewsBlocked
DrawdownHalted
RecoveryMode
SessionClosed
```

可与：

- `EventBus`
- `CalendarEngine`
- `OrderBuilder`
- `RiskManager`
- `StateManager`

组合成可维护 EA 框架。

## 平台级升级

这篇可以进一步提炼为平台级架构资产：

- [FSM / Context / State Pattern：从 EA 状态机升级到平台运行状态机](../architecture/fsm-context-state-pattern.md)

EA 层的 `Idle / Entry / InTrade / Exit` 只是起点。对于 Research → Replay → Paper → Live 框架，更重要的是：

```text
ApplicationFSM
BrokerFSM
OrderFSM
PositionFSM
ReplayFSM
StrategyFSM
```

状态机负责生命周期，EventBus 负责模块通信，Context 负责运行依赖和共享状态。

## 反模式

应避免：

```mql5
void OnTick()
{
   if(has_signal)
      if(!has_position)
         if(!news)
            if(!drawdown)
               ...
}
```

这种写法会把状态、条件、动作混在一起，后续无法验证状态转移是否完整。

## 示例源码

已收录：

- `examples/mql5/StrategyStateMachine/IState.mqh`
- `examples/mql5/StrategyStateMachine/StrategyContext.mqh`
- `examples/mql5/StrategyStateMachine/StrategyContextImpl.mqh`
- `examples/mql5/StrategyStateMachine/States.mqh`
- `examples/mql5/StrategyStateMachine/StateMachineEA.mq5`

## 最终判断

这是高价值框架素材。它不提供 Alpha，但提供复杂 EA 可维护性的基础。
