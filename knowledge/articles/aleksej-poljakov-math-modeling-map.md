# Aleksej Poljakov：数学建模与 Forecast SDK 路线图

作者主页：

- https://www.mql5.com/en/users/aleksej1966/publications

## 总体定位

Aleksej Poljakov 不是典型 EA 策略作者，而是数学建模型作者。

他的高价值内容集中在：

```text
Time Series Modeling
Forecasting
Trend Definition
Signal Processing
Numerical Methods
Mathematical Tooling
```

这类内容最适合沉淀到 Python Research SDK，而不是直接归入交易策略库。

## 推荐优先级

| 文章 / 主题 | 推荐 | 对应平台模块 |
|---|---:|---|
| Forecasting in Trading Using Grey Models | S+ | ForecastEngine / GreyModel |
| Application of the Grey Model in Technical Analysis of Financial Time Series | S | GreyModel 基础实现 |
| Polynomial Models in Trading | S | PolynomialForecast / CurveFitting |
| Price Movement: Mathematical Models and Technical Analysis | S | Mathematical Modeling Foundation |
| Trend Criteria. Conclusion | A | TrendEngine / Regime |
| Triangular and Sawtooth Waves | A | Signal Processing / Feature Extraction |
| Century-old functions in trading strategies | A | MathToolkit / Special Functions |

## 为什么值得整套收藏

当前平台的 Research Layer 不能只包含 ML 模型。还需要一组轻量、可解释、可作为 baseline 的数学预测器：

```text
ForecastEngine
├── GreyModel
├── PolynomialModel
├── LinearRegression
├── KalmanFilter
├── ARIMA
├── Prophet
├── N-BEATS
├── DeepAR
└── Transformer
```

Grey Model、Polynomial Model、Trend Criteria 这类文章可以补齐传统数学建模层。

## S 级：Grey Model 系列

### 1. Application of the Grey Model in Technical Analysis of Financial Time Series

链接：

- https://www.mql5.com/en/articles/18553

定位：

```text
Grey Model 入门与 GM(1,1) 基础实现。
```

收藏点：

- AGO：Accumulated Generating Operation；
- IAGO：Inverse AGO；
- GM(1,1) 参数估计；
- 小样本预测；
- 不强依赖平稳性；
- 可作为传统预测 baseline。

### 2. Forecasting in Trading Using Grey Models

链接：

- https://www.mql5.com/en/articles/19012

定位：

```text
Grey Model 家族与工程实现合集。
```

收藏点：

- GM(1,1)；
- Rolling GM；
- Adaptive GM；
- GM + SMA；
- Grey Trend Channel；
- Discrete GM；
- DGM11 / DGM02 / DGM12 / DGM21；
- 多模型 ensemble 与动态权重思想。

## S 级：Polynomial Models

建议作为 ForecastEngine 的另一个插件：

```text
PolynomialForecast
├── fit(window)
├── predict(horizon)
├── confidence_band()
└── curvature_feature()
```

用途：

- 曲线拟合 baseline；
- 局部趋势斜率；
- 曲率/加速度特征；
- 通道和预测区间。

不建议把高阶多项式预测直接当策略信号。它更适合做 feature / baseline / sanity check。

## A 级：Trend Criteria

这类文章适合进入 `TrendEngine`：

```text
TrendEngine
├── slope
├── persistence
├── range expansion
├── direction consistency
├── reversal probability
└── confidence
```

趋势不应该只等于：

```text
MA fast > MA slow
```

而应该是可测的状态和概率。

## A 级：Signal Processing / Math Toolkit

三角波、锯齿波、特殊函数这类内容不一定直接产生 alpha，但适合沉淀为研究工具箱：

```text
MathToolkit
├── smoothing
├── basis_functions
├── wave_shapes
├── special_functions
├── curve_fitting
└── numerical_solvers
```

它们可以服务：

- feature extraction；
- detrending；
- regime shape detection；
- cycle / waveform approximation；
- synthetic market stress test。

## 对平台的落地建议

新增 Research SDK 方向：

```text
research/
├── forecasting/
│   ├── base.py
│   ├── grey_model.py
│   ├── polynomial.py
│   ├── kalman.py
│   └── ensemble.py
├── trend/
│   ├── criteria.py
│   └── trend_state.py
└── math/
    ├── ago.py
    ├── curve_fit.py
    └── special_functions.py
```

统一接口：

```python
class BaseForecaster:
    def fit(self, series): ...
    def predict(self, horizon: int): ...
    def update(self, value): ...
```

## 不建议收藏的方式

避免：

- 把 Grey Model 当成一个买卖指标；
- 只看预测线，不做误差分布；
- 不和 ARIMA / Linear / Naive baseline 比较；
- 用单市场样本证明模型有效；
- 忽略 forecast horizon 与交易周期的关系。

## 结论

这个作者应归入：

```text
Research SDK / Mathematical Modeling / ForecastEngine
```

而不是：

```text
EA Strategy Collection
```

