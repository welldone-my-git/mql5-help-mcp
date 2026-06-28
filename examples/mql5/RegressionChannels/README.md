# Regression Channels：OLS Confidence / Prediction Bands

来源：

- 文章：https://www.mql5.com/en/articles/23130
- 标题：Linear Regression Prediction Channels in MQL5: Constructing Statistically Grounded Confidence and Prediction Bands
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-26

## 定位

```text
Statistical Channels / Regression Diagnostics / Prediction Interval Engine。
```

这不是交易策略，而是把传统通道从“经验带宽”升级为显式统计模型：rolling OLS + Student's t + confidence interval + prediction interval。

## 文件

| 文件 | 作用 |
|---|---|
| `OLSStatistics.mqh` | 计算 OLS slope、intercept、SSE、x_mean、Sxx |
| `ResidualAnalysis.mqh` | 用 `n-2` 自由度计算 residual variance / standard error |
| `TDistribution.mqh` | 用近似方法提供 Student's t critical value |
| `ConfidenceInterval.mqh` | 计算 regression mean 的置信区间 |
| `PredictionInterval.mqh` | 计算单个观测值的预测区间 |
| `RegressionChannels.mq5` | 主指标，绘制 regression line、CI upper/lower、PI upper/lower 五条线 |

## 值得抽取的模块

### 1. 统计职责拆分

源码把一个回归通道拆成五个统计模块：

```text
OLS
  ↓
Residual Variance
  ↓
T Critical Value
  ↓
Confidence Interval
  ↓
Prediction Interval
```

这比把所有数学写在 `OnCalculate()` 里更可维护。

### 2. Confidence vs Prediction

两个区间的含义不同：

- CI：估计均值趋势线的不确定性；
- PI：单个未来/边缘观测值的不确定性。

交易系统通常更关心 PI，因为价格是单个观测，不是趋势均值本身。

### 3. Leverage-Aware Band

区间宽度随 `x` 位置变化，中心更窄，边缘更宽。它不是固定标准差通道。

这适合做：

- trend uncertainty feature；
- forecast interval；
- channel breach diagnostics；
- residual regime feature。

### 4. Evaluation Mode

主指标支持：

```text
EVAL_CURRENT_EDGE  # x = n - 1
EVAL_NEXT_BAR      # x = n
```

这点很重要：边缘描述与下一根预测不能混用。

## 平台迁移建议

```text
RegressionChannelEngine
├── fit_window()
├── residual_stats()
├── confidence_band()
├── prediction_band()
├── coverage_test()
└── channel_features()
```

可作为 Python 研究侧特征：

```text
reg_slope
reg_r2 / residual_std
pi_width
ci_width
price_z_to_pi
breach_pi_upper
breach_pi_lower
coverage_error
```

## 局限

- 当前实现每根 bar 全窗口重算，复杂度 `O(N * window)`；
- 金融价格常违反 OLS 假设；
- nominal 95% 不等于真实覆盖率；
- 应增加 out-of-sample coverage test；
- 后续可替换为 Newey-West / HC3 / GARCH-adjusted variance。
