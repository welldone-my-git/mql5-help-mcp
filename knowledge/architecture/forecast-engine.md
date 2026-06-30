# Forecast Engine：Research SDK 的统一预测器层

来源：

- Aleksej Poljakov Grey Model 系列：https://www.mql5.com/en/users/aleksej1966/publications
- [Grey Model Forecast Engine](../articles/grey-model-forecast-engine-poljakov.md)
- ARIMA / Prophet / N-BEATS / DeepAR / Transformer 已收录文章

## 目标

平台需要一个统一的预测器接口，而不是每个模型单独散落在策略里。

```text
Market Series / Feature Series
    ↓
ForecastEngine
    ↓
ForecastResult
    ↓
SignalEngine / MetaLabel / Regime
```

## 为什么需要这一层

不同预测模型的输入、训练、输出差异很大：

- Grey Model；
- Polynomial Model；
- Linear Regression；
- Kalman Filter；
- ARIMA；
- Prophet；
- DeepAR；
- N-BEATS；
- Transformer。

但平台消费它们时只需要统一结果：

```text
future estimate
uncertainty
forecast error
model confidence
metadata
```

## 统一接口

```python
class BaseForecaster:
    name: str

    def fit(self, series, **kwargs):
        ...

    def update(self, value, **kwargs):
        ...

    def predict(self, horizon: int):
        ...
```

统一结果：

```python
@dataclass
class ForecastResult:
    timestamp: datetime
    symbol: str
    model_name: str
    horizon: int
    y_hat: list[float]
    lower: list[float] | None
    upper: list[float] | None
    error_estimate: float | None
    confidence: float | None
    metadata: dict
```

## 推荐目录

```text
research/
├── forecasting/
│   ├── base.py
│   ├── result.py
│   ├── grey/
│   │   ├── ago.py
│   │   ├── gm11.py
│   │   ├── rolling_gm.py
│   │   ├── adaptive_gm.py
│   │   └── discrete_gm.py
│   ├── polynomial.py
│   ├── linear.py
│   ├── kalman.py
│   ├── arima.py
│   ├── prophet.py
│   ├── neural/
│   └── ensemble.py
```

## Forecast 不是 Signal

严格分层：

```text
ForecastEngine  -> 预测
SignalEngine    -> 决策候选
MetaLabel       -> 过滤 / sizing
RiskEngine      -> 是否允许交易
OrderManager    -> 下单
```

预测器不能直接下单。

## Forecast Feature

预测结果本身也可以成为特征：

```text
forecast_slope
forecast_return
forecast_error
forecast_dispersion
forecast_confidence
distance_to_forecast_mid
forecast_interval_width
```

这些适合喂给：

- Meta Labeling；
- Regime Detection；
- Position Sizing；
- Risk Throttle。

## Ensemble / Weight Engine

Poljakov 的 Rolling / Adaptive GM 可以推广为通用 ensemble：

```text
ForecastEnsemble
├── model list
├── weight engine
├── error tracker
├── regime-conditioned weights
└── aggregate forecast
```

权重方式：

- inverse recent error；
- exponential decay；
- walk-forward score；
- regime-specific score；
- Bayesian model averaging。

## 验证标准

每个 forecaster 至少输出：

```text
MAE
RMSE
Directional Accuracy
Forecast Bias
Interval Coverage
Walk-forward Stability
Cost-adjusted Signal Value
```

不通过 baseline 的预测器不能进入 SignalEngine。

## MVP 范围

第一版只需要：

```text
BaseForecaster
ForecastResult
NaiveForecaster
LinearForecaster
GreyModel stub / prototype
walk-forward evaluator
```

GreyModel 可先作为研究插件，不进入 live execution。

