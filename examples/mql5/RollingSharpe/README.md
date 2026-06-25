# Rolling Sharpe

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/22978>
- Title: Rolling Sharpe Ratio with Statistical Significance Bands in MQL5

Positioning:

```text
Statistical analytics component, not a trading strategy.
```

## Files

- `CReturnBuffer.mqh` - fixed-size circular buffer for O(1) rolling mean, variance, and standard deviation.
- `CSharpeCalculator.mqh` - Sharpe calculator with Lo standard error bands and `SSharpeResult`.
- `RollingSharpe.mq5` - indicator example that plots rolling Sharpe, upper band, lower band, and zero line.

## Core Takeaways

- Keep rolling statistics in a reusable component.
- Maintain `sum` and `sumSq` incrementally instead of rescanning the whole window.
- Return analytical results through a struct with `valid`, `sharpe`, `upperBand`, `lowerBand`, and `se`.
- Draw confidence bands, not just the Sharpe point estimate.
- Treat the indicator drawing code as a consumer of the statistics engine.

## Reuse Targets

This pattern can be extended to:

- rolling mean;
- rolling variance;
- Z-score;
- volatility;
- skew;
- kurtosis;
- Sortino;
- Information Ratio;
- strategy diagnostics.

The useful part is the statistics component architecture. The plotted indicator is only one frontend.
