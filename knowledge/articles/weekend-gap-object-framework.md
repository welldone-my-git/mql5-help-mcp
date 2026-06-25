# Weekend Gap Structure Mapping：Chart Object 状态管理框架

## 来源

- 标题：Price Action Analysis Toolkit Development (Part 71): Weekend Gap Structure Mapping in MQL5
- 来源：https://www.mql5.com/en/articles/22796
- 作者：Christian Benjamin
- 发布日期：2026-06-08
- 分类：MetaTrader 5 / Trading systems
- 本地源码：[examples/mql5/WeekendGapIndicator/WeekendGapIndicator.mq5](/home/novo/quant/github/welldone-my-git/mql5-help-mcp/examples/mql5/WeekendGapIndicator/WeekendGapIndicator.mq5)
- 处理日期：2026-06-25

## 用户评审结论

总体评分：

| 项目 | 评分 |
| --- | --- |
| 交易思想 | ★★★☆☆ |
| MQL5 架构 | ★★★★☆ |
| 代码质量 | ★★★★☆ |
| 可复用程度 | ★★★★★ |
| 值得收藏 | 推荐收藏，偏框架，不偏策略 |
| 综合收藏价值 | 8.8/10 |

一句话总结：

```text
不是一个优秀的交易策略，
但却是一套非常好的图形对象状态管理框架。
```

建议收藏的是：

```text
Object Framework + Entity + State Machine + Visual Layer
```

而不是 Weekend Gap 交易逻辑。

## 核心价值：Object Framework

文章没有使用 indicator buffer，而是用 chart objects 构造一个结构化对象。

一个 `WeekendGap` 实体由多个对象组成：

```text
WG_<id>_RECT
WG_<id>_VMARK
WG_<id>_MID
WG_<id>_LBL
WG_<id>_TOP
WG_<id>_BOT
WG_<id>_MIDPRICE
```

也就是：

```text
一个业务对象
  ↓
多个 Chart Object
```

这套设计可迁移到：

- Supply Zone；
- Demand Zone；
- Fair Value Gap；
- Order Block；
- Liquidity Pool；
- Session Box；
- VWAP Zone；
- Opening Range；
- Manual Risk Zone。

建议未来抽象成：

```text
ChartObjectBase
├── Create()
├── Update()
├── Delete()
└── Refresh()
```

## Entity 设计

源码定义：

```text
WeekendGapRecord
├── startTime
├── endTime
├── gapHigh
├── gapLow
├── midpoint
├── isGapDown
├── state
└── activeWeek
```

这是标准 entity 设计。

可以直接迁移成：

```text
FairValueGapRecord
├── startTime
├── endTime
├── high
├── low
├── direction
├── filled
├── strength
├── touchCount
└── state
```

或者：

```text
OrderBlockRecord
├── high
├── low
├── direction
├── firstTouch
├── mitigated
├── broken
└── state
```

核心是：

```text
数据结构稳定，业务逻辑和显示层围绕 Entity 运转。
```

## 状态机设计

源码定义：

```text
enum ENUM_GAP_STATE
{
  GAP_FRESH,
  GAP_PARTIAL,
  GAP_REACTION,
  GAP_FILLED,
  GAP_HISTORICAL
};
```

`UpdateCurrentState()` 根据当前价格和 gap 区间更新状态。

这比在各处写零散 if 更可维护。

同样模式可用于：

```text
FVG:
  OPEN
  PARTIAL_FILL
  FILLED
  INVALID

OrderBlock:
  FRESH
  TOUCHED
  MITIGATED
  BROKEN
  HISTORICAL

Liquidity Zone:
  ACTIVE
  SWEPT
  REACTION
  INVALIDATED
```

这篇最值得收藏的就是这种：

```text
Market Structure Entity
  ↓
State Machine
  ↓
Visual Update
```

## Visual Layer 分离

源码中：

```text
UpdateGapVisuals()
```

只负责：

- 颜色；
- 透明度；
- 字体；
- 线宽；
- fill；
- label text；
- historical style；
- active style。

它不负责：

- gap 检测；
- gap 交易；
- gap 状态判断；
- 信号生成。

这接近 MVC：

```text
Data Layer
  ↓
State Layer
  ↓
Visual Layer
```

以后所有 chart object 型指标都建议这样拆。

## 生命周期管理

整体生命周期：

```text
OnInit()
  ↓
初始化 VisualSettings

OnCalculate() first run
  ↓
DetectAllGaps()
  ↓
CreateGapObjects()

OnCalculate() live
  ↓
UpdateCurrentState()
  ↓
UpdateGapVisuals()

Week rollover
  ↓
active → historical

OnDeinit()
  ↓
ObjectsDeleteAll("WG_")
```

