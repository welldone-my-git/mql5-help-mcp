# TickValue Compare

Source:

- MQL5 CodeBase: <https://www.mql5.com/en/code/73211>
- File: `TickValue_Compare.mq5`
- Author: Vinicius Pereira De Oliveira

Positioning:

```text
Developer utility / risk diagnostics tool, not a trading strategy.
```

## Files

- `TickValue_Compare.mq5` - script that compares tick-value properties for all Market Watch symbols.

## Core Takeaways

- Compare these three symbol properties:
  - `SYMBOL_TRADE_TICK_VALUE`
  - `SYMBOL_TRADE_TICK_VALUE_LOSS`
  - `SYMBOL_TRADE_TICK_VALUE_PROFIT`
- Scan Market Watch with `SymbolsTotal(true)` and `SymbolName(i, true)`.
- Classify symbols into:
  - `ALL_EQUAL`
  - `TV_MATCHES_PROFIT`
  - `TV_MATCHES_LOSS`
  - `ALL_DIFFER`
- Export a CSV report for Python-side broker diagnostics.

## Reuse Notes

- For risk-based position sizing, prefer `SYMBOL_TRADE_TICK_VALUE_LOSS` when estimating stop-loss money risk.
- `SYMBOL_TRADE_TICK_VALUE` is not always equal to the loss-side tick value.
- This script is useful for validating broker behavior before trusting a generic lot-sizing formula.
- Treat the source as a diagnostic utility and extract its checks into a `RiskManager` or `BrokerDiagnostics` module.

Recommended framework location:

```text
Framework/Risk/
├── BrokerSymbolAudit.mqh
├── TickValueDiagnostics.mqh
└── PositionSizing.mqh
```
