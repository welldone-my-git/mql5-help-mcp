# Geometry Interaction

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/22662>
- Title: How to Detect and Normalize Chart Objects in MQL5 (Part 3)

Positioning:

```text
Chart Geometry Interaction / Event / Execution demo layer.
```

## Files

- `MQL5/Include/ChartObjectsAlgorithms/InteractionDetector.mqh` - interaction engine for touches, crosses, breakouts, and geometry proximity.
- `MQL5/Include/ChartObjectsAlgorithms/AlertManager.mqh` - duplicate-suppressed alert manager.
- `MQL5/Include/ChartObjectsAlgorithms/TradeExecutor.mqh` - demo trade execution wrapper.
- `MQL5/Include/ChartObjectsAlgorithms/ChartObjectDetector.mqh` - base object detector.
- `MQL5/Include/ChartObjectsAlgorithms/ComplexObjectDataCollector.mqh` - complex geometry collector.
- `MQL5/Experts/TestInteractionEA.mq5` - integration demo EA.

## Core Takeaways

- Convert normalized geometry objects into runtime interactions:
  - trendline touch / cross;
  - rectangle breakout;
  - Fibonacci level touch;
  - channel boundary touch;
  - pitchfork median / level touch.
- Return event-like records through `SInteraction`.
- Track object state to avoid repeated touch / cross spam.
- Separate responsibilities:

```text
ChartObjectDetector
    ↓
ComplexObjectCollector
    ↓
InteractionDetector
    ↓
AlertManager / TradeExecutor
```

## Reuse Notes

- Treat `TradeExecutor.mqh` as a demo, not production execution logic.
- The valuable reusable layer is `InteractionDetector.mqh` plus the `SInteraction` event record.
- This module is the bridge from manual chart geometry to feature / signal / event pipelines.
- For research use, interactions should be exported as events or features before they are turned into trades.

Recommended framework location:

```text
Framework/Geometry/
├── InteractionDetector.mqh
├── GeometryEvent.mqh
├── AlertManager.mqh
└── GeometryFeatureGenerator.mqh
```
