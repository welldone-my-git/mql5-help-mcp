# State Persistence：Binary EA State Manager

来源：

- 文章：https://www.mql5.com/en/articles/22277
- 标题：Keeping Memory Across Restarts: EA State Persistence Using Binary Files in MQL5
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-05-29
- 源码目录：[examples/mql5/StatePersistence](../../examples/mql5/StatePersistence/)

## 收藏结论

收藏价值：★★★★★

这篇属于 EA / Trading Platform 基础设施。它解决的是：

```text
EA 重启后如何恢复内部状态
```

不是交易策略。

## 为什么重要

很多 EA 的隐性 bug 不是信号问题，而是状态丢失：

- martingale / grid 层级重置；
- daily trade count 清零；
- loss streak 丢失；
- partial close 标志丢失；
- last processed deal 重复处理；
- recovery mode 失效；
- 风控保护重启后消失。

状态持久化是 Paper / Live 的基础要求。

## 核心设计

### 1. 集中式状态结构

源码用 `EAState` 把运行状态集中管理。

平台版应改为：

```text
StrategyState
RiskState
PortfolioState
BrokerState
ReplayCheckpoint
```

### 2. Binary IO

MQL5 侧使用：

```text
FileWriteStruct()
FileReadStruct()
FILE_COMMON
```

优点：

- 简单；
- 快；
- 适合 EA 本地恢复；
- 不依赖外部服务。

限制：

- schema 演进不灵活；
- 不适合跨语言直接分析；
- 需要版本和校验。

### 3. Version Guard

状态文件必须带版本。版本不匹配时重置或迁移。

这点应直接纳入平台设计：

```text
state_version
schema_version
created_at
updated_at
checksum
```

## 平台迁移建议

```text
StateStore
├── load(key)
├── save(key, state)
├── reset(key)
├── validate_schema()
└── snapshot()

Backends
├── BinaryFileStateStore      # MQL5 lightweight
├── JsonStateStore            # debug-friendly
├── SQLiteStateStore          # local structured
└── DuckDBStateStore          # research / replay
```

## 建议保存的状态

| 模块 | 状态 |
|---|---|
| Strategy | FSM state、last signal、warmup complete |
| Risk | daily loss、trade count、cooldown、news block |
| Broker | pending order ids、last transaction id |
| Portfolio | positions snapshot、cash/equity checkpoint |
| Replay | current timestamp、last row offset |
| Feature | last bar time、rolling window buffer |

## 设计原则

```text
Live/Paper 不允许依赖内存状态作为唯一真实状态。
```

关键状态变化后保存，不等到进程退出。

最低要求：

- `OnInit()` load；
- `OnDeinit()` save；
- `OnTradeTransaction()` save；
- risk state 变化时 save。
