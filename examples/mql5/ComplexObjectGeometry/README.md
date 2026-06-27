# Complex Object Geometry

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/22563>
- Title: How to Detect and Normalize Chart Objects in MQL5 (Part 2)

Positioning:

```text
Chart Geometry Engine / complex analytical object collector.
```

## Files

- `ChartObjectDetector.mqh` - extended base detector; `m_chart_id` and `ExtractProperties()` are protected for inheritance.
- `ComplexObjectDataCollector.mqh` - `SComplexObjectInfo` and `CComplexObjectDetector`.
- `TestComplexObjectsEA.mq5` - demonstration EA for printing complex geometry data and simple proximity alerts.

## Core Takeaways

- Extend the Part 1 scanner into a complex analytical object collector.
- Filter analytical objects with `IsAnalyticalObject()`.
- Extend base object records with:
  - Fibonacci ratios and actual prices;
  - channel anchor points;
  - pitchfork handle points, median point, and optional levels.
- Convert chart objects into geometry-ready data:

```text
Chart Object
    ↓
ComplexObjectDetector
    ↓
SComplexObjectInfo
    ↓
Geometry / Feature / Interaction layer
```

## Reuse Notes

- This is still infrastructure, not a trading strategy.
- `ComputeActualFibonacciPrices()` is a useful example of converting drawing metadata into tradeable price levels.
- Channel and pitchfork extraction are valuable as feature-generation inputs.
- Demo alerts in `TestComplexObjectsEA.mq5` should not be treated as trading logic.

Recommended framework location:

```text
Framework/Geometry/
├── BaseChartObjectDetector.mqh
├── ComplexObjectCollector.mqh
├── FibonacciGeometry.mqh
├── ChannelGeometry.mqh
├── PitchforkGeometry.mqh
└── GeometryFeatureGenerator.mqh
```
