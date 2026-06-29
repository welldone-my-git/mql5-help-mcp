# Tick VWAP / Imbalance

来源：

- 文章：https://www.mql5.com/en/articles/19290
- 标题：Price Action Analysis Toolkit Development (Part 38): Tick Buffer VWAP and Short-Window Imbalance Engine
- 作者：Christian Benjamin（LynnChris）
- 源码：[Slippage.mq5](./Slippage.mq5)

## 定位

```text
Tick Buffer → VWAP / Spread / Flow / Imbalance Feature
```

这份源码不应作为“Slippage 策略”收藏，而应作为 microstructure feature seed。

## 可收藏点

- `MqlTick` rolling buffer；
- `SymbolInfoTick()` 实时获取 tick；
- VWAP over time window；
- Flow / imbalance over short window；
- spread pips；
- ATR context；
- hysteresis 避免 alert 频繁闪烁；
- panel update 采用 changed-only 更新思路。

## 平台映射

```text
TickStream
  ↓
TickBuffer
  ↓
MicrostructureFeatures
  ↓
Signal / Risk / Execution Filter
```

可迁移特征：

```text
vwap
price_vs_vwap
spread_pips
spread_to_atr
flow
imbalance
tick_rate
cheap_spread_flag
```

## 不建议直接复用的部分

- UI panel 占源码大部分；
- 没有落库；
- tick buffer 不应只存在于 EA 内存；
- 生产平台应写入 DuckDB / Parquet 并支持 replay。

