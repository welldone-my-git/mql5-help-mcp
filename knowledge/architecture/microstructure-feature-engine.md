# Microstructure Feature Engine

## 定位

从 TickEvent 提取短窗口执行与流动性特征。

```text
TickEvent
  ↓
TickBuffer
  ↓
MicrostructureFeature
  ↓
Risk / Execution / Model
```

来源样例：

- [TickVWAPImbalance](../../examples/mql5/TickVWAPImbalance/)
- [Microstructure Feature Pipeline](../../examples/research/microstructure-feature-pipeline/)

## 核心特征

```text
spread
spread_to_atr
vwap
price_vs_vwap
flow
imbalance
tick_rate
volatility_short_window
```

## 设计规则

1. Tick buffer 必须可 replay。
2. 特征计算和 UI 展示分离。
3. Broker tick quality 必须记录。
4. Spread / slippage 特征进入 RiskEngine。
5. 高频写入优先 DuckDB 或批量 Parquet，不依赖 CSV。

## 事件映射

```text
TickEvent
  ↓
FeatureEvent
  ↓
DecisionEvent
```

## MVP 建议

先实现：

```text
RollingTickBuffer
SpreadFeature
VWAPFeature
ImbalanceFeature
```

再接入：

```text
ReplayEngine
FeatureStore
RiskEngine
```

