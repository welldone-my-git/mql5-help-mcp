# Tick VWAP / Imbalance：Tick Buffer 微观结构特征

来源：

- 文章：https://www.mql5.com/en/articles/19290
- 作者：Christian Benjamin（LynnChris）
- 源码：[TickVWAPImbalance](../../examples/mql5/TickVWAPImbalance/)

## 结论

这篇文章适合作为 microstructure feature engine 收藏。

它的价值不是“Slippage Tool”，而是：

```text
Tick Stream
  ↓
Rolling Buffer
  ↓
VWAP / Spread / Flow / Imbalance
  ↓
Execution Filter / Feature Store
```

## 可收藏设计

### 1. Tick Buffer

`MqlTick` 进入内存 ring-like buffer，用于短窗口统计。

生产平台应升级为：

```text
TickBuffer
DuckDB tick log
Parquet tick archive
Replay tick stream
```

### 2. VWAP

基于 tick price 和 tick volume 计算时间窗口 VWAP。

可用作：

```text
price_vs_vwap
vwap_distance
fair_value_proxy
```

### 3. Imbalance / Flow

用 uptick / downtick 近似买卖压力。

虽然不等同真实 order book，但可作为低成本 microstructure proxy。

### 4. Spread / ATR Context

把 spread 放到 ATR 背景下评估，适合 RiskEngine：

```text
spread_to_atr > threshold
  ↓
block or reduce size
```

## 平台映射

```text
TickEvent
  ↓
MicrostructureFeatureEngine
  ↓
FeatureStore
  ↓
RiskEngine / Model
```

## 反模式

- 把 tick imbalance 直接当方向预测；
- 不落库导致无法回测；
- 不考虑 broker tick quality；
- 用 UI panel 代替数据接口。

