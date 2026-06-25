# BreakEven Framework：ATR / RRR 保本机制的可插拔架构

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/18111>
- Title: Implementing a Breakeven Mechanism in MQL5 (Part 2): ATR- and RRR-Based Breakeven
- Author: Niquel Mendoza
- Date: 2026-06-08
- Category: MetaTrader 5 / Examples
- Local source: [BreakEven_Framework](../../examples/mql5/BreakEven_Framework/)

## 总体评价

| 项目 | 评分 | 是否收藏 |
|---|---:|---|
| 架构设计 | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| OOP 设计 | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| 参数系统 | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| 可扩展性 | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| 交易思想 | ⭐⭐⭐☆☆ | 一般 |
| BreakEven 算法 | ⭐⭐⭐☆☆ | 常规 |

一句话总结：

> 这篇的价值不在 ATR 或 RRR 保本公式，而在于它把 BreakEven 做成了可扩展、可插拔、可维护的 EA 框架组件。

## 核心定位

文章表面上是：

```text
ATR BreakEven
RRR BreakEven
Fixed Points BreakEven
```

但真正值得收藏的是：

```text
BreakEven Framework
│
├── CBreakEvenBase
├── CBreakEvenSimple
├── CBreakEvenAtr
├── CBreakEvenRR
└── CBreakEven Manager
```

也就是：

```text
Factory + Strategy + Polymorphism + Manager
```

这套结构可以迁移到：

- Trailing Stop；
- Stop Loss；
- Exit Engine；
- Filter Engine；
- Position Protection；
- Risk Module；
- Trade Management Plugin。

## 1. 抽象基类：CBreakEvenBase

`CBreakEvenBase` 定义统一接口，子类只负责自己的保本价格计算。

核心接口：

```text
virtual Add(...)
virtual Set(MqlParam &params[])
BreakEven()
```

Base 负责：

- position ticket 维护；
- magic / symbol 过滤；
- 已跟踪持仓数组；
- 触发后修改 Stop Loss；
- 公共执行流程。

子类负责：

- Simple：固定点数；
- ATR：基于 ATR 倍数；
- RR：基于风险回报比。

这是典型 Template Pattern：

```text
Base 控制流程
Child 定义细节
```

## 2. 策略子类：Simple / ATR / RR

继承结构：

```text
CBreakEvenBase
        ▲
        │
 ┌──────┼────────┐
 │      │        │
Simple ATR      RRR
```

每个子类只处理自己的计算规则。

这点非常重要：EA 不需要知道“当前保本模式到底是什么”，它只调用统一接口。

## 3. 参数系统：MqlParam[]

这是全篇最值得收藏的设计之一。

作者没有给每个 BE 类型设计完全不同的构造函数，而是通过：

```text
MqlParam params[]
obj.Set(params)
```

统一配置不同策略。

意义：

- ATR 可以有 ATR period、timeframe、index、multiplier；
- RR 可以有 coefficient、extra type、ATR 参数；
- Simple 可以有固定点数；
- 新增模式时不需要改 EA 调用方式。

这就是插件化参数系统。

后续可以迁移成：

```text
TrailingParam[]
ExitParam[]
FilterParam[]
RiskParam[]
```

## 4. Factory：CreateBreakEven()

Manager 内部通过工厂创建具体对象：

```text
CreateBreakEven(type)
    ├── CBreakEvenSimple
    ├── CBreakEvenAtr
    └── CBreakEvenRR
```

以后新增：

```text
CBreakEvenTime
CBreakEvenVolatility
CBreakEvenSession
CBreakEvenML
```

只需要增加 class 和 factory 分支，EA 主流程不用重写。

这是标准 Factory + Strategy。

## 5. Manager：CBreakEven

`CBreakEven` 本身不是具体保本算法，而是 Manager。

它负责：

- 创建具体 BE 对象；
- 保存不同模式参数；
- 切换内部指针；
- 调用 `Set()`；
- 暴露统一运行入口。

典型流程：

```text
SetBeByATR()
    ↓
保存参数
    ↓
SetInternalPointer()
    ↓
CreateBreakEven()
    ↓
obj.Set(params)
    ↓
obj.BreakEven()
```

