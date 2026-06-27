# StrategyStateMachine

来源：

- 文章：https://www.mql5.com/en/articles/22950
- 标题：Designing a Strategy State Machine in MQL5: Replacing Nested If-Else Logic with Formal States
- 作者：Ushana Kevin Iorkumbul

定位：

```text
EA Framework / Formal State Machine。
```

## 文件

- `IState.mqh` — state interface。
- `StrategyContext.mqh` — context declaration。
- `StrategyContextImpl.mqh` — context implementation，拆分以解决循环依赖。
- `States.mqh` — concrete states。
- `StateMachineEA.mq5` — 示例 EA。

## 核心结构

```text
IState
│
├── OnEnter(ctx)
├── Evaluate(ctx)
└── OnExit(ctx)
        ▲
        │
CStrategyContext.SetState()
```

## 值得收藏

- 用 formal state 替代 nested if-else；
- `IState` 接口统一状态生命周期；
- `CStrategyContext` 作为 mediator；
- `SetState()` 集中处理 OnExit / OnEnter；
- declaration / implementation 分离解决 MQL5 include 循环；
- 状态可独立测试和替换。

## 适合迁移的状态

```text
Idle
EntryPending
InPosition
ExitPending
NewsBlocked
DrawdownHalted
RecoveryMode
SessionClosed
```

## 收藏结论

这是 EA 行为层的框架组件。价值不在 MA 示例，而在把隐式 if-else 状态显式化，降低复杂策略维护成本。
