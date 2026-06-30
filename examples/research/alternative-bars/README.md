# Alternative Bars

Source:

- Article: https://www.mql5.com/en/articles/22213
- Author: Patrick Murimi Njoroge
- Knowledge map: [Patrick AFML Research Map](../../../knowledge/articles/patrick-njoroge-afml-research-map.md)
- Architecture notes:
  - [AFML Feature Engine](../../../knowledge/architecture/afml-feature-engine.md)
  - [Scientific Research Pipeline](../../../knowledge/architecture/scientific-research-pipeline.md)

## Contents

```text
Python/
└── afml/data_structures/
    ├── bars.py
    ├── calibration.py
    ├── information_bars.py
    └── __init__.py

MQL5/
└── AlternativeBars/
    ├── Experts/BarBuilderEA.mq5
    └── Include/AlternativeBars/
        ├── CBarConstructor.mqh
        ├── CStandardBars.mqh
        ├── CImbalanceBars.mqh
        └── CRunsBar.mqh
```

## What this demonstrates

The example implements AFML-style alternative sampling:

- tick bars;
- volume bars;
- dollar bars;
- imbalance bars;
- runs bars.

The useful architecture:

```text
Raw ticks
    ↓
Bar constructor
    ↓
Alternative bar stream
    ↓
FeatureEngine / LabelEngine / Replay
```

## Important boundary

The Python attachment contains the `afml.data_structures` subpackage only.

`bars.py` imports helpers from:

```text
afml.cache
afml.util.misc
```

Those support modules are not included in this article attachment. Treat the Python code as a reference implementation, not a standalone package without adaptation.

## Platform extraction target

Future platform module:

```text
research/sampling/
├── tick_bars.py
├── volume_bars.py
├── dollar_bars.py
├── imbalance_bars.py
└── runs_bars.py
```

MQL5 side:

```text
MQL5 AlternativeBars
    ↓
real-time tick sampling
    ↓
bar export / feature snapshot
```

## Why this matters

Time bars are not the only valid market representation.

Alternative bars help reduce sampling bias and make model inputs closer to market activity:

```text
clock time
    vs
trade count / volume / dollar flow / imbalance / runs
```

This connects directly to:

- Romanov discretization;
- AFML feature engineering;
- Meta labeling;
- replay dataset generation.

