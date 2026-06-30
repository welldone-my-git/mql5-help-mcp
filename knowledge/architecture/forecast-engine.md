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

- 第一代数学解析模型；
- 第二代统计学习模型；
- 第三代机器学习模型；
- 第四代深度学习模型。

但平台消费它们时只需要统一结果：

```text
future estimate
uncertainty
forecast error
model confidence
metadata
```

## 四代预测模型分类

ForecastEngine 按四代模型组织。

```text
第一代：数学解析 / 可解释基线
    ↓
Linear
Polynomial
Grey Model
Kalman
Fourier
Wavelet

第二代：统计学习 / 随机过程
    ↓
AR
MA
ARMA
ARIMA
SARIMA
GARCH
State Space

第三代：机器学习 / 表格特征模型
    ↓
Random Forest
SVM
XGBoost
LightGBM
CatBoost

第四代：深度学习 / 序列表示学习
    ↓
LSTM
GRU
Transformer
TCN
N-BEATS
TimeMixer
```

### 第一代：数学解析

用途：

- 可解释 baseline；
- 小样本建模；
- smoothing / detrending；
- forecast feature；
- sanity check。

典型模型：

```text
Linear
Polynomial
Grey Model
Kalman
Fourier
Wavelet
```

这一层不追求最强预测能力，追求可解释、低依赖、低成本。

### 第二代：统计学习

用途：

- 时间序列 baseline；
- 自相关 / 季节性 / 波动建模；
- 预测区间；
- volatility forecast。

典型模型：

```text
AR
MA
ARMA
ARIMA
SARIMA
GARCH
State Space
```

这一层是判断深度模型是否真的有增量价值的基准。

### 第三代：机器学习

用途：

- 表格特征建模；
- 非线性关系；
- 因子组合；
- meta labeling；
- probability output。

典型模型：

```text
Random Forest
SVM
XGBoost
LightGBM
CatBoost
```

这一层最适合结合 AFML FeatureEngine 和 Meta Labeling。

### 第四代：深度学习

用途：

- 多变量序列建模；
- 长依赖建模；
- representation learning；
- cross-asset / multi-horizon forecasting。

典型模型：

```text
LSTM
GRU
Transformer
TCN
N-BEATS
TimeMixer
```

这一层必须严格通过 walk-forward、CPCV、成本压力测试，否则容易只是高复杂度拟合。

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
│   ├── classical/
│   │   ├── linear.py
│   │   ├── polynomial.py
│   │   ├── kalman.py
│   │   ├── fourier.py
│   │   ├── wavelet.py
│   │   └── grey/
│   │       ├── ago.py
│   │       ├── gm11.py
│   │       ├── rolling_gm.py
│   │       ├── adaptive_gm.py
│   │       └── discrete_gm.py
│   ├── statistical/
│   │   ├── arima.py
│   │   ├── sarima.py
│   │   ├── garch.py
│   │   └── state_space.py
│   ├── ml/
│   │   ├── random_forest.py
│   │   ├── svm.py
│   │   ├── xgboost.py
│   │   ├── lightgbm.py
│   │   └── catboost.py
│   ├── deep/
│   │   ├── lstm.py
│   │   ├── gru.py
│   │   ├── transformer.py
│   │   ├── tcn.py
│   │   ├── nbeats.py
│   │   └── timemixer.py
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
