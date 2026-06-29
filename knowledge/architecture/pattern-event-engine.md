# Pattern Event Engine

## 定位

将图形形态从“画在图上”升级为可研究、可回放、可执行的事件。

```text
Price / Object
  ↓
Detector
  ↓
PatternEntity
  ↓
PatternEvent
  ↓
Feature / Signal / Risk
```

来源样例：

- [FlagPatternDetector](../../examples/mql5/FlagPatternDetector/)
- [WedgePatternDetector](../../examples/mql5/WedgePatternDetector/)
- [HeadShouldersScanner](../../examples/mql5/HeadShouldersScanner/)
- [ParallelChannelGeometry](../../examples/mql5/ParallelChannelGeometry/)

## PatternEntity

推荐字段：

```text
pattern_id
pattern_type
symbol
timeframe
anchors
start_time
end_time
direction
score
state
invalidation_price
breakout_price
metadata
```

## PatternState

```text
candidate
active
confirmed
breakout
failed
expired
```

## PatternEvent

```text
event_id
timestamp
symbol
source
pattern_id
pattern_type
event_type
direction
confidence
metadata
```

## 设计规则

1. 检测与交易分离

   Pattern detector 只产生事件，不下单。

2. 评分与方向分离

   `score` 表示形态质量，不等于做多/做空概率。

3. 视觉与事件分离

   renderer 可以画 triangle / channel / label，但事件必须可脱离图表对象存在。

4. 支持回放

   PatternEvent 应写入 storage，供 Replay / ML / Meta Label 使用。

5. 支持 schema version

   不同 pattern 的 metadata 不同，必须有版本字段。

## Python 平台映射

```text
research/patterns/
  detectors/
  entities.py
  events.py
  feature_generator.py
```

最终目标不是“自动画形态”，而是生成结构化 context features。

