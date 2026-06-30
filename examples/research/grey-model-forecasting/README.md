# Grey Model Forecasting

Source:

- Article: https://www.mql5.com/en/articles/19012
- Author: Aleksej Poljakov / AIS Forex
- Knowledge note: [Grey Model Forecast Engine](../../../knowledge/articles/grey-model-forecast-engine-poljakov.md)
- Architecture note: [Forecast Engine](../../../knowledge/architecture/forecast-engine.md)

## Contents

This directory contains the MQL5 source files attached to `Forecasting in Trading Using Grey Models`.

```text
MQL5/
├── sGM.mq5       # script demonstrating grey series construction and GM smoothing
├── GM11.mq5      # classic GM(1,1) indicator
├── RGM11.mq5     # rolling / averaged GM(1,1) variants
├── GM11sma.mq5   # GM(1,1) using SMA values as input
├── GM11Ch.mq5    # GM(1,1)-based trend channel
├── DGM11.mq5     # discrete GM(1,1)
├── DGM02.mq5     # discrete GM(0,2), linear-regression-like variant
├── DGM12.mq5     # discrete GM(1,2) with two input factors
└── DGM21.mq5     # discrete second-order analogue
```

`GM11.mq5` and `RGM11.mq5` were converted from UTF-16 LE to UTF-8 for repository search and diff compatibility.

## Why this is collected

The value is not the indicator plots themselves. The useful parts are:

- AGO / inverse AGO as reusable time-series transforms;
- GM(1,1) as a small-sample forecasting baseline;
- rolling GM as a forecast ensemble pattern;
- adaptive weighting based on forecast error;
- discrete GM variants as recurrence-style forecasters;
- grey trend channel output as feature generation material.

## Platform extraction target

These files should eventually be refactored into a Python Research SDK module:

```text
research/forecasting/grey/
├── ago.py
├── gm11.py
├── rolling_gm.py
├── adaptive_gm.py
└── discrete_gm.py
```

With a common interface:

```python
class BaseForecaster:
    def fit(self, series): ...
    def update(self, value): ...
    def predict(self, horizon: int): ...
```

## Usage boundary

Do not treat these indicators as ready-made trading strategies.

They are research references for:

- forecast baseline testing;
- feature generation;
- model comparison;
- meta-labeling context;
- regime / trend diagnostics.

