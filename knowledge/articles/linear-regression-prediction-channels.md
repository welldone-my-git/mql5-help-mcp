# Linear Regression Prediction Channels：统计化回归通道

来源：

- 文章：https://www.mql5.com/en/articles/23130
- 标题：Linear Regression Prediction Channels in MQL5: Constructing Statistically Grounded Confidence and Prediction Bands
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-26
- 源码目录：[examples/mql5/RegressionChannels](../../examples/mql5/RegressionChannels/)

## 收藏结论

收藏价值：★★★★☆

这篇不是通道交易策略，而是统计分析组件。它的价值在于把“价格通道”从固定倍数经验规则升级成：

```text
Rolling OLS
  ↓
Residual Variance
  ↓
Student's t Critical Value
  ↓
Confidence Interval
  ↓
Prediction Interval
```

## 核心价值

### 1. 明确区分 CI 与 PI

很多通道指标只画“上下轨”，但不说明上下轨含义。

这篇明确拆分：

- Confidence Interval：趋势均值估计误差；
- Prediction Interval：单个价格观测的可能范围。

对交易研究而言，PI 更适合做异常、突破、覆盖率诊断。

### 2. Student's t 而不是固定 2 倍标准差

通道宽度来自自由度和 t 分布，而不是经验 multiplier。

这使它可以进入统计诊断体系：

```text
nominal coverage
actual coverage
breach frequency
residual diagnostics
```

### 3. Leverage-Aware Width

回归通道在窗口中心最窄，边缘更宽。这来自 OLS leverage 项。

这比 Bollinger 的 uniform width 更有模型解释。

### 4. 模块化源码

源码拆成：

```text
OLSStatistics
ResidualAnalysis
TDistribution
ConfidenceInterval
PredictionInterval
RegressionChannels
```

职责边界清晰，适合纳入统计组件库。

## 平台迁移建议

```text
research/statistics/
├── ols.py
├── residuals.py
├── intervals.py
└── regression_channel.py
```

输出特征：

```text
reg_slope
residual_std
prediction_width
confidence_width
price_position_in_pi
pi_upper_breach
pi_lower_breach
rolling_coverage_error
```

## 风险和不足

- OLS 假设在金融市场经常不成立；
- raw price regression 容易受非平稳影响；
- 当前 MQL5 实现是窗口重算，不是 O(1) rolling sums；
- 需要 out-of-sample coverage test；
- 后续可加入 robust standard errors。

## 归档建议

放入：

```text
Statistics / Diagnostics / Forecast Intervals
```

不要归类为 alpha 策略。
