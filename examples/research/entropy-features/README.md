# Entropy Features

Source:

- Article: https://www.mql5.com/en/articles/22756
- Author: Patrick Murimi Njoroge
- Knowledge map: [Patrick AFML Research Map](../../../knowledge/articles/patrick-njoroge-afml-research-map.md)
- Architecture note: [AFML Feature Engine](../../../knowledge/architecture/afml-feature-engine.md)

## Contents

```text
entropy_optimized.py
```

This file implements optimized entropy estimators for AFML-style feature engineering:

- Shannon entropy;
- plug-in / block entropy;
- Lempel-Ziv complexity;
- Kontoyiannis entropy;
- tick-rule encoding;
- quantile / sigma encoding;
- per-bar entropy kernels.

## Why this is collected

Entropy features are useful as state representation, not direct trading signals.

Typical use:

```text
Tick / Bar sequence
    ↓
Symbol encoding
    ↓
Entropy / complexity
    ↓
Regime / confidence / risk throttle / meta feature
```

## Extraction target

Future platform module:

```text
research/features/entropy.py
```

Expected interface:

```python
def entropy_features(series, encoding="tick_rule") -> dict[str, float]:
    ...
```

## Usage boundary

Do not use entropy as a standalone buy/sell rule. Treat it as:

- market structure complexity;
- noise / randomness proxy;
- model confidence context;
- risk throttle feature.

