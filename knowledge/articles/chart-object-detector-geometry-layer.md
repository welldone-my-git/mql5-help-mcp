# Chart Object Detector：从手动画线到 Geometry Layer

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22540>
- Title: How to Detect and Normalize Chart Objects in MQL5 (Part 1)
- Local source: [ChartObjectDetector](../../examples/mql5/ChartObjectDetector/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 交易策略价值 | ⭐⭐☆☆☆ |
| 软件架构价值 | ⭐⭐⭐⭐⭐ |
| Python 迁移价值 | ⭐⭐⭐⭐⭐ |
| 研究框架价值 | ⭐⭐⭐⭐⭐ |
| 收藏价值 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 这篇不是策略文章，而是 Chart Geometry Layer 的起点：把人工画在图上的对象扫描、读取、标准化，变成 EA 和研究系统能理解的数据结构。

## 它解决的问题

传统 EA 直接读图表对象时，代码很容易变成：

```text
if OBJ_TREND:
    read time1 price1 time2 price2
if OBJ_RECTANGLE:
    read left right upper lower
if OBJ_HLINE:
    read price
...
```

对象越多，业务代码越乱。

文章的思路是先建一层 parser：

```text
Chart
    ↓
Object Enumerator
    ↓
Property Reader
    ↓
Normalizer
    ↓
Object List
```

EA 后续不直接关心底层 `ObjectGet*()`。

## 核心源码结构

源码很短，但骨架清晰。

### 1. SChartObjectInfo

统一输出结构：

```text
name
type
type_name
time1
time2
price1
price2
```

这是最值得收藏的部分。

它把不同 chart object 统一成一个可传递、可缓存、可分析的对象记录。

### 2. ObjectTypeToString()

把 MQL5 object type 转成人类可读字符串：

```text
TREND
RECTANGLE
CHANNEL
HLINE
VLINE
FIBO
UNKNOWN
```

这属于基础 utility。

### 3. CChartObjectDetector

核心接口：

```text
Init(chart_id)
Total()
Detect(out_objects[])
```

`Detect()` 内部执行：

```text
ObjectsTotal
ObjectName
ObjectFind
ObjectGetInteger(OBJPROP_TYPE)
ExtractProperties
```

这就是最小 Chart Object Scanner。

### 4. ExtractProperties()

针对不同对象读取不同 anchor：

- `OBJ_TREND`;
- `OBJ_CHANNEL`;
- `OBJ_RECTANGLE`;
- `OBJ_HLINE`;
- `OBJ_VLINE`.

这一步是 normalization 的基础。

## 真正价值

这篇真正值钱的不是“读到了几条线”。

而是它提供了一层：

```text
Manual Chart Object → Structured Geometry Data
```

后面可以继续做：

```text
Geometry Data
    ↓
Distance
    ↓
Touch / Cross / Breakout
    ↓
Event
    ↓
Signal / Feature / Meta Label
```

## 与后续 Interaction Layer 的关系

这篇是：

```text
Object Abstraction Layer
```

后续复杂对象和交易执行文章可以接在它后面：

```text
22540: detect and normalize chart objects
    ↓
Interaction Layer: touch / cross / breakout / bounce
    ↓
Execution Layer: trade decisions
```

所以它是前置基础，不是最终策略。

## 对 Python 研究框架的价值

如果迁移到 Python，可以形成：

```text
quant/
└── geometry/
    ├── scanner.py
    ├── parser.py
    ├── object.py
    ├── normalizer.py
    ├── interaction.py
    └── events.py
```

统一对象：

```text
ChartObject
├── id
├── type
├── points
└── properties
```

然后派生：

- `Trendline`;
- `Rectangle`;
- `Channel`;
- `Fib`;
- `Pitchfork`;
- `HLine`;
- `VLine`.

## Geometry Feature

这层对机器学习很有价值。

它能生成传统指标之外的几何特征：

```text
distance_to_trendline
distance_to_channel
inside_rectangle
touch_fib_level
break_channel
channel_position
```

这些可以直接进入 feature matrix：

```text
ATR
RSI
ADX
Volume
TrendlineDistance
FibDistance
RectangleState
ChannelPosition
```

对 Meta Labeling 特别自然：

```text
Primary Signal: RSI cross
Meta Features: near trendline / inside rectangle / touch fib / break channel
Meta Model: should trade?
```

## 值得收藏的内容

一级收藏：

- Object scanner；
- `SChartObjectInfo` normalized struct；
- object type mapping；
- property extraction method；
- chart id abstraction；
- `Detect(out_objects[])` 统一入口。

二级收藏：

- 测试 EA 的 5 秒节流扫描；
- `ObjectFind()` 安全检查；
- defaults initialization。

不重点收藏：

- demo 打印逻辑；
- 当前支持对象数量；
- 交易逻辑，因为本篇基本没有交易逻辑。

## 不足与生产化建议

### 1. Type Filter 还不完整

当前源码会扫描所有对象，只是不支持的对象字段为空。

生产版建议加入：

```text
ObjectFilter
```

只保留策略相关对象，过滤 UI、按钮、标签等。

### 2. Fibo 还没有完整 normalization

`ObjectTypeToString()` 支持 `OBJ_FIBO`，但 `ExtractProperties()` 没有读取 fib levels。

后续应扩展：

```text
anchor points
level count
level value
level price
```

### 3. Geometry 方法应分离

Detector 只负责读取对象。

几何计算应放到独立层：

```text
PriceAt(time)
DistanceTo(price, time)
IsInside(price, time)
Intersects(bar)
```

### 4. 需要状态缓存

实时 EA 不能每 tick 盲目重复处理所有对象。

建议增加：

```text
ObjectCache
ObjectVersion
LastUpdated
Dirty flag
```

### 5. 需要事件层

最终 EA 不应直接读 geometry object，而应接收事件：

```text
TOUCH
CROSS
BREAKOUT
BOUNCE
INVALIDATE
```

## 推荐框架结构

```text
Framework/
└── Geometry/
    ├── ChartObjectScanner.mqh
    ├── ObjectFilter.mqh
    ├── ObjectNormalizer.mqh
    ├── GeometryObject.mqh
    ├── TrendlineGeometry.mqh
    ├── RectangleGeometry.mqh
    ├── FibGeometry.mqh
    ├── InteractionDetector.mqh
    └── GeometryEvent.mqh
```

## 最终结论

这篇应作为 Geometry Engine 的基础条目收藏。

它的长期价值不是 MQL5 语法，而是这一层抽象：

```text
Manual Chart Objects
    ↓
Normalized Geometry Objects
    ↓
Features / Events / Signals
```

对于 Python + MQL5 研究执行分离框架，这层可以把手动画线、SMC、ICT、趋势线、通道、矩形区间全部纳入统一 feature / event 系统。

## 标签

```text
MQL5
Chart Objects
Geometry Layer
Object Detection
Object Normalization
Manual Chart To Strategy
Feature Engineering
Meta Labeling Context
EA Framework
```
