# Complex Object Geometry：Fibonacci、Channel、Pitchfork 的几何抽象层

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22563>
- Title: How to Detect and Normalize Chart Objects in MQL5 (Part 2)
- Local source: [ComplexObjectGeometry](../../examples/mql5/ComplexObjectGeometry/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 软件架构 | ⭐⭐⭐⭐⭐ |
| MQL5 代码质量 | ⭐⭐⭐⭐⭐ |
| Python 迁移价值 | ⭐⭐⭐⭐⭐ |
| ML Feature 价值 | ⭐⭐⭐⭐⭐ |
| 交易策略价值 | ⭐⭐☆☆☆ |
| 收藏价值 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 如果 22540 是 Geometry Foundation，这篇就是 Geometry Engine：把 Fib、Channel、Pitchfork 这类复杂对象解析成可计算的几何结构。

## 系列位置

三篇可以串成完整链路：

```text
22540
Chart Object Detection / Normalization
    ↓
22563
Complex Geometry Extraction
    ↓
22662
Interaction / Event / Execution Layer
```

这篇处在中间层，也是最核心的一层。

## 解决的问题

Part 1 只能稳定获得基础对象：

```text
name
type
time1 / price1
time2 / price2
```

但复杂对象不止两个点。

例如：

- Fibonacci 有 levels；
- Channel 有 3 个 anchor；
- Pitchfork 有 handle、median point、parallel levels；
- FibFan / FibArc / FibTimes 也有 level 信息。

这篇把这些复杂对象继续展开成结构化数据。

## 核心源码结构

### 1. IsAnalyticalObject()

过滤分析对象：

```text
OBJ_FIBO
OBJ_FIBOTIMES
OBJ_FIBOFAN
OBJ_FIBOARC
OBJ_CHANNEL
OBJ_PITCHFORK
OBJ_TREND
OBJ_RECTANGLE
```

这是比 Part 1 更明确的 Type Filter。

### 2. SComplexObjectInfo

`SComplexObjectInfo` 继承 `SChartObjectInfo`，并增加复杂对象字段：

```text
fibo_ratios[]
fibo_prices[]

channel_time[3]
channel_price[3]

pitchfork_handle_time[2]
pitchfork_handle_price[2]
pitchfork_median_time
pitchfork_median_price

pitchfork_level_values[]
pitchfork_level_texts[]
```

这是全文最值得收藏的设计。

它把复杂 chart object 转成 geometry-ready data。

### 3. CComplexObjectDetector

`CComplexObjectDetector` 继承 `CChartObjectDetector`。

关键是 Part 2 的 `ChartObjectDetector.mqh` 把：

```text
m_chart_id
ExtractProperties()
```

改为 protected，让子类可以复用基础扫描和 anchor 读取逻辑。

### 4. Fibonacci Parser

`ExtractFibonacciLevels()` 读取：

```text
OBJPROP_LEVELS
OBJPROP_LEVELVALUE
```

`ComputeActualFibonacciPrices()` 把 ratio 转成真实价格。

EA 或 Python 后续不应该每次重新计算 Fib 价格，而应直接使用 `fibo_prices[]`。

### 5. Channel Parser

`ExtractChannelPoints()` 读取 3 个 anchor：

```text
channel_time[0..2]
channel_price[0..2]
```

这为后续计算提供基础：

- upper line；
- lower line；
- median line；
- channel width；
- channel slope；
- channel position。

### 6. Pitchfork Parser

`ExtractPitchforkData()` 读取：

- handle points；
- median point；
- optional levels。

Pitchfork 是很多 MQL5 示例不会认真处理的对象。

这里的价值在于把复杂图形对象拆成可计算字段。

## Demo EA 的价值

`TestComplexObjectsEA.mq5` 里有两个有价值的小函数：

```text
LineValueAtTime()
PitchforkMedianValue()
```

它们展示了：

```text
Anchor Points → Current Price Projection → Distance Feature
```

但 demo 里的 `Print()` / alert 不应当作为交易逻辑收藏。

## 机器学习 Feature 价值

这篇最适合迁移成 Geometry Feature Generator。

### Fibonacci Features

```text
nearest_fib_level
distance_to_fib
fib_zone
touch_fib_618
```

### Channel Features

```text
distance_to_upper
distance_to_lower
channel_width
channel_slope
channel_position
```

### Pitchfork Features

```text
distance_to_median
distance_to_upper_parallel
distance_to_lower_parallel
pitchfork_level_distance
```

这些都可以进入：

```text
Feature Matrix
    ↓
Meta Label
    ↓
LightGBM / XGBoost / CatBoost
```

## 与 Meta Labeling 的结合

典型结构：

```text
Primary Signal:
    RSI cross / ADX DI cross / Breakout

Meta Features:
    near fib618
    near channel upper
    distance to pitchfork median
    inside rectangle

Meta Model:
    trade or skip
```

这类几何特征是传统 OHLC 指标无法直接提供的 context。

## Python 迁移建议

```text
quant/
└── geometry/
    ├── base.py
    ├── detector.py
    ├── collector.py
    ├── fib.py
    ├── channel.py
    ├── pitchfork.py
    ├── feature_generator.py
    └── interaction.py
```

统一接口：

```text
class GeometryObject:
    anchors()
    levels()
    lines()
    price_at(time)
    distance(price, time)
    features(bar)
```

## 值得收藏的内容

一级收藏：

- `IsAnalyticalObject()` type filter；
- `SComplexObjectInfo` 复杂对象结构；
- `CComplexObjectDetector` 继承式 collector；
- `ExtractFibonacciLevels()`；
- `ComputeActualFibonacciPrices()`；
- `ExtractChannelPoints()`；
- `ExtractPitchforkData()`；
- `LineValueAtTime()` / `PitchforkMedianValue()` 思想。

二级收藏：

- demo proximity alert；
- 5 秒节流扫描；
- object print/debug 方式。

不重点收藏：

- 直接交易逻辑；
- demo `Print()` 输出；
- alert 触发文案；
- 当前不完整的 channel / pitchfork feature 计算。

## 不足与生产化建议

### 1. Geometry Interface 还不完整

当前只是采集字段。

建议继续抽象：

```text
IGeometryObject
ILevelProvider
ILineProvider
IDistanceProvider
```

### 2. Channel 需要完整几何计算

应补充：

```text
upper_price_at(time)
lower_price_at(time)
median_price_at(time)
width()
normalized_position(price, time)
```

### 3. Pitchfork 需要 parallel lines

当前只展示 median 和 levels。

生产版要计算：

```text
median line
upper parallel
lower parallel
level offsets
```

### 4. Fibonacci 方向和对象类型要严谨

Fib retracement、Fib fan、Fib arc、Fib time 本质不同。

生产版不应统一只用价格 ratio。

应按对象类型拆：

```text
FibRetracementGeometry
FibFanGeometry
FibArcGeometry
FibTimeGeometry
```

### 5. 需要缓存和增量更新

对象变化并非每 tick 都发生。

建议：

```text
ObjectCache
hash/object version
dirty update
event on object change
```

## 推荐框架结构

```text
Framework/
└── Geometry/
    ├── BaseChartObjectDetector.mqh
    ├── ComplexObjectCollector.mqh
    ├── GeometryObject.mqh
    ├── FibonacciGeometry.mqh
    ├── ChannelGeometry.mqh
    ├── PitchforkGeometry.mqh
    ├── GeometryFeatureGenerator.mqh
    └── InteractionDetector.mqh
```

## 最终结论

这篇应作为 Geometry Engine 核心条目收藏。

它真正提供的是：

```text
Chart Object
    ↓
Complex Geometry Object
    ↓
Math / Feature / Event / Strategy
```

对于 Python + MQL5 自研研究框架，这层比单个策略更重要，因为它能支撑 SMC、ICT、趋势线、通道、Pitchfork、Fib、Liquidity Zone 等所有“图形几何型”研究。

## 标签

```text
MQL5
Geometry Engine
Chart Objects
Complex Object Collector
Fibonacci
Channel
Pitchfork
Feature Engineering
Meta Labeling Context
Python Migration
EA Framework
```
