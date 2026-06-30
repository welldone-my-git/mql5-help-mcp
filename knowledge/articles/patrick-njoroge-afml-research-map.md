# Patrick Murimi Njoroge：AFML / Feature Engineering 研究路线图

作者主页：

- https://www.mql5.com/en/users/patricknjoroge743/publications

## 总体定位

Patrick Murimi Njoroge 是当前 MQL5 社区里少数系统性围绕 AFML（Advances in Financial Machine Learning）做工程化拆解的作者。

他的高价值内容不是单个 EA，而是：

```text
Feature Engineering
    ↓
Alternative Bars
    ↓
Sequential Bootstrap / CPCV
    ↓
Meta Labeling
    ↓
Bet Sizing
    ↓
MQL5 Live Feature Parity
```

这和当前平台路线高度一致：

```text
Python Research
    ↓
Feature Store
    ↓
Model / Meta Label
    ↓
MQL5 / MT5 Execution
```

## 优先级

| 系列 / 主题 | 推荐 | 对应平台模块 |
|---|---:|---|
| Feature Engineering for ML Part 1–7 | S | FeatureEngine |
| Microstructural Features in Python | S+ | Microstructure Feature Pipeline |
| Microstructural Features in MQL5 | S+ | MT5 Real-time Feature Parity |
| Entropy Features | S | State Representation / Regime |
| MetaTrader 5 Machine Learning Blueprint | S | AFML Research Pipeline |
| Sequential Bootstrap | S | Sampling / Sample Weighting |
| CPCV / Purged CV | S | Research Validation |
| Meta-Labeling the Classics | S | Primary + Meta Model |
| Beyond the Clock / Alternative Bars | A | DataEngine / Sampling |
| Calendar / Session Features | A | CalendarEngine / SessionEngine |

## 已收录核心文章

| 条目 | 本库文档 |
|---|---|
| Feature Engineering Part 5：Microstructural Features in Python | [afml-microstructure-feature-pipeline-python.md](./afml-microstructure-feature-pipeline-python.md) |
| Feature Engineering Part 6：Microstructural Features in MQL5 | [afml-microstructure-features-mql5.md](./afml-microstructure-features-mql5.md) |
| Meta-Labeling RSI | [meta-labeling-rsi-primary-meta-bet-sizing.md](./meta-labeling-rsi-primary-meta-bet-sizing.md) |
| Meta-Labeling ADX | [meta-labeling-adx-hpo-gate-bet-sizing.md](./meta-labeling-adx-hpo-gate-bet-sizing.md) |

## Feature Engineering 系列

推荐按模块而不是按文章编号吸收。

### 1. Price Geometry Features

适合进入：

```text
FeatureEngine.Geometry
```

典型特征：

- candle body；
- upper shadow；
- lower shadow；
- body ratio；
- wick ratio；
- range position。

这类特征是低成本、强可解释的基础 feature。

### 2. Price Action / Structure Features

适合进入：

```text
FeatureEngine.Structure
```

典型对象：

- swing；
- breakout；
- range；
- trend；
- local structure。

它和 LynnChris 的 Geometry / Pattern Event 系列可以合并成统一的 `MarketStructureFeature`。

### 3. Calendar Features

适合进入：

```text
FeatureEngine.Calendar
CalendarEngine
```

典型特征：

- hour；
- day of week；
- month；
- session；
- holiday proximity；
- news distance。

注意：Calendar feature 不应只做 one-hot；应支持 cyclic encoding：

```text
sin(hour)
cos(hour)
sin(weekday)
cos(weekday)
```

### 4. Session Features

适合进入：

```text
FeatureEngine.Session
SessionRangeEngine
```

典型特征：

- Asia / London / NY；
- session overlap；
- session range；
- distance to session high / low；
- breakout after session close。

可和 `Session Boxes`、`Opening Range Breakout` 合并。

### 5–6. Microstructure Features

已单独收录。它们是整个系列最重要的部分。

Python 层：

```text
Roll Spread
Corwin-Schultz Spread
Kyle Lambda
Amihud Illiquidity
Hasbrouck Lambda
VPIN
Imbalance
```

MQL5 层：

```text
实时 bar-level microstructure features
```

平台意义：

```text
Research Feature
    ↔
Live Feature
```

同一个特征定义应能在 Python 和 MQL5 两端一致复现。

### 7. Entropy Features

适合进入：

```text
FeatureEngine.Entropy
RegimeEngine
```

典型特征：

- Shannon entropy；
- plug-in entropy；
- Lempel-Ziv complexity；
- Kontoyiannis entropy。

用法：

```text
low entropy  -> structured / persistent
high entropy -> noisy / random / unstable
```

Entropy 不建议单独作为交易信号，更适合作为 regime / confidence / risk throttle。

## MetaTrader 5 Machine Learning Blueprint

最值得收藏的是研究流程，而不是某个模型：

```text
Label
    ↓
Sample Weight
    ↓
Sequential Bootstrap
    ↓
Purged / Embargo CV
    ↓
CPCV
    ↓
Model
    ↓
Probability
    ↓
Bet Sizing
```

这应成为 Research Pipeline 的验证基准。

## Meta Labeling 系列

核心模式：

```text
Primary Model
    ↓
Candidate Signal
    ↓
Meta Features
    ↓
Meta Model
    ↓
Probability
    ↓
Bet Size
```

重点不是 RSI / ADX，而是：

- primary signal 和 meta model 分离；
- feature 围绕 signal context 构建；
- 输出 probability，不是直接 buy/sell；
- bet sizing 由 probability 驱动。

## Alternative Bars

适合进入：

```text
DataEngine.Sampling
```

包括：

- tick bars；
- volume bars；
- dollar bars；
- imbalance bars；
- run bars；
- range bars。

这是对 Romanov `discretization` 思想的工程化补充。

## 建议沉淀的模块

```text
research/
├── features/
│   ├── geometry.py
│   ├── calendar.py
│   ├── session.py
│   ├── microstructure.py
│   └── entropy.py
├── sampling/
│   ├── alternative_bars.py
│   ├── imbalance_bars.py
│   └── run_bars.py
├── validation/
│   ├── purged_cv.py
│   ├── cpcv.py
│   └── embargo.py
├── sampling_weights/
│   ├── uniqueness.py
│   └── sequential_bootstrap.py
└── meta_labeling/
    ├── primary_signal.py
    ├── meta_features.py
    └── bet_sizing.py
```

## 结论

Patrick 的文章应该作为当前平台 Research Layer 的 AFML 主线。

优先级高于普通策略文章，因为它回答的是：

```text
How to build machine-learning-ready market data.
How to validate it without leakage.
How to turn model probability into position size.
```

