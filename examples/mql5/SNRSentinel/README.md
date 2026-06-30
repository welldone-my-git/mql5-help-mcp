# SNR Sentinel

Source:

- CodeBase: https://www.mql5.com/en/code/69219
- Author: Bikeen / Chukwubuikem Okeke
- Knowledge map: [Bikeen Market Structure Engine Map](../../../knowledge/articles/bikeen-market-structure-engine-map.md)
- Architecture note: [Market Structure Event Engine](../../../knowledge/architecture/market-structure-event-engine.md)

## Contents

```text
SNR_SENTINEL.mq5
```

The source was downloaded from CodeBase and converted from UTF-8 with BOM to plain UTF-8 for repository search/diff compatibility.

## Why this is collected

The useful part is not the line drawing itself. The reusable pattern is:

```text
detect candidate support / resistance
    ↓
validate level
    ↓
monitor break
    ↓
mark broken
    ↓
replace with next valid level
```

This should become a `SupportResistanceEngine` that outputs structured events and features:

- distance to support;
- distance to resistance;
- support touch;
- resistance touch;
- support break;
- resistance break;
- bars since level update.

## Boundary

Do not use S/R touch or break directly as a trading rule. Treat it as context for:

- FeatureEngine;
- Meta Labeling;
- Regime;
- Risk filters.

