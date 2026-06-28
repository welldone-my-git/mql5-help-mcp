# Platform Design Source Map：Research → Replay → Paper → Live 资料映射

目标平台：

```text
MT5       = 高保真数据 / Strategy Tester / 订单成交生命周期
Python    = 因子 / 特征 / ML / PAE / Regime / Signal
OpenAlgo  = API / Broker Adapter / Risk / Portfolio / Order Manager 思路
DuckDB    = 研究数据 / 回测日志 / Feature Store
Parquet   = 长期归档 / 批量研究
```

## 当前资料是否足够

结论：

```text
Research → Replay → Paper：足够启动 MVP
Live MT5 / 高保真成交生命周期：仍需补资料
```

## 模块映射

| 平台模块 | 已有资料 | 充分度 | 备注 |
|---|---|---:|---|
| Event Model | Type-Safe EventBus, Strategy State Machine | 高 | 足够设计事件基类和同步总线 |
| EventBus | Type-Safe Event Bus | 高 | Python 版可先同步 publish/subscribe |
| FSM / Context | Strategy State Machine 22950 | 高 | 已提升为平台架构资产 |
| Strategy Interface | Meta-Labeling RSI/ADX, Transformer, DeepAR | 高 | Strategy 只产出 SignalEvent |
| RiskEngine | TickValue, CarryCost, CalendarEngine, BreakEven | 中高 | 够 MVP，后续补 portfolio-level risk |
| OrderManager | OrderBuilder, Bootstrap TradeHelpers | 高 | 足够生成 OrderEvent |
| PaperBroker | Python-MT5 Strategy Tester | 中高 | 够 market-order immediate fill |
| MT5Broker | Python MetaTrader5 API 待补 | 中 | 先 stub |
| Portfolio | Python Strategy Tester, TradeHelpers | 中 | 够 cash/equity/positions MVP |
| ReplayEngine | Python Strategy Tester, CSV Data Analysis | 高 | 够 CSV/Parquet bar replay |
| MT5 Replay Adapter | Strategy Tester export 待补 | 中低 | 后续需要 order/deal/position schema |
| Storage | CSV Data Analysis, Bootstrap SQLite, File IO | 中高 | DuckDB schema 还要单独定 |
| Feature Store | Microstructure, RQA/TDA/RNA, Meta Labeling | 高 | 研究侧素材充足 |
| Notification | Discord Notification | 中高 | 可做 risk/fill alert adapter |
| Scheduler | Bootstrap Schedule | 高 | 可映射 core/clock.py |
| API | OpenAlgo 思路待补 | 中 | FastAPI skeleton 足够 |

## 第一批应落地的架构资产

```text
knowledge/architecture/
├── fsm-context-state-pattern.md
├── platform-design-source-map.md
├── event-model.md           # 待建
├── broker-adapter.md        # 待建
├── risk-engine.md           # 待建
├── storage-schema.md        # 待建
└── replay-engine.md         # 待建
```

## 需要继续补资料的缺口

### 1. MT5 Trade Lifecycle

需要补：

```text
MqlTradeRequest
MqlTradeResult
MqlTradeTransaction
OnTradeTransaction
Order / Deal / Position
HistoryOrder / HistoryDeal
netting / hedging
partial fill
retcode
position identifier
```

用途：

```text
OrderEvent
FillEvent
PositionEvent
MT5Broker
MT5ReplayAdapter
TradeLog schema
```

### 2. MT5 Strategy Tester Export

需要补：

```text
tester order/deal export
OnTester / OnTesterPass
trade transaction logging
real tick replay
spread / commission / swap handling
```

用途：

```text
Replay high-fidelity validation
MT5 lifecycle parity
```

### 3. OpenAlgo Adapter / API

需要补：

```text
broker adapter interface
order API schema
position API schema
strategy hosting
webhook signal
dashboard state
```

用途：

```text
api/
brokers/
trading/
```

### 4. DuckDB / Parquet Schema

需要定：

```text
bars
ticks
features
signals
decisions
orders
fills
positions
portfolio_snapshots
```

用途：

```text
FeatureStore
TradeLog
DecisionLog
Replay dataset
```

## 当前实现优先级

建议仍按最小闭环推进：

```text
1. core/events.py
2. core/bus.py
3. replay/replay_engine.py
4. strategy/base.py
5. strategy/example_strategy.py
6. trading/risk.py
7. trading/order_manager.py
8. brokers/paper_broker.py
9. trading/portfolio.py
10. storage/decision_log.py / trade_log.py
```

暂缓：

```text
真实 MT5Broker
完整 OpenAlgo API
复杂 ML
复杂 PAE
复杂 Regime
Dashboard
高保真撮合
```

## 设计原则

```text
EventBus 连接模块
FSM 管理生命周期
Context 承载依赖
Strategy 只产生 SignalEvent
RiskEngine 决定是否允许交易
OrderManager 只生成 OrderEvent
BrokerAdapter 只执行订单
Portfolio 只根据 Fill/Position 更新状态
Storage 记录所有决策和成交
```
