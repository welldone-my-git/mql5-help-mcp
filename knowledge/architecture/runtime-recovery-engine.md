# Runtime Recovery Engine：Replay / Paper / Live 的自恢复运行时

来源：

- Chacha Ian Maroa Self-Healing EA series: https://www.mql5.com/en/users/chachaian
- [Self-Healing EA Runtime Recovery](../articles/self-healing-ea-runtime-recovery.md)
- [State Persistence](./state-persistence.md)

## 目标

平台必须假设以下情况会发生：

```text
Python process crash
MT5 terminal restart
VPS reboot
network disconnect
broker reconnect
strategy hot reload
```

因此 live/paper 运行时不能依赖内存。

## 核心组件

```text
RuntimeRecoveryEngine
├── StateManager
├── HeartbeatMonitor
├── BrokerReconciler
├── VirtualProtectionRestorer
├── OrderStateRestorer
└── OrphanStateCleaner
```

## 启动恢复流程

```text
Application Boot
    ↓
Load latest runtime checkpoint
    ↓
Connect broker
    ↓
Fetch account / positions / orders
    ↓
Reconcile local state with broker state
    ↓
Recover risk counters
    ↓
Recover pending orders
    ↓
Recover virtual protection
    ↓
Emit RecoveryReport
    ↓
Allow trading only after recovery is clean
```

## RecoveryReport

建议事件：

```python
@dataclass
class RecoveryReport:
    recovered_positions: int
    recovered_orders: int
    orphaned_states: int
    broker_only_positions: int
    local_only_positions: int
    risk_state_restored: bool
    safe_to_trade: bool
    metadata: dict
```

`safe_to_trade=False` 时，平台只能进入只读/管理模式，不允许新开仓。

## 与 EventBus 的关系

恢复过程也应该发事件：

```text
RecoveryStarted
RecoveryStateLoaded
RecoveryBrokerSnapshotLoaded
RecoveryMismatchDetected
RecoveryCompleted
RecoveryBlocked
```

这些事件进入 telemetry，方便复盘生产事故。

## 必须持久化的状态

| 模块 | 状态 |
|---|---|
| Strategy | FSM state、last signal、warmup status |
| Risk | daily loss、daily trade count、cooldown、risk locks |
| OrderManager | client_order_id、pending orders、external order mapping |
| Broker | broker_order_id、deal id、position id |
| Portfolio | position snapshot、cash/equity checkpoint |
| Virtual Protection | virtual SL/TP、BE、trailing progress |
| Replay | cursor、last event timestamp |

## 原则

```text
If a state changes trading behavior, persist it.
```

只影响 UI 的状态可以丢失；影响交易行为的状态不能丢失。

## 最小 MVP

先实现：

```text
JSON / DuckDB StateStore
    ↓
Portfolio checkpoint
    ↓
Risk daily counters
    ↓
Order id mapping
    ↓
startup reconciliation report
```

Virtual SL / trailing 可以在后续 live 阶段接入。

