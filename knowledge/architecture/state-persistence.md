# State Persistence：平台状态持久化设计

## 目标

状态持久化用于保证：

```text
Replay / Paper / Live 在进程重启后可以恢复关键运行状态。
```

参考来源：

- [Keeping Memory Across Restarts](../articles/state-persistence-binary-files-mql5.md)

## 最小接口

```python
class StateStore:
    def load(self, key: str) -> dict: ...
    def save(self, key: str, state: dict) -> None: ...
    def reset(self, key: str) -> None: ...
```

生产版应增加：

```text
schema_version
checksum
updated_at
atomic write
namespace / strategy_id / account_id
```

## 哪些状态必须保存

| 模块 | 状态 |
|---|---|
| Strategy | FSM state、last signal id、warmup flag |
| Risk | daily loss、trade count、cooldown、news block |
| OrderManager | pending orders、client order id counter |
| Broker | last transaction id、external order mapping |
| Portfolio | positions snapshot、cash/equity checkpoint |
| Replay | current cursor、last event timestamp |

## 原则

```text
关键交易状态变化后立即持久化。
```

不能只在退出时保存，因为 VPS、终端、系统都可能非正常中断。
