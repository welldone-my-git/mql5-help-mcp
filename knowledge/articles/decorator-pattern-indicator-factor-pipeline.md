# Decorator Pattern in MQL5：从指标包装到因子处理 Pipeline

## 来源

- 标题：Implementing the Decorator Pattern in MQL5: Adding Logging, Timing, and Filtering to Any Indicator Non-Invasively
- 来源：https://www.mql5.com/en/articles/22962
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-19
- 分类：MetaTrader 5 / Trading systems
- 处理日期：2026-06-23
- 源码目录：[examples/mql5/DecoratorPattern](../../examples/mql5/DecoratorPattern/)

## 用户评审结论

这不是交易策略文章，而是 MQL5 工程设计文章。

评分：

- 研究价值：★☆☆☆☆
- 交易价值：☆☆☆☆☆
- MQL 工程价值：★★★★★
- Python 迁移价值：★★★★☆
- 学习价值：★★★★☆

补充评分：

- 工程设计：8/10
- MQL5 代码规范：7/10
- 实盘策略价值：2/10
- 学习价值：8/10

核心关键词：

```text
Pipeline
```

## 文章核心

文章讲 Decorator Pattern：

```text
原始指标
↓
过滤器 decorator
↓
日志 decorator
↓
计时 decorator
↓
EA 调用
```

目标是不修改 RSI / MA 指标本身，而是在外部包一层功能。

文章示例包括：

- `IIndicator`
- `CRSIIndicator`
- `CMovingAverageIndicator`
- `CBaseDecorator`
- `CLoggingDecorator`
- `CTimingDecorator`
- `CThresholdFilterDecorator`

核心思想：

```text
指标只负责计算。
日志、计时、过滤等横切功能放到外层 wrapper。
```

这符合 Open-Closed Principle：

```text
open for extension
closed for modification
```

## 为什么有价值

差的实现会把所有东西写进一个函数或一个类：

```text
def factor():
  计算动量
  去极值
  标准化
  中性化
  打日志
  存缓存
  做过滤
```

好的结构是：

```text
Factor Core
+ Decorator Pipeline
```

也就是把“因子计算”和“因子处理”分离。

这对用户正在搭建的 quant 框架很关键：

```text
features/
states/
factors/
models/
backtest/
```

对于 EA 框架，也可以迁移成：

```text
Indicator
  -> CacheDecorator
  -> LoggerDecorator
  -> TimingDecorator
  -> SignalFilterDecorator
```

重点是学习：

```text
接口抽象 + 装饰器链 + 资源释放模式
```

不要把文章里的 RSI 阈值过滤当作严肃交易逻辑。

## MQL5 工程模式

### 1. 统一接口

文章用 `IIndicator` 作为统一 contract：

```text
GetValue(shift)
GetName()
```

所有 concrete indicator 和 decorator 都实现同一个接口。因此 EA 不关心当前拿到的是：

- 原始 RSI
- 原始 MA
- 被日志包装过的 RSI
- 被过滤 + 日志 + 计时包装过的 RSI

调用侧只依赖：

```text
IIndicator*
```

### 2. Concrete Component

`CRSIIndicator` / `CMovingAverageIndicator` 只做一件事：

- 创建 terminal indicator handle
- 用 `CopyBuffer()` 获取值
- 析构时 `IndicatorRelease()`

不关心：

- 日志
- 计时
- 阈值过滤
- 策略上下文

这符合单一职责。

资源释放意识是这篇值得学的点之一：指标 handle 有明确 owner，生命周期结束时释放，不把 terminal handle 泄漏给外层调用者。

### 3. Base Decorator

`CBaseDecorator` 持有一个被包装的 `IIndicator*`。

默认行为：

```text
GetValue() -> delegate to wrapped.GetValue()
GetName()  -> delegate to wrapped.GetName()
```

析构时负责释放下游动态对象，外部只需要删除最外层 decorator。

这点在 MQL5 中很重要，因为对象生命周期和指针释放需要显式管理。

但要注意：这种裸指针 ownership 模式必须写清楚谁拥有对象、谁只是观察者。文章里存在非拥有观察指针的用法，虽然在 `OnDeinit()` 中置空，但这类设计容易演化成悬垂指针。更稳健的工程约束是：

```text
owner pointer:
  只存在于 decorator chain 中，由最外层 delete 级联释放

observer pointer:
  只读，不 delete，不跨生命周期保存
```

如果确实需要旁路观察，建议用名字、ID、registry 或明确的 non-owning 注释，而不是模糊共享裸指针。

### 4. Concrete Decorators

典型横切能力：

- `CLoggingDecorator`：被动观察，打印指标名和值。
- `CTimingDecorator`：测量 `GetValue()` 执行耗时。
- `CThresholdFilterDecorator`：在不改指标代码的情况下添加阈值过滤。

调用链可以自由组合：

```text
CTimingDecorator
  -> CLoggingDecorator
    -> CThresholdFilterDecorator
      -> CRSIIndicator
```

文章里阈值过滤把不满足条件的值返回为 `0.0`。这在 RSI 示例里勉强能理解，但作为通用指标接口并不安全，因为 `0.0` 可能本身就是有效值。

更稳健的设计：

```text
方案 A: 返回 EMPTY_VALUE
方案 B: bool TryGetValue(int shift, double &value)
方案 C: 返回 IndicatorValue { bool valid; double value; string reason; }
方案 D: 单独输出 filter state / signal state
```

