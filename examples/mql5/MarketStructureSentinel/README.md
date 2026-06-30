# Market Structure Sentinel

Source:

- Article: https://www.mql5.com/en/articles/22249
- Author: Bikeen / Chukwubuikem Okeke
- Knowledge note: [Market Structure Sentinel](../../../knowledge/articles/market-structure-sentinel-bikeen.md)
- Architecture note: [Market Structure Event Engine](../../../knowledge/architecture/market-structure-event-engine.md)

## Contents

```text
Market_Structure_Sentinel.mq5
```

The source was downloaded from the article attachment and converted from UTF-8 with BOM to plain UTF-8 for repository search/diff compatibility.

## Why this is collected

This indicator is useful as a market-structure core reference:

- swing high / swing low state;
- pivot strength parameter;
- HH / HL / LH / LL context;
- BOS and CHOCH distinction;
- chart object rendering of structure breaks.

## Extraction target

Future platform module:

```text
research/structure/
├── swings.py
├── structure_state.py
├── bos_choch.py
└── events.py
```

The platform should emit `StructureEvent`; the detector itself should not place trades.

