# Market Structure Event Engine：BOS / ChoCH / Liquidity Sweep / ORB

来源：

- BOS / ChoCH：https://www.mql5.com/en/articles/19365
- Liquidity Sweep：https://www.mql5.com/en/articles/18379
- Opening Range Breakout：https://www.mql5.com/en/articles/18486
- 作者：Christian Benjamin（LynnChris）
- 源码：
  - [FractalReactionBOS](../../examples/mql5/FractalReactionBOS/)
  - [LiquiditySweep](../../examples/mql5/LiquiditySweep/)
  - [OpeningRangeBreakout](../../examples/mql5/OpeningRangeBreakout/)

## 结论

这批文章应该归类为 Market Structure Event，不应归类为策略。

```text
Fractal / High-Low / Session Range
  ↓
Structure Event
  ↓
Feature / Regime / Meta Label
```

## BOS / ChoCH

核心价值：

```text
Fractal pivot
  ↓
Structure level
  ↓
Break
  ↓
BOS or ChoCH
```

它能提供 regime / structure state：

```text
trend_continuation
trend_change_warning
last_structure_break
```

## Liquidity Sweep

核心价值：

```text
sweep prior level
  ↓
close reclaim / reject
  ↓
sweep event
```

适合生成 SMC / ICT context feature，而不是直接下单。

## Opening Range

核心价值：

```text
session start
  ↓
range capture
  ↓
range high / low
  ↓
breakout / retest
```

这应接入 session calendar 和 replay。

## 平台统一事件

建议抽象：

```text
StructureEvent(
    event_type,
    direction,
    level_price,
    source_level,
    confirmation_time,
    confidence,
    metadata
)
```

事件类型：

```text
BOS
CHOCH
LIQUIDITY_SWEEP
OPENING_RANGE_BREAKOUT
OPENING_RANGE_RETEST
```

## 研究特征

```text
bars_since_bos
bars_since_choch
last_sweep_direction
opening_range_size_atr
distance_to_structure_level
structure_regime
```

这些是 Meta Labeling 和 Regime Detection 的输入，不是孤立交易信号。