EA 层只需要：

```text
break_even.SetInternalPointer(type)
break_even.obj.BreakEven()
```

更理想的封装是让 EA 只调用：

```text
break_even.Run()
```

避免直接访问内部 `obj` 指针。

## 6. 配置保存思想

Manager 保存每种模式对应的参数。

价值：

```text
切换模式
    ↓
复用已保存参数
    ↓
重新创建内部策略对象
    ↓
继续运行
```

这对多模式 EA 很重要。

很多 EA 的问题是参数散落在 input 和全局变量里，切换策略时容易丢状态。这里把参数归属到 Manager，是更好的结构。

## 7. Indicator Handle 生命周期

ATR 模式使用：

```text
iATR()
CopyBuffer()
IndicatorRelease()
INVALID_HANDLE
```

这部分值得作为 MQL5 handle 生命周期模板收藏。

关键点：

- 创建 handle 后检查 `INVALID_HANDLE`；
- `CopyBuffer()` 前后检查返回值；
- 析构时释放 handle；
- `ArraySetAsSeries()` 对齐时间序列；
- 参数错误时明确中断。

## 8. 算法本身评价

算法不新。

ATR 保本：

```text
BE price = Open ± ATR * extra_multiplier
Trigger  = Open ± ATR * trigger_multiplier
```

RRR 保本：

```text
Trigger = Risk * RR
BE      = Open ± extra
```

这些都是常规保本逻辑。真正可收藏的是框架，不是公式。

## 可以继续优化的地方

### 1. 不建议 EA 直接访问 obj

当前示例中 EA 会调用：

```text
break_even.obj.BreakEven()
```

更好的做法：

```text
break_even.Run()
```

Manager 应隐藏内部策略指针，避免外部误操作。

### 2. ExpertRemove() 过于强硬

参数错误时直接 `ExpertRemove()` 虽然安全，但在大型框架里不够柔性。

建议改成：

```text
bool Configure(...)
string Error()
```

由上层决定：

- 停止 EA；
- 禁用 BE 模块；
- 切换到默认 Simple 模式；
- 记录错误并继续。

### 3. 参数系统可类型化

`MqlParam[]` 灵活，但可读性弱。

可以进一步封装：

```text
SBreakEvenATRConfig
SBreakEvenRRConfig
SBreakEvenSimpleConfig
```

再统一序列化为 `MqlParam[]`，兼顾类型安全和插件化。

### 4. Manager 可纳入 Trade Management Engine

更完整架构：

```text
TradeManager
│
├── BreakEvenEngine
├── TrailingEngine
├── PartialCloseEngine
├── TimeExitEngine
└── RiskGuard
```

BreakEven 只是 Position Management 的一个插件。

## 推荐提炼到源码库的模块

一级收藏：

- `CBreakEvenBase` 抽象基类；
- `CBreakEven` Manager；
- `CreateBreakEven()` Factory；
- `MqlParam[]` 动态配置；
- 统一 `Set()` / `Add()` / `BreakEven()` 接口；
- Strategy + Polymorphism 的整体结构。

二级收藏：

- ATR handle 生命周期；
- `position_be` 持仓保本缓存结构；
- 参数合法性校验；
- Magic / symbol 过滤；
- 测试 set 文件。

不重点收藏：

- ATR / RRR 具体公式；
- Order Block EA 策略本身；
- 单次回测结论。

## 最终结论

这篇属于 EA 框架文章，不是保本算法文章。

它展示了一个大型 EA 里非常重要的工程思想：

```text
交易功能不应该写成 if/else 堆叠
而应该写成可插拔组件
```

如果目标是构建自己的 MQL5 EA 框架，这篇应归类为：

```text
MQL5 Framework
└── Trade Management
    └── BreakEven Plugin System
```

收藏价值：★★★★★。

## 标签

```text
BreakEven
Trade Management
Factory Pattern
Strategy Pattern
Polymorphism
MqlParam
ATR Handle
RRR
MQL5 OOP
EA Framework
```
