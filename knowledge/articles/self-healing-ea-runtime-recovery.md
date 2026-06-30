# Self-Healing Expert Advisor：从 EA 自恢复到平台 Runtime Recovery

来源：

- Part 1: https://www.mql5.com/en/articles/22532
- Part 2: https://www.mql5.com/en/articles/22613
- Part 3: https://www.mql5.com/en/articles/22614
- Part 4: https://www.mql5.com/en/articles/22615

## 定位

这组文章不应归类为 trailing / breakeven 策略，而应归类为 Runtime Recovery。

核心问题：

```text
EA / Terminal / VPS 重启后，系统如何恢复交易保护状态？
```

它解决的不是“怎么开仓”，而是：

- 虚拟止损是否还存在；
- 虚拟止盈是否还存在；
- break-even 是否已经触发；
- trailing 进度是否丢失；
- broker 实际持仓和本地状态是否一致；
- 多品种状态是否能重建。

## 推荐抽象

```text
RuntimeState
├── strategy_id
├── account_id
├── symbol
├── position_id
├── ticket
├── side
├── volume
├── entry_price
├── virtual_stop_loss
├── virtual_take_profit
├── breakeven_state
├── trailing_state
├── heartbeat_at
├── persisted_at
└── schema_version
```

## Recovery 流程

```text
Startup
    ↓
Load persisted state
    ↓
Query broker positions
    ↓
Reconcile state vs broker
    ↓
Recover virtual protection
    ↓
Recover BE / trailing state
    ↓
Mark orphaned / stale records
    ↓
Resume runtime loop
```

## 平台落地

Python 平台中建议拆成：

```text
runtime/
├── state_manager.py
├── recovery_engine.py
├── heartbeat.py
└── reconciliation.py
```

MQL5 侧只保留轻量本地保护和状态上报：

```text
MQL5 EA
    ↓
Local virtual protection
    ↓
Heartbeat / state export
    ↓
Python RuntimeStateManager
```

## 和 State Persistence 的区别

`state-persistence.md` 是通用持久化接口。

Self-Healing 系列补充的是交易状态恢复语义：

| 层 | 关注点 |
|---|---|
| StateStore | 如何保存/读取 |
| RuntimeRecovery | 保存什么、如何恢复、如何和 broker 对账 |
| VirtualProtection | 重启后如何继续执行本地 SL/TP |
| Reconciliation | 本地状态和真实持仓不一致时如何处理 |

## 风险点

Virtual Stop 必须严肃处理：

- 终端关闭期间虚拟止损不会执行；
- VPS 延迟会影响触发；
- broker 真实 SL 仍然是硬保护；
- virtual SL 更适合隐藏逻辑或二级保护，不应替代所有硬止损。

建议策略：

```text
Hard SL = disaster stop
Virtual SL = strategy/risk logic stop
```

## 收藏结论

收藏等级：S。

核心价值：

```text
Live trading cannot rely on in-memory state.
Every critical trade state must be recoverable.
```