如果未来用于因子框架，过滤层不应把“无效/未通过”和“数值为 0”混在一起。

## 迁移到 Python 因子框架

这篇对用户最直接的价值在 Python quant 框架。

可以把指标装饰器迁移成因子处理 pipeline：

```python
raw_factor = MomentumFactor()

factor = ZScore(
    Winsorize(
        Neutralize(
            raw_factor
        )
    )
)
```

横切能力不要写进每个因子内部，而是外包：

- winsorize
- zscore
- neutralize
- rank
- log
- cache
- missing-value handling
- universe filter
- industry neutralization
- turnover constraint

## 推荐抽象

### Factor 接口

```text
Factor.compute(context) -> Series/DataFrame
Factor.name -> string
```

### Decorator 接口

```text
FactorDecorator(Factor)
  compute(context):
    raw = wrapped.compute(context)
    return transform(raw)
```

### Pipeline 示例

```text
MomentumFactor
→ WinsorizeDecorator
→ ZScoreDecorator
→ NeutralizeDecorator
→ CacheDecorator
→ LoggingDecorator
```

更清晰的研究流程：

```text
raw feature
→ clean
→ standardize
→ neutralize
→ validate
→ evaluate
```

## 适合沉淀成项目能力的内容

### MQL5 侧

可做：

```text
examples/mql5/patterns/indicator-decorator/
```

但要避免照搬原文代码。建议自研版本：

- `IIndicator`
- `IndicatorHandleAdapter`
- `LoggingDecorator`
- `TimingDecorator`
- `ThresholdDecorator`
- 简单 EA 调用示例

### Python 侧

更优先：

```text
examples/research/factor-decorator-pipeline/
```

内容：

- `Factor`
- `MomentumFactor`
- `Winsorize`
- `ZScore`
- `Neutralize`
- `Cache`
- `RankIC` evaluation hook

### 文档模式

```text
knowledge/patterns/factor-decorator-pipeline.md
```

沉淀：

- core vs cross-cutting concerns
- pipeline composition
- decorator ordering
- cache ownership
- logging / timing / validation hooks

## 注意事项

### 1. Decorator 顺序很重要

不同顺序含义不同：

```text
ZScore(Winsorize(raw))
```

和：

```text
Winsorize(ZScore(raw))
```

不是完全等价。

对因子研究建议固定顺序并记录元数据：

```text
raw -> winsorize -> neutralize -> zscore -> rank
```

### 2. 日志和缓存不应改变值

Logging / Timing / Cache 属于 observational decorators，原则上不应改变输出。

Filtering / Winsorize / Neutralize 属于 transforming decorators，会改变结果，必须进入实验记录。

日志 decorator 还需要节流。文章把虚函数调用和栈帧开销说得较轻，这是合理的；但在高频 tick、多品种、多指标链下，真正的大开销往往是 `Print()` 本身，而不是 decorator 调用链。

建议：

```text
log every N bars
log only on state change
log only in debug mode
aggregate timing stats instead of per tick Print
disable logging in production
```

### 3. 避免过度包装

Decorator 太多会导致调试困难。需要：

- pipeline repr
- 每层输入输出统计
- 异常定位
- 中间结果可选保存

### 4. MQL5 指针所有权必须明确

MQL5 中最外层 decorator 删除时会级联删除内部对象。不要重复 delete 内层对象。

建议在类名或注释中区分：

- owning wrapper
- non-owning observer
- registry-managed object

否则装饰器链复杂后，最容易出现 double delete 或 dangling pointer。

### 5. 过滤返回语义必须明确

不要用 `0.0` 表示“未通过过滤”，除非指标定义保证 0 不是有效值。

对交易系统来说，推荐区分：

```text
no value
invalid value
filtered out
valid signal with value = 0
```

这些状态在风控、日志、回测归因里含义完全不同。

## 与前面知识条目的关系

这篇可作为以下研究条目的工程支撑：

- `qnn-markov-feature-pipeline-mql5.md`
  - Feature Pipeline 可以用 decorator 组织。
- `kyles-lambda-market-impact-liquidity-factor.md`
  - Lambda 因子可接 winsorize / zscore / event filter。
- `adaptive-kalman-smoother-regime-factor.md`
  - Kalman Gain 可接 regime filter / logging / cache。

组合示例：

```text
KyleLambdaFactor
→ Winsorize
→ ZScore
→ RegimeCondition(KalmanGain)
→ RankICLogger
```

EA 工程组合示例：

```text
RSIIndicator
→ CacheDecorator
→ ThresholdFilterDecorator
→ TimingDecorator
→ ThrottledLoggerDecorator
```

## 结论

这篇不提供交易策略，也没有 alpha 价值。

但如果目标是搭建自己的量化研究框架，它比很多“神经网络交易系统”更值得学。真正要记住的是：

```text
把因子计算和因子处理分离。
用 Decorator / Pipeline 组织横切能力。
```

它适合做工程架构参考，不适合寻找交易策略。文章中的阈值过滤只是装饰器演示，不是严肃信号设计。

## 标签

- MQL5
- engineering
- design pattern
- decorator pattern
- pipeline
- factor pipeline
- indicator wrapper
- logging
- timing
- filtering
- Open-Closed Principle
- Python migration
- quant framework
