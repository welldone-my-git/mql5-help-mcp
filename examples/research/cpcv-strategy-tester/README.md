# CPCV Strategy Tester Bridge

Source:

- Article: https://www.mql5.com/en/articles/21954
- Author: Patrick Murimi Njoroge
- Knowledge map: [Patrick AFML Research Map](../../../knowledge/articles/patrick-njoroge-afml-research-map.md)
- Architecture note: [AFML Research Validation](../../../knowledge/architecture/afml-research-validation.md)

## Contents

```text
MQL5/
├── CPCVBacktest.mq5
├── FeatureEngine.mqh
└── Calibrator.mqh

Python/
├── export_pipeline_artifacts.py
└── cpcv_postprocess.py
```

## What this demonstrates

This example connects Python ML research artifacts to MetaTrader 5 Strategy Tester:

```text
Python model pipeline
    ↓
ONNX model / calibrator / feature spec / CPCV masks
    ↓
MQL5 Strategy Tester
    ↓
one path per optimization pass
    ↓
per-path equity CSV
    ↓
Python post-processing
```

Key ideas:

- ONNX model runs inside MQL5;
- calibration is exported into flat files;
- feature specification is consumed by MQL5;
- CPCV path masks are precomputed in Python;
- MT5 Strategy Tester optimization agents are reused for parallel path simulation;
- Python computes path Sharpe distribution and PBO audit.

## Platform extraction target

Future modules:

```text
research/validation/cpcv.py
research/model_export/export_artifacts.py
replay/mt5_strategy_tester_adapter.py
storage/validation_report.py
```

## Boundary

This is not a generic ready-to-run strategy.

It assumes the upstream Python pipeline has already created:

- ONNX model;
- calibrator artifact;
- feature names/spec;
- events DataFrame;
- CPCV fold/path masks.

The important reusable part is the Research → MT5 Strategy Tester validation contract.

