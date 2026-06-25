# Local Stop Loss EA

来源文件：`Local_Stop_Loss.mq5`

定位：

```text
EA 架构收藏样例，不是重点交易策略。
```

收藏价值：

- `OnInit()` / `OnTick()` 职责清晰；
- `PositionsCheck()` 统一扫描仓位；
- `ProcessPosition()` 处理新仓；
- `CheckProcessedPosition()` 管理已处理仓位；
- `CHashMap<ulong,double>` 缓存 ticket → local stop price；
- chart object 统一命名和清理；
- helper functions 拆分明确。

主要学习点：

```text
Position Manager
  ↓
HashMap Position Cache
  ↓
State Machine
  ↓
Object Manager
  ↓
Cleanup Manager
```

注意：

- 这不是直接推荐实盘使用的本地止损 EA。
- 作为本地止损，终端关闭、EA 停止或网络断开时无法替代 broker/server stop。
- 如果用于真实账户，应补充 magic number 过滤、异常处理、交易结果检查和 fail-safe server stop。
