# Meta-Labeling ADX Pipeline

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/22754>
- Title: Meta-Labeling the Classics (Part 2): Filtering and Sizing ADX Trades
- Published: 2026-06-26

Positioning:

```text
Python research pipeline for upgrading a classic ADX / DI-cross system with HPO, meta-labeling, and bet sizing.
```

## Files

- `adx_system.py` - Wilder-style ADX / ADXR calculation and DI-cross signal generator.
- `adx_hpo.py` - Optuna optimization for ADXR threshold, DI period, and DI separation gate.
- `adx_features.py` - ADX-centered meta features.
- `adx_pipeline.py` - full HPO → triple barrier → random forest → probability sizing pipeline.
- `afml/` - local AFML helper subset used by the pipeline.

Original parquet data files and `__pycache__` artifacts are intentionally not imported.

## Core Takeaways

- ADX is treated as a primary signal engine, not as a complete strategy.
- The first layer is an optimized regime gate:

```text
ADXR threshold + DI period + DI separation
```

- The second layer is meta-labeling:

```text
Signal → Triple Barrier → Meta Features → Classifier Probability
```

- The third layer is bet sizing:

```text
Probability → Position Size
```

## Reuse Notes

This is best treated as a reusable classic-indicator upgrade template:

```text
Classic Indicator
    ↓
Primary Signal
    ↓
Optimized Gate
    ↓
Meta Label
    ↓
Meta Model
    ↓
Probability
    ↓
Bet Size
```

Recommended framework location:

```text
research/
├── primary_models/adx.py
├── gate/optuna_gate.py
├── features/adx_features.py
├── labeling/triple_barrier.py
├── models/
├── sizing/bet_sizing.py
└── walkforward/
```
