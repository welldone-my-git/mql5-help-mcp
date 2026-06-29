# Market Structure Event Engine

## 定位

统一 BOS、ChoCH、Liquidity Sweep、Opening Range Breakout 等结构事件。

```text
Market Data
  ↓
Structure Detector
  ↓
StructureEvent
  ↓
Feature / Regime / Signal
```

来源样例：

- [FractalReactionBOS](../../examples/mql5/FractalReactionBOS/)
- [LiquiditySweep](../../examples/mql5/LiquiditySweep/)
- [OpeningRangeBreakout](../../examples/mql5/OpeningRangeBreakout/)

## 事件类型

```text
BOS
CHOCH
LIQUIDITY_SWEEP
RANGE_DEFINED
RANGE_BREAKOUT
RANGE_RETEST
```

## 事件 schema

```text
StructureEvent
  ├── event_id
  ├── timestamp
  ├── symbol
  ├── timeframe
  ├── event_type
  ├── direction
  ├── level_price
  ├── source
  ├── confidence
  └── metadata
```

## 设计规则

1. 使用闭合 K 线确认结构事件。
2. 不在 detector 内直接下单。
3. 所有事件必须可落库和 replay。
4. 结构事件可作为 Feature，也可作为 Primary Signal。
5. 风控和执行必须由下游 RiskEngine / OrderManager 决定。

## Python 平台映射

```text
research/structure/
  fractals.py
  bos_choch.py
  liquidity_sweep.py
  opening_range.py
  events.py
```

## Feature 输出

```text
last_structure_event
bars_since_event
distance_to_event_level
structure_direction
structure_regime
```

