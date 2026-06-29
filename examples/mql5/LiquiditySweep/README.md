# Liquidity Sweep

来源：

- 文章：https://www.mql5.com/en/articles/18379
- 标题：Price Action Analysis Toolkit Development (Part 27): Liquidity Sweep With MA Filter Tool
- 作者：Christian Benjamin（LynnChris）
- 源码：[Liquidity_Sweep.mq5](./Liquidity_Sweep.mq5)

## 定位

```text
Prior High / Low Sweep → Reclaim / Rejection Event
```

这份源码适合作为 SMC / ICT 事件检测的入门样例。收藏点是 sweep event，不是信号本身。

## 可收藏点

- Bull / Bear sweep 规则；
- LessStrict / Strict 两种严格度；
- 可选 candlestick confirmation；
- MA filter 作为上下文过滤；
- closed bar 检测；
- 用箭头和 label 标记事件。

## 平台映射

```text
LiquidityLevel
  ↓
SweepDetector
  ↓
LiquiditySweepEvent
  ↓
Context Feature / Meta Label
```

可迁移特征：

```text
sweep_direction
swept_level_type
reclaim_strength
candle_body_ratio
ma_context
bars_since_sweep
```

## 不建议直接复用的部分

- “扫流动性后立即交易”缺少统计验证；
- 只用前一根 K 线高低点，结构层级较浅；
- 没有统一 event / buffer 输出；
- 应扩展到 session high/low、PDH/PDL、swing high/low。

