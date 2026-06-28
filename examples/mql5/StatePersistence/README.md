# State Persistence：Binary EA State Manager

来源：

- 文章：https://www.mql5.com/en/articles/22277
- 标题：Keeping Memory Across Restarts: EA State Persistence Using Binary Files in MQL5
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-05-29

## 定位

```text
EA StateManager / Restart Recovery 基础设施。
```

这份源码解决的问题不是策略，而是 EA 在终端重启、图表刷新、VPS 迁移后如何恢复内部状态。

## 文件

| 文件 | 作用 |
|---|---|
| `PersistenceManager.mqh` | 二进制状态读写模块，包含默认状态、保存、加载、删除和版本校验 |
| `PersistenceDemo.mq5` | 示例 EA，演示在 `OnInit`、`OnDeinit`、`OnTradeTransaction` 中加载/保存状态 |

## 值得抽取的模块

### 1. `EAState` 结构

源码把运行时状态集中到一个 struct：

```text
version
lastSaveTime
dailyTradeCount
lossStreak
winStreak
currentLotMult
sessionHighEq
partialClosed
lastSignal
```

这些字段不是重点，重点是“状态集中声明 + 统一序列化”。

### 2. Binary Save / Load

`PersistenceManager.mqh` 使用：

```text
FileWriteStruct()
FileReadStruct()
FILE_COMMON
```

适合 MQL5 与多个终端共享或在 VPS 上恢复。

### 3. Version Guard

状态文件带 `version`，版本不匹配时回退默认状态。

这是生产必要设计：EA 升级后旧状态结构可能不兼容，不能盲目读取。

### 4. Save Timing

示例展示了几个保存点：

- `OnInit()`：加载状态；
- `OnDeinit()`：最终保存；
- `OnTradeTransaction()`：交易状态变化时保存；
- 运行中关键计数或风控状态变化后保存。

## 可迁移到平台的设计

建议落地为：

```text
StateManager
├── Load(strategy_id)
├── Save(strategy_id, state)
├── Reset(strategy_id)
├── ValidateVersion()
├── Snapshot()
└── Restore()
```

适合保存：

- strategy FSM 当前状态；
- last processed bar / tick / deal id；
- daily trade count；
- loss streak / recovery mode；
- grid / martingale level；
- partial close flag；
- risk guard state；
- last model regime / signal id。

## 平台映射

```text
Replay
  可选：保存 replay checkpoint

Paper
  必须：保存模拟账户与策略状态

Live
  必须：保存交易生命周期与风控状态
```

## 后续升级建议

当前源码适合做 MQL5 基础版。平台级实现还应补：

- atomic write：先写临时文件，再 rename；
- checksum / schema version；
- 多 magic / 多 symbol 独立命名；
- JSON / SQLite / DuckDB 后端；
- Python 端 StateStore 接口。
