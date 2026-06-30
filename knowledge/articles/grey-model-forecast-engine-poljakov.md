# Forecasting in Trading Using Grey Models：Grey Model Forecast Engine

来源：

- Forecasting in Trading Using Grey Models: https://www.mql5.com/en/articles/19012
- Application of the Grey Model in Technical Analysis of Financial Time Series: https://www.mql5.com/en/articles/18553
- 作者主页：https://www.mql5.com/en/users/aleksej1966/publications

## 总体评价

这篇文章不是普通预测指标，而是一套 Grey Model 家族工程实现。

平台价值：

| 维度 | 评分 |
|---|---:|
| 数学价值 | ★★★★★ |
| 可复用性 | ★★★★★ |
| Python 迁移价值 | ★★★★★ |
| 适合作为 SDK | ★★★★★ |
| 直接交易价值 | ★★☆☆☆ |

建议归类：

```text
Research Layer / ForecastEngine / GreyModel
```

## 核心流程

Grey Model 的基本流程：

```text
Original Series
    ↓
AGO
    ↓
Grey Series
    ↓
Parameter Estimation
    ↓
Forecast
    ↓
IAGO
    ↓
Recovered Forecast
```

关键价值：

- 小样本可用；
- 不像 ARIMA 那样强依赖平稳序列；
- 可解释；
- 可作为传统 forecast baseline；
- 可扩展成 ensemble 和 adaptive model。

## 必收藏模块

### 1. AGO / IAGO

```text
AGO  = Accumulated Generating Operation
IAGO = Inverse Accumulated Generating Operation
```

建议沉淀为工具函数：

```python
def ago(x): ...
def iago(x_acc): ...
```

所有 GM 变体都会用到。

### 2. GM(1,1)

经典灰色模型：

```text
series
    ↓
AGO
    ↓
estimate a, b
    ↓
forecast accumulated series
    ↓
IAGO
```

建议实现为：

```python
class GM11(BaseForecaster):
    def fit(self, series): ...
    def predict(self, horizon): ...
```

### 3. Rolling GM

文章中多个窗口长度共同预测：

```text
GM(4)
GM(5)
...
GM(24)
    ↓
Average / Aggregate
```

平台化后就是 ensemble：

```python
class RollingGreyEnsemble:
    def __init__(self, windows): ...
    def predict(self, horizon): ...
```

用途：

- 降低单一窗口敏感性；
- 观察不同尺度预测是否一致；
- 输出 forecast dispersion 作为不确定性。

### 4. Adaptive GM

根据历史预测误差动态调整权重：

```text
lower error -> higher weight
higher error -> lower weight
```

这可以升级为统一的 WeightEngine：

```text
WeightEngine
├── inverse_error_weight
├── exponential_decay_error
├── bayesian_model_weight
├── regime_conditioned_weight
└── online_update
```

### 5. GM + SMA / Input Adapter

Grey Model 不应绑定 close price。

它可以预测：

```text
Close
SMA
EMA
Median Price
Typical Price
VWAP
Feature Series
```

因此需要 InputAdapter：

```python
ForecastTarget
├── close
├── sma
├── ema
├── median
├── typical
├── vwap
└── custom_feature
```

### 6. Grey Trend Channel

文章中通过 Grey Model 参数/预测构建趋势通道。

平台里应当输出：

```text
forecast_mid
forecast_upper
forecast_lower
forecast_slope
forecast_width
forecast_error
```

而不是只画线。

这些都可以变成 Feature：

```text
distance_to_grey_mid
distance_to_grey_upper
forecast_slope
forecast_width_pct
forecast_confidence
```

### 7. Discrete GM

这是最值得重点收藏的部分。

传统 GM 依赖微分方程解析解，程序实现时可能更复杂。Discrete GM 直接使用离散递推：

```text
X[t+1] = f(X[t], params)
```

对 Python / SDK 更友好，也更容易和：

- AR；
- Kalman；
- state-space model；
- recursive filter；
- online update；

统一。

文章涉及：

```text
DGM11
DGM02
DGM12
DGM21
```

建议整组作为 GreyModel 子模块。

## ForecastEngine 设计

```text
ForecastEngine
├── BaseForecaster
├── GreyModel
│   ├── GM11
│   ├── RollingGM
│   ├── AdaptiveGM
│   ├── DGM11
│   ├── DGM02
│   ├── DGM12
│   └── DGM21
├── PolynomialModel
├── LinearRegression
├── KalmanFilter
├── ARIMA
├── Prophet
├── DeepAR
└── Transformer
```

统一输出：

```python
@dataclass
class ForecastResult:
    horizon: int
    y_hat: list[float]
    lower: list[float] | None
    upper: list[float] | None
    error_estimate: float | None
    model_name: str
    metadata: dict
```

## 与平台事件模型连接

Grey Model 不直接下单。

推荐链路：

```text
BarEvent
    ↓
FeatureEngine
    ↓
ForecastEngine
    ↓
ForecastResult
    ↓
SignalEngine / MetaLabel
    ↓
SignalEvent
    ↓
RiskEngine
```

## 验证要求

必须和 baseline 比较：

```text
Naive last value
Moving average
Linear regression
ARIMA
Kalman
```

指标：

- MAE；
- RMSE；
- directional accuracy；
- calibration；
- forecast interval coverage；
- transaction-cost-adjusted signal value；
- walk-forward stability。

## 反模式

避免：

- 预测线看起来贴合就认为有 alpha；
- 不区分 in-sample 拟合和 out-of-sample 预测；
- 直接用预测方向开仓；
- 不保存 forecast error；
- 不做 forecast horizon 分析；
- 不和 naive baseline 比较。

## 结论

这篇文章应作为 ForecastEngine 的核心参考来源。

它的长期价值不是 Grey Model 本身，而是提供了一个可扩展预测器家族的组织方式：

```text
single model
rolling ensemble
adaptive weighting
input adapter
channel output
discrete recurrence
```

