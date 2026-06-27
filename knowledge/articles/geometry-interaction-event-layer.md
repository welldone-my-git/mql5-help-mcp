# Geometry Interaction：从几何对象到事件、特征与执行层

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22662>
- Title: How to Detect and Normalize Chart Objects in MQL5 (Part 3)
- Local source: [GeometryInteraction](../../examples/mql5/GeometryInteraction/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 工程设计 | ⭐⭐⭐⭐⭐ |
| 交易价值 | ⭐⭐⭐☆☆ |
| 研究价值 | ⭐⭐⭐⭐☆ |
| Python 迁移价值 | ⭐⭐⭐⭐⭐ |
| 收藏价值 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 这篇不是“画线突破 EA”，而是把 normalized geometry object 转成 interaction event 的应用层。

## 系列位置

这个系列可以按三层理解：

```text
22540 = Geometry Foundation
    Chart object scanner / normalizer

22563 = Geometry Engine
    Complex object collector: Fib / Channel / Pitchfork

22662 = Interaction & Event Layer
    Touch / Cross / Breakout / Alert / Execution
```

这篇解决的是：

```text
Geometry Object
    ↓
Interaction Event
    ↓
Signal / Feature / Alert / Trade
```

## 核心源码结构

附件包含完整模块：

```text
ChartObjectDetector
ComplexObjectDataCollector
InteractionDetector
AlertManager
TradeExecutor
TestInteractionEA
```

这是一个标准管线：

```text
Detector
    ↓
Collector
    ↓
Interaction Detector
    ↓
Alert / Execution
```

## 1. ENUM_INTERACTION

`InteractionDetector.mqh` 定义 interaction 类型。

它把对象和价格关系统一为事件。

这一步非常重要，因为 EA 后续不应直接关心：

```text
OBJ_TREND
OBJ_FIBO
OBJ_CHANNEL
OBJ_PITCHFORK
```

而应关心：

```text
TOUCH
CROSS
BREAKOUT
BOUNCE
```

## 2. SInteraction

`SInteraction` 是事件记录。

它保存：

- object name；
- object type；
- interaction type；
- level price；
- current price；
- time；
- level text。

这是全文最值得收藏的结构。

它把几何交互变成可传递的数据。

后续可以：

- alert；
- trade；
- log；
- export CSV；
- feed to Python；
- generate ML features；
- generate meta labels。

## 3. CInteractionDetector

`CInteractionDetector` 继承 `CComplexObjectDetector`。

核心方法：

```text
DetectInteractions(bid, ask, now)
GetInteraction(index, out)
InteractionCount()
```

内部针对不同对象分别检查：

- `CheckTrendline()`;
- `CheckRectangle()`;
- `CheckFibonacci()`;
- `CheckChannel()`;
- `CheckPitchfork()`.

这就是 Geometry Engine 到 Event Engine 的桥。

## 4. State Tracking

源码有对象状态跟踪：

```text
FindState(name)
SetState(name, value)
```

作用是避免重复事件：

```text
价格贴着趋势线连续 100 tick
    ↓
不能连续触发 100 次 Touch
```

这类状态机在所有实时 EA 中都非常重要。

值得抽象成：

```text
EventStateCache
```

## 5. AlertManager

`AlertManager.mqh` 做去重提醒。

它维护：

```text
object name
action
price
last alert time
```

这层说明作者已经开始把 interaction event 作为独立消息处理。

可迁移为：

```text
EventSink
NotificationSink
LoggerSink
WebhookSink
```

## 6. TradeExecutor

`TradeExecutor.mqh` 用 `CTrade` 做示范：

```text
Interaction
    ↓
Order Type
    ↓
SL / TP
    ↓
PositionOpen / Limit Order
```

这部分不应直接当实盘策略。

它的价值是分层：

```text
InteractionDetector only detects events
TradeExecutor handles execution
```

信号和执行分离，这是正确架构。

## 真正价值

表面看：

```text
趋势线 touch → alert / trade
```

实际价值：

```text
Manual Chart Geometry
    ↓
Interaction Event
    ↓
Feature / Meta Label / Execution
```

这让手工画线、SMC、ICT、Supply Demand、Liquidity Sweep 都可以走同一套底层事件系统。

## Geometry Feature 视角

对于 Python 研究框架，不建议直接用这些事件交易。

更建议生成特征：

```text
distance_to_trendline
trendline_touch
trendline_cross
rectangle_breakout
near_fib_level
channel_boundary_touch
pitchfork_median_distance
```

然后进入：

```text
Feature Matrix
    ↓
Meta Label
    ↓
Model
```

这比“碰线就买”高级得多。

## Meta Labeling 用法

例如：

```text
Primary Signal:
    RSI Cross

Geometry Context:
    near Fib618
    touch trendline
    inside rectangle
    break channel

Meta Model:
    should trade?
```

这正是 Meta Labeling 需要的 context features。

## SMC / ICT 用法

很多 SMC / ICT 对象本质也是 geometry：

```text
Order Block      = Rectangle
Fair Value Gap   = Rectangle
Liquidity Level  = Horizontal Line
BOS / CHOCH      = Line / Event
Supply Demand    = Rectangle
```

有了 Geometry Engine：

```text
SMC / ICT object
    ↓
Geometry Object
    ↓
Interaction Event
```

底层不用重复开发。

## Python 迁移建议

```text
quant/
└── geometry/
    ├── objects.py
    ├── detector.py
    ├── collector.py
    ├── interaction.py
    ├── events.py
    ├── state_cache.py
    ├── feature_generator.py
    └── sinks.py
```

事件结构：

```text
GeometryEvent
├── object_id
├── object_type
├── event_type
├── price
├── level_price
├── distance
├── time
└── metadata
```

## 值得收藏的内容

一级收藏：

- `ENUM_INTERACTION`;
- `SInteraction`;
- `CInteractionDetector`;
- `DetectInteractions()`;
- per-object check methods；
- object state tracking；
- AlertManager 的 duplicate suppression；
- signal / alert / trade 分层。

二级收藏：

- demo EA 集成方式；
- `TradeExecutor` 作为执行层样例；
- SL / TP 根据 interaction level 计算的思路。

不重点收藏：

- “touch 就交易”的 demo 逻辑；
- 固定 5 pip tolerance；
- 固定 lot size；
- 简单 R:R 计算；
- demo alert 文案。

## 不足与生产化建议

### 1. Event Type 应更细

建议拆成：

```text
TOUCH_FROM_ABOVE
TOUCH_FROM_BELOW
CROSS_UP
CROSS_DOWN
BREAKOUT_UP
BREAKOUT_DOWN
RETEST
INVALIDATION
```

### 2. Tolerance 应动态化

当前很多判断类似固定 pip tolerance。

生产版应改为：

```text
ATR × k
spread × k
symbol point aware
volatility aware
```

### 3. TradeExecutor 不能直接实盘复用

实盘执行必须接入：

- spread filter；
- session filter；
- max position；
- risk percent lot sizing；
- broker tick value；
- slippage；
- retry；
- order state tracking。

### 4. 需要导出事件

对研究平台来说，应把 interaction 导出为：

```text
CSV / JSON / Common Files / WebRequest
```

供 Python 做：

- event study；
- label；
- feature；
- model training。

## 推荐框架结构

```text
Framework/
└── Geometry/
    ├── ChartObjectDetector.mqh
    ├── ComplexObjectCollector.mqh
    ├── GeometryObject.mqh
    ├── InteractionDetector.mqh
    ├── GeometryEvent.mqh
    ├── EventStateCache.mqh
    ├── AlertManager.mqh
    ├── GeometryFeatureGenerator.mqh
    └── GeometryEventExporter.mqh
```

## 最终结论

这篇应作为 Geometry 系列的 Interaction/Event Layer 收藏。

它的价值不是交易策略，而是把：

```text
Chart Geometry
    ↓
Runtime Interaction
    ↓
Event / Feature / Signal / Execution
```

这条链打通。

对 Python + MQL5 研究执行框架来说，这一层非常重要，因为它把人工画线、复杂几何对象、SMC/ICT 结构和机器学习 context features 连接起来。

## 标签

```text
MQL5
Geometry Interaction
Chart Objects
Event Layer
InteractionDetector
AlertManager
TradeExecutor
Feature Engineering
Meta Labeling Context
SMC
ICT
EA Framework
```
