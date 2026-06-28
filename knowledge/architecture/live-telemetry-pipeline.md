# Live Telemetry Pipeline：Replay / Paper / Live 统一遥测

参考来源：

- [Live CSV Streaming](../articles/live-csv-streaming-telemetry-pipeline.md)

## 目标

平台需要记录的不只是成交，还包括每次决策前后的上下文：

```text
features
model output
signal
risk decision
order
fill
portfolio snapshot
runtime health
```

## 最小事件流

```text
BarEvent / TickEvent
  ↓
FeatureSnapshot
  ↓
DecisionEvent
  ↓
SignalEvent
  ↓
RiskEvent
  ↓
OrderEvent
  ↓
FillEvent
  ↓
PortfolioSnapshot
```

## Sink 设计

```text
TelemetrySink
├── CsvSink          # fallback/debug
├── DuckDBSink       # research/main local store
├── ParquetSink      # archive/batch
└── SocketSink       # live dashboard/API
```

## 原则

- live、paper、replay 使用同一 schema；
- 写入应支持 micro-batch；
- 每条记录必须能追溯到 event_id；
- dashboard 只能读 telemetry，不应该直接耦合策略内部对象。
