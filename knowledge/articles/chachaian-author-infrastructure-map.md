# Chacha Ian Maroa：基础设施型文章优先级地图

作者主页：

- https://www.mql5.com/en/users/chachaian

## 总体定位

Chacha Ian Maroa 的高价值文章集中在平台基础设施，而不是交易策略本身：

```text
Runtime State
    ↓
Persistence
    ↓
Recovery
    ↓
Trade Event Export
    ↓
Python Analytics
    ↓
Dashboard
```

这正好对应 Python + MT5 平台中的：

```text
Replay / Paper / Live
Runtime Recovery
Trade Journal
Telemetry
Analytics API
```

## 优先级

| 系列 | 推荐 | 平台价值 | 是否深入 |
|---|---:|---:|---|
| Self-Healing Expert Advisor | S | ★★★★★ | 必须 |
| Building a Trade Analytics System | S | ★★★★★ | 必须 |
| Larry Williams 系列 | B | ★★★☆☆ | 参考 |
| Geography / Session Visualization | C | ★★☆☆☆ | 可跳过 |

## S 级 1：Self-Healing Expert Advisor

| Part | 文章 | 链接 | 收藏点 |
|---|---|---|---|
| 1 | Persistent Trade State Architecture | https://www.mql5.com/en/articles/22532 | TradeState / persistence / recovery foundation |
| 2 | Restart-Safe Virtual Trade Protection | https://www.mql5.com/en/articles/22613 | Virtual SL/TP / restart-safe protection |
| 3 | Restart-Aware Breakeven and Trailing Systems | https://www.mql5.com/en/articles/22614 | BE state / trailing state / heartbeat |
| 4 | Advanced Recovery and Multi-Symbol State Management | https://www.mql5.com/en/articles/22615 | multi-symbol state / advanced recovery |

### 收藏重点

不要收藏具体 trailing 公式；收藏运行时设计：

```text
TradeState
├── ticket / position id
├── symbol
├── direction
├── entry price
├── virtual sl / tp
├── breakeven state
├── trailing state
├── heartbeat
├── last persisted time
└── recovery status
```

平台级迁移：

```text
RuntimeStateManager
├── save_position_state()
├── load_position_state()
├── reconcile_with_broker()
├── recover_virtual_protection()
├── recover_trailing_state()
└── mark_orphaned_state()
```

## S 级 2：Building a Trade Analytics System

| Part | 文章 | 链接 | 收藏点 |
|---|---|---|---|
| 1 | Foundation: MQL5 to Python Bridge | https://www.mql5.com/en/articles/22107 | MT5 → HTTP → Python server |
| 2 | Closed Trade Capture | https://www.mql5.com/en/articles/22216 | OnTradeTransaction → JSON event |
| 3 | SQLite Persistence | https://www.mql5.com/en/articles/22373 | trade schema / storage layer |
| 4 | Dashboard and Metrics | https://www.mql5.com/en/articles/22449 | win rate / drawdown / expectancy / report |

### 收藏重点

原系列使用 Flask / SQLite。平台实现建议升级：

```text
MQL5 / MT5
    ↓
TradeEvent JSON
    ↓
FastAPI
    ↓
DuckDB
    ↓
Parquet Archive
    ↓
Dashboard / Research Report
```

这比简单日志更重要，因为它建立了 Trade Analytics Event Pipeline。

## B 级：Larry Williams 系列

价值主要在策略实现样例，不是平台核心。

可参考：

- EA 结构；
- 参数组织；
- 指标/信号到订单的基本连接。

不建议作为核心策略库。

## C 级：Geography / Session Visualization

偏 GUI 和可视化。除非后续需要 dashboard / chart UI，否则暂缓。

## 对当前平台的落地建议

新增两个平台资产：

```text
knowledge/architecture/
├── runtime-recovery-engine.md
└── trade-analytics-event-pipeline.md
```

对应未来工程目录：

```text
quant_platform/
├── runtime/
│   ├── state_manager.py
│   ├── recovery.py
│   └── heartbeat.py
├── storage/
│   ├── trade_log.py
│   ├── position_log.py
│   └── telemetry_sink.py
└── api/
    ├── trade_events.py
    └── analytics.py
```

## 最终结论

Chacha Ian Maroa 值得长期跟踪的原因是：他写的是 EA 在生产环境中的生存问题。

```text
Can the system restart safely?
Can virtual protection survive?
Can trade events be exported reliably?
Can analytics be rebuilt from persisted events?
```

这些问题比单个交易信号更接近平台工程核心。

