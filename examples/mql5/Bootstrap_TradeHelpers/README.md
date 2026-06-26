# Bootstrap Trade Helpers

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/21398>
- Title: MQL5 Bootstrap (I): Reusable Functions for Positions and Orders

Positioning:

```text
EA bootstrap / trade helper layer, not a trading strategy.
```

## Files

- `Include/positions.mqh` - reusable position helpers for existence checks, counts, closing, recent position, and oldest position.
- `Include/orders.mqh` - reusable pending order helpers for existence checks, counts, cancellation, recent order, and oldest order.
- `Experts/SMA crossover EA.mq5` - minimal demo EA showing how helpers keep signal code cleaner.

## Core Takeaways

- Centralize repeated position and order scans in a bootstrap layer.
- Use one generic function with optional filters, then expose convenience wrappers.
- Keep signal logic focused on signal decisions, not low-level account iteration.
- Recent and oldest position/order helpers are reusable for grid, pyramiding, FIFO, and cleanup logic.

## Notes Before Reuse

- Treat this as an architecture reference, not production-ready framework code.
- `orders.mqh` contains a typo in the include line: `#include <Trade\Trade.mqh>0`.
- Some wrappers use `INT_MAX` while the generic functions use `LONG_MAX` as the sentinel. Normalize this before direct reuse.
- A class-based `CPositionManager` / `COrderManager` with a `PositionFilter` or `OrderFilter` struct would scale better.

Recommended destination in a larger framework:

```text
Framework/Trade/
├── PositionManager.mqh
├── OrderManager.mqh
├── DealManager.mqh
└── HistoryManager.mqh
```
