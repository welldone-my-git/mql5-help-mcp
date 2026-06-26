# Meta-Labeling RSI Pipeline

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/22274>
- Title: Meta-Labeling the Classics (Part 1): Filtering and Sizing RSI Trades

Positioning:

```text
Python research pipeline for meta-labeling classic primary signals.
```

## Files

- `rsi_meta_pipeline.py` - RSI primary signal, triple-barrier labels, meta model, probability filter, bet sizing, and comparison backtest.

The original attachment also contains a EURUSD H1 parquet file. It is intentionally not imported into the repository.

## Core Takeaways

- Split the system into:
  - primary model: generates direction / candidate trades;
  - meta model: predicts whether the candidate trade is worth taking;
  - bet sizing: converts model probability into position size.
- Build features around signal context, not just raw OHLC.
- Use triple-barrier labeling to evaluate each primary signal.
- Compare three tracks:
  - plain RSI;
  - meta-labeled RSI;
  - meta-labeled plus probability-sized RSI.
- Keep Python as the research/training layer and export decisions or models to MT5 execution later.

## Reuse Notes

- The RSI strategy is only a demonstration primary model.
- The reusable part is the pipeline:

```text
Signal → Meta Label → Probability → Bet Size → Execution
```

Recommended framework location:

```text
research/
├── signals/
├── labeling/
├── features/
├── models/
├── sizing/
└── execution/
```
