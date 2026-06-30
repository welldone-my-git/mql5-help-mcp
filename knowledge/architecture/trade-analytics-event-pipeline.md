# Trade Analytics Event Pipeline：订单/成交/持仓到研究分析

来源：

- Chacha Ian Maroa Trade Analytics System series: https://www.mql5.com/en/users/chachaian
- [Trade Analytics System](../articles/trade-analytics-system-chachaian.md)
- [Live Telemetry Pipeline](./live-telemetry-pipeline.md)

## 目标

把交易过程变成可重放、可查询、可分析的事件流。

```text
Decision
    ↓
Signal
    ↓
Risk
    ↓
Order
    ↓
Fill
    ↓
Position
    ↓
ClosedTrade
    ↓
PortfolioSnapshot
```

## 为什么不能只保存 closed trades

Closed trade 不包含足够上下文：

- 为什么开仓；
- 当时模型概率是多少；
- RiskEngine 是否调低仓位；
- 下单是否滑点；
- 是否部分成交；
- 持仓期间是否触发风控；
- 平仓是策略、止损、止盈还是人工干预。

平台必须保存完整事件链。

## 推荐事件表

```text
decision_log
signals
risk_events
orders
fills
positions
closed_trades
portfolio_snapshots
runtime_events
```

每张表至少有：

```text
event_id
correlation_id
timestamp
symbol
strategy_id
source
metadata
```

## MQL5 接入点

MQL5 侧重点：

```text
OnTradeTransaction
    ↓
Order / Deal extraction
    ↓
JSON serialization
    ↓
WebRequest POST
```

Python 侧重点：

```text
FastAPI endpoint
    ↓
validation
    ↓
DuckDB append
    ↓
analytics query
    ↓
dashboard / report
```

## Replay / Paper / Live 统一

同一 schema 应服务三种模式：

| 模式 | 事件来源 |
|---|---|
| Replay | ReplayEngine 合成事件 |
| Paper | PaperBroker 生成 Order/Fill/Position |
| Live | MT5 / BrokerAdapter 实际交易事件 |

这样才能比较：

```text
research expectation
paper behavior
live execution reality
```

## 最小 MVP

第一版实现：

```text
DecisionLog
TradeLog
PortfolioSnapshot
DuckDBSink
Parquet export
```

后续加入：

```text
OnTradeTransaction bridge
slippage analysis
execution quality report
dashboard
```