这是一套完整的 chart object 生命周期管理模板。

## Prefix 命名规范

源码统一使用：

```text
WG_
```

并用：

```text
PrefixForIndex(i)
```

生成对象名前缀。

好处：

- 对象分组清晰；
- 删除简单；
- 不污染用户其它对象；
- 易于 debug；
- 支持一个 entity 对应多个 object。

清理：

```text
ObjectsDeleteAll(0, "WG_")
```

这是 MQL5 图形对象管理必须养成的习惯。

## VisualSettings 配置结构

源码把视觉参数封装为：

```text
VisualSettings
├── activeFillColor
├── activeOutlineColor
├── reactionColor
├── memoryOutlineColor
├── activeFillOpacity
├── lineWidth
└── fontSize
```

这比到处散落颜色和线宽更好。

后续可升级为：

```text
Theme
├── dark
├── light
├── highContrast
└── custom
```

或者：

```text
ChartObjectStyle
```

供 FVG / OB / Session / Liquidity 共用。

## Utility 模块

值得抽到 `Utils.mqh` 的函数：

- `PipSize()`
- `GetWeekMonday()`
- `GetNextMondayOpen()`
- `ColorSetAlpha()`
- `StateToString()`

这些函数不属于 Weekend Gap 专有逻辑，可复用。

## 交易思想评价

Weekend Gap 逻辑本身一般。

基本思想：

```text
Friday Close
  ↓
Monday Open
  ↓
Gap Zone
  ↓
等待回补 / 反应
```

这是老策略，不是新 alpha。

文章没有证明：

- 为什么 gap 会回补；
- 什么条件下不回补；
- 哪些品种有效；
- 哪些 regime 有效；
- gap size 与未来收益关系；
- 成本和滑点影响；
- news / liquidity context。

因此：

```text
策略价值 ≈ ★★☆☆☆
框架价值 ≈ ★★★★★
```

## 最大问题：Gap 只是 Price Level，没有 Context

当前 gap 只是：

```text
Rectangle
```

缺少：

- ATR 过滤；
- volatility regime；
- trend filter；
- session context；
- volume；
- liquidity；
- news；
- market state；
- distance to VWAP；
- microstructure feature。

没有 context 的 gap 不是 alpha，只是结构标注。

## 推荐升级路线

如果重写，应从：

```text
Gap
  ↓
Draw Rectangle
```

升级为：

```text
GapDetector
  ↓
GapFeature
  ↓
GapScoring
  ↓
GapStateMachine
  ↓
GapPredictor
```

Gap Score 可设计为：

```text
GapStrength =
GapSize
× ATRContext
× TrendContext
× LiquidityContext
× VolumeSpike
× SessionContext
× DistanceToVWAP
```

然后再判断：

- 是否容易回补；
- 是否容易突破；
- 是否仅作为反应区；
- 是否应进入交易候选。

## 推荐提炼到源码库的模块

保留：

- `WeekendGapRecord` Entity 结构；
- `ENUM_GAP_STATE` 状态机；
- `Create / Update / Delete` object framework；
- data/state/visual 分层；
- lifecycle：Init → Detect → Update → Historical → Delete；
- prefix 对象命名规范；
- `VisualSettings`；
- utility functions。

不重点保留：

- weekend gap 检测业务本身；
- gap 回补策略；
- label 文案；
- 固定配色；
- 单一品种/周期假设。

## 和本项目已有知识的关系

这篇应归类为：

```text
Chart Object Framework / Visual State Machine
```

可和这些模块组合：

- Local Stop Loss：chart object 与 position lifecycle 同步；
- MSNR Clean：Signal Cluster / Dashboard；
- Universal Breakout：Session Box / Range Object；
- G Channel：结构线可视化；
- DSU + DBN：event cluster 可视化；
- Fluent Order Builder：从结构对象生成订单请求；
- CSV Export：导出 gap lifecycle 和交互统计。

## 最终结论

这篇值得进入源码精华库。

但收藏理由不是：

```text
Weekend Gap 策略有多强。
```

而是：

```text
它展示了如何把一个市场结构做成可持久、可更新、可变状态、可视化的 Chart Object Entity。
```

一句话沉淀：

```text
22796 的价值是 Object Framework，
Weekend Gap 只是这个框架的示例业务。
```

## 标签

- MQL5
- Chart Object
- Object Framework
- Weekend Gap
- State Machine
- Visual Layer
- Entity
- Price Action Toolkit
- FVG
- Order Block
- Liquidity Zone
