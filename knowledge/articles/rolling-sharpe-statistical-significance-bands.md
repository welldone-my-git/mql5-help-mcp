# Rolling Sharpe：带统计显著性区间的策略诊断组件

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22978>
- Title: Rolling Sharpe Ratio with Statistical Significance Bands in MQL5
- Author: Ushana Kevin Iorkumbul
- Date: 2026-06-22
- Category: MetaTrader 5 / Indicators
- Local source: [RollingSharpe](../../examples/mql5/RollingSharpe/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 统计思想 | ⭐⭐⭐⭐⭐ |
| MQL5 架构 | ⭐⭐⭐⭐⭐ |
| 代码质量 | ⭐⭐⭐⭐☆ |
| 可复用程度 | ⭐⭐⭐⭐⭐ |
| 交易策略价值 | ⭐☆☆☆☆ |
| 收藏价值 | 8.8/10 |

一句话总结：

> 这篇不是交易策略文章，而是一个优秀的统计分析组件，用来判断策略表现是否真的有 alpha。

## 核心思想

普通 Sharpe 只给一个点估计：

```text
Sharpe = mean(return) / std(return)
```

这篇实现的是 Rolling Sharpe：

```text
SR(t)
SR(t+1)
SR(t+2)
...
```

更关键的是，它同时绘制统计显著性区间：

```text
Sharpe +/- z * SE
```

其中 Lo 标准误公式为：

```text
SE(SR) = sqrt((1 + 0.5 * SR^2) / n)
```

这比只画一条 Sharpe 曲线有价值得多。

如果 Rolling Sharpe 是 `1.2`，但 95% 置信区间是：

```text
[-0.4, 2.8]
```

这说明不能证明 Sharpe 显著大于 0。点估计看起来不错，但统计上仍可能是噪声。

## 真正值得收藏的模块

### 1. CReturnBuffer

这是全篇最值得收藏的代码。

它是固定长度循环缓冲区，维护：

```text
m_data[]
m_head
m_count
m_sum
m_sumSq
```

每次 `Push()`：

- 如果 buffer 未满，直接加入；
- 如果 buffer 已满，先删除最旧值；
- 同步更新 `sum` 和 `sumSq`；
- 移动 head 指针。

这样 `Mean()`、`Variance()`、`StdDev()` 都可以 O(1) 返回。

这类组件可以复用于几乎所有滚动统计：

- rolling mean；
- rolling variance；
- rolling volatility；
- Z-score；
- skew；
- kurtosis；
- entropy；
- Sortino；
- Information Ratio。

### 2. CSharpeCalculator

第二个值得收藏的是计算器职责分离。

它不是把所有逻辑塞进指标 `OnCalculate()`，而是封装成：

```text
AddReturn()
Calculate()
IsReady()
Reset()
```

这让 Sharpe 计算可以被多个消费者复用：

- Indicator；
- EA；
- Optimizer；
- CSV exporter；
- Python bridge。

### 3. SSharpeResult

统一结果结构很实用：

```text
sharpe
upperBand
lowerBand
se
valid
```

以后统计组件都应该采用类似返回模式：

```text
value
upper
lower
standard_error
valid
```

不要只返回一个 `double`，否则调用方无法知道这个结果是否成熟、是否有效、是否具有统计意义。

### 4. ComputeBar 无状态设计

文章特别强调 MT5 指标引擎可能因为历史刷新、周期切换或重新加载导致：

```text
prev_calculated = 0
```

很多依赖状态累积的 rolling indicator 会在这种情况下输出看似合理但实际不完整的数据。

源码里的 `ComputeBar()` 对每根 bar 独立计算，牺牲部分性能换稳定性。

这是一种成熟的工程取舍：

```text
组件层：CReturnBuffer 适合 O(1) 实时更新
指标层：ComputeBar 适合应对 MT5 完整重算
```

两者并不冲突。

## 数学价值

数学不复杂，但有实用价值。

Lo 的标准误公式提醒一件事：

```text
短窗口 Sharpe 的不确定性非常大
```

所以很多看起来漂亮的短期 Sharpe，其实根本不能证明策略有效。

这个思想可以扩展到：

- Rolling Sortino；
- Information Ratio；
- Calmar；
- alpha t-stat；
- factor IC；
- rolling win rate。

重点是画不确定性，而不是只画点估计。

## 不建议重点收藏的部分

以下部分价值较低：

- 指标绘图样式；
- Sharpe 本身的基础公式；
- 固定参数示例；
- 只把它当交易信号使用；
- 仅凭 Sharpe 上下穿线决定买卖。

这篇的定位应该是策略诊断，而不是 alpha 生成。

## 可放入个人框架的模块

建议归入：

```text
MQL5 Quant Framework
└── Statistical Analytics
    ├── RollingBuffer
    ├── RollingStats
    ├── SharpeCalculator
    ├── ConfidenceBand
    └── StrategyDiagnostics
```

Python 侧也可以保留同样接口：

```text
RollingStats
    Mean()
    Variance()
    Std()
    Skew()
    Kurtosis()
    Sharpe()
    Sortino()
```

MQL5 负责实时轻量诊断，Python 负责批量研究和更复杂统计检验。

## 最终结论

这篇值得收藏，但原因不是 Rolling Sharpe 本身。

真正应沉淀的是：

```text
CReturnBuffer
O(1) rolling statistics
SSharpeResult
CSharpeCalculator
Confidence bands
ComputeBar stateless design
```

它适合成为你 MQL5 Quant Framework 中的统计分析基础组件。

## 标签

```text
Rolling Sharpe
Statistical Analytics
CReturnBuffer
Rolling Statistics
Circular Buffer
Confidence Band
Lo Standard Error
Strategy Diagnostics
MQL5 Indicator
```
