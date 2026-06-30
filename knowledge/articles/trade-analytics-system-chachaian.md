# Building a Trade Analytics System：MT5 到 Python 的交易事件分析管线

来源：

- Part 1: https://www.mql5.com/en/articles/22107
- Part 2: https://www.mql5.com/en/articles/22216
- Part 3: https://www.mql5.com/en/articles/22373
- Part 4: https://www.mql5.com/en/articles/22449

## 定位

这组文章不是策略文章，而是 Trade Analytics / Trade Journal 基础设施。

原始方向：

```text
MT5 EA
    ↓
HTTP
    ↓
Python
    ↓
SQLite
    ↓
Dashboard
```

平台升级方向：

```text
MT5 / Paper / Replay
    ↓
TradeEvent
    ↓
FastAPI
    ↓
DuckDB
    ↓
Parquet
    ↓
Analytics / Dashboard
```

## 值得收藏的内容

### 1. MT5 → Python Bridge

EA 不应该只写本地日志，而应该把结构化事件推送到分析服务：

```text
OrderEvent
FillEvent
PositionEvent
ClosedTradeEvent
PortfolioSnapshot
```

### 2. OnTradeTransaction

交易分析不应依赖定时扫描账户历史。

更稳的方式：

```text
OnTradeTransaction
    ↓
Extract order/deal/position fields
    ↓
Serialize JSON
    ↓
POST to analytics service
```

### 3. Storage Schema

SQLite 可作为文章演示，平台应优先 DuckDB / Parquet。

推荐表：

```text
orders
fills
positions
closed_trades
portfolio_snapshots
decision_log
runtime_heartbeat
```

### 4. Metrics

Dashboard 指标至少包括：

- win rate；
- profit factor；
- expectancy；
- average win / average loss；
- drawdown；
- average holding time；
- symbol split；
- strategy split；
- slippage；
- commission；
- risk-adjusted return。

## 与当前平台的关系

这组文章可以直接服务：

```text
storage/trade_log.py
storage/decision_log.py
api/main.py
api/trade_events.py
dashboard/
```

事件链：

```text
SignalEvent
    ↓
RiskEvent
    ↓
OrderEvent
    ↓
FillEvent
    ↓
PositionEvent
    ↓
ClosedTradeEvent
    ↓
TradeAnalytics
```

## 反模式

避免：

- 只记录最终盈利，不记录决策上下文；
- 只保存 closed trades，不保存 orders / fills；
- 只在 EA 侧做统计，Python 无法复现；
- 用 CSV 作为长期主存储；
- dashboard 直接访问策略对象。

## 收藏结论

收藏等级：S。

核心价值：

```text
Trade analytics should be event-sourced.
```

如果所有订单、成交、持仓、决策都能重放，平台后续才能做：

- Replay audit；
- Paper vs Live 对比；
- strategy attribution；
- slippage analysis；
- risk breach diagnosis；
- ML label / execution feedback。

