# FSM / Context / State Pattern：从 EA 状态机升级到平台运行状态机

主要来源：

- MQL5 文章：https://www.mql5.com/en/articles/22950
- 已收录条目：[Strategy State Machine：用显式状态替代嵌套 if-else](../articles/strategy-state-machine-mql5.md)
- 本地源码：[examples/mql5/StrategyStateMachine](../../examples/mql5/StrategyStateMachine/)

## 核心结论

22950 的真正价值不是 MA 示例，也不是四个状态本身，而是这套结构：

```text
Context
    owns current_state
    owns shared dependencies
    exposes SetState()

State
    OnEnter(ctx)
    Evaluate(ctx)
    OnExit(ctx)
```

它把 EA 从：

```text
OnTick()
    nested if / else
```

升级为：

```text
OnTick()
    ctx.Update()
        current_state.Evaluate(ctx)
```

这就是 State Pattern 在交易系统里的最小可用形态。

## EA 层原始结构

文章中的状态：

```text
Idle
    ↓ signal
Entry
    ↓ filled
InTrade
    ↓ exit
Exit
    ↓ done
Idle
```

接口：

```text
IState
├── OnEnter(ctx)
├── Evaluate(ctx)
└── OnExit(ctx)
```

Context：

```text
CStrategyContext
├── current_state
├── magic
├── symbol
├── indicator handles
├── last ticket
├── pending direction
└── SetState(next)
```

## 真正应保留的设计

### 1. 显式状态

复杂系统不应该把状态藏在多个 bool 变量里：

```text
has_signal
has_position
is_news_blocked
is_drawdown_halted
is_pending_order
```

这些组合会快速失控。

应改成：

```text
State = Idle / Signal / RiskBlocked / OrderPending / InPosition / ExitPending
```

### 2. 生命周期

每个状态应有明确生命周期：

```text
enter()
update()
exit()
```

这比把初始化、轮询、清理混在 `OnTick()` 或 `run()` 里更可测。

### 3. Context

Context 是状态之间共享依赖和运行数据的容器。

但 Context 不能无限膨胀。平台级设计应拆分：

```text
AppContext
├── MarketContext
├── BrokerContext
├── PortfolioContext
├── RiskContext
├── StrategyContext
├── FeatureContext
├── StorageContext
└── ConfigContext
```

### 4. Include / dependency 分离

MQL5 里文章用：

```text
IState
StrategyContext declaration
States
StrategyContextImpl
```

解决循环 include。迁移到 Python 时也应避免循环 import：

```text
core/state.py
core/context.py
states/*.py
```

## 平台级升级

22950 解决的是 EA 行为 FSM。quant_platform 应扩展成多个 FSM：

```text
ApplicationFSM
├── Boot
├── Replay
├── Paper
├── Live
├── Paused
└── Shutdown

BrokerFSM
├── Disconnected
├── Connecting
├── Connected
├── Submitting
├── Reconnecting
└── Error

OrderFSM
├── Created
├── RiskApproved
├── Submitted
├── Accepted
├── PartialFilled
├── Filled
├── Cancelled
└── Rejected

PositionFSM
├── Flat
├── PendingOpen
├── Open
├── Scaling
├── PendingClose
└── Closed

StrategyFSM
├── Warmup
├── Scan
├── Signal
├── Risk
├── Execute
└── Manage

ReplayFSM
├── Loading
├── Warmup
├── Running
├── Paused
└── Finished
```

## 与 EventBus 的关系

FSM 不替代 EventBus。

建议关系：

```text
EventBus = 模块之间传递事实
FSM      = 模块内部管理状态
Context  = 模块运行时依赖和状态数据
```

例如：

```text
BarEvent
    -> StrategyFSM.Scan
    -> SignalEvent
    -> RiskEngine
    -> RiskEvent
    -> OrderFSM.Submitted
    -> BrokerAdapter
    -> FillEvent
    -> PositionFSM.Open
```

## 对 quant_platform 的实现建议

第一版不要把所有 FSM 都实现完。

MVP 只需要：

```text
StrategyFSM: Warmup / Ready
OrderFSM: Created / Submitted / Filled / Rejected
Position state: Flat / Open
ReplayFSM: Loading / Running / Finished
```

可以先写成枚举字段，不必每个状态都建类。

等状态逻辑变复杂后，再引入 full State Pattern。

## 推荐目录

```text
quant_platform/
├── core/
│   ├── state.py
│   ├── context.py
│   └── events.py
├── trading/
│   ├── order_state.py
│   ├── position_state.py
│   └── risk.py
├── replay/
│   └── replay_state.py
└── strategy/
    ├── base.py
    └── strategy_state.py
```

## 反模式

避免：

```text
if mode == "replay":
    if has_data:
        if signal:
            if risk_ok:
                if broker_connected:
                    ...
```

避免：

```text
global broker
global portfolio
global current_position
global current_order
```

避免：

```text
Strategy 直接调用 Broker
Strategy 直接改 Portfolio
RiskEngine 直接发订单
Broker 直接写策略状态
```

## 最终判断

22950 应归入：

```text
Architecture Knowledge / FSM / Context / State Pattern
```

不是单纯的 EA 示例。

它为 Research → Replay → Paper → Live 框架提供了一个明确方向：

```text
事件驱动负责模块通信
状态机负责生命周期
Context 负责依赖注入和运行数据
```
