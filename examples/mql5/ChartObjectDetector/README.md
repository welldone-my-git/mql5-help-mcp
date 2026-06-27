# Chart Object Detector

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/22540>
- Title: How to Detect and Normalize Chart Objects in MQL5 (Part 1)

Positioning:

```text
Chart Geometry Layer / object detection and normalization skeleton.
```

## Files

- `ChartObjectDetector.mqh` - normalized chart object detector.
- `ObjectDetectionTestEA.mq5` - small EA that scans the chart every 5 seconds and prints detected objects.

## Core Takeaways

- Enumerate chart objects with `ObjectsTotal()` and `ObjectName()`.
- Validate object existence with `ObjectFind()`.
- Read object type through `OBJPROP_TYPE`.
- Normalize heterogeneous chart objects into one struct:

```text
SChartObjectInfo
├── name
├── type
├── type_name
├── time1 / price1
└── time2 / price2
```

- Extract object-specific anchor properties through one internal method.

## Reuse Notes

- This is not a strategy and not an indicator.
- It is the first layer of a geometry engine:

```text
Chart Objects
    ↓
Scanner
    ↓
Normalizer
    ↓
Geometry Objects
    ↓
Interaction / Events / Features
```

- Current implementation supports basic anchors for trendline, channel, rectangle, horizontal line, and vertical line.
- `OBJ_FIBO` is named in `ObjectTypeToString()` but not yet fully normalized with all levels.
- For production use, add object filtering, richer properties, state cache, and event generation.

Recommended framework location:

```text
Framework/Geometry/
├── ChartObjectScanner.mqh
├── ChartObjectNormalizer.mqh
├── GeometryObject.mqh
├── ObjectFilter.mqh
└── GeometryEvent.mqh
```
