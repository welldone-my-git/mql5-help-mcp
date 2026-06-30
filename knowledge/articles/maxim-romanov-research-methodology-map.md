# Maxim Romanov：市场规律研究方法论路线图

作者主页：

- https://www.mql5.com/en/users/223231/publications

## 总体定位

Maxim Romanov 的核心价值不在 EA 模板，也不在某个可直接交易的策略，而在于市场规律研究方法：

```text
Market Observation
    ↓
Discretization / State Definition
    ↓
Hypothesis
    ↓
Statistical Verification
    ↓
Adaptive Rule
    ↓
Trading System
```

这组文章适合放入 Research Layer，而不是 Strategy Library。

对当前平台的价值：

| 方向 | 价值 |
|---|---:|
| Research Methodology | ★★★★★ |
| Market Structure / Regime | ★★★★★ |
| Discretization / Signal Processing | ★★★★★ |
| Adaptive Algorithm | ★★★★★ |
| 可直接交易价值 | ★★☆☆☆ |
| MQL5 工程复用 | ★★★☆☆ |

## 必收文章

| 文章 | 链接 | 推荐 | 知识归类 |
|---|---|---:|---|
| A scientific approach to the development of trading algorithms | https://www.mql5.com/en/articles/8231 | S+ | Research Methodology |
| Price series discretization, random component and noise | https://www.mql5.com/en/articles/8136 | S | Discretization / Noise |
| What is a trend and is the market structure based on trend or flat? | https://www.mql5.com/en/articles/8184 | S | Market Structure / Regime |
| Developing a self-adapting algorithm (Part I): Finding a basic pattern | https://www.mql5.com/en/articles/8616 | S | Pattern Discovery |
| Developing a self-adapting algorithm (Part II): Improving efficiency | https://www.mql5.com/en/articles/8767 | A+ | Adaptive Parameters |
| Self-adapting algorithm (Part III): Abandoning optimization | https://www.mql5.com/en/articles/8807 | S | Self Adaptation |
| Self-adapting algorithm (Part IV): Additional functionality and tests | https://www.mql5.com/en/articles/8859 | A | Multi-scale Engineering |

## 1. Scientific Approach

核心不是“找到指标”，而是建立研究闭环：

```text
Observation
    ↓
Hypothesis
    ↓
Measurement
    ↓
Statistical Test
    ↓
Rule
    ↓
Implementation
    ↓
Out-of-sample Validation
```

这是当前平台最应该继承的部分。

迁移到 Python Research Layer：

```text
research/
├── observations/
├── hypotheses/
├── features/
├── labels/
├── tests/
├── models/
└── reports/
```

要求：

- 每个策略想法必须先转成可检验假设。
- 每个假设必须有可复现实验。
- 每个实验必须输出统计指标，而不是只看净利润。
- 每个策略必须区分 in-sample、out-of-sample、walk-forward。

## 2. Price Series Discretization

这篇文章的长期价值是提醒：

```text
Time Bar is only one sampling method.
Sampling method changes the observable market.
```

可迁移结论：

- 时间 K 线会把交易活跃度差异混进价格序列。
- 噪声不只是市场本身，也可能来自采样方式。
- 研究趋势、波动率、形态前，必须先定义采样规则。

适合沉淀为：

```text
SamplingEngine
├── time_bar
├── tick_bar
├── volume_bar
├── range_bar
├── renko_like_block
└── event_bar
```

对 Feature Engine 的影响：

```text
Raw Tick
    ↓
Sampling Engine
    ↓
Bar / Block / Event Series
    ↓
Feature Engine
    ↓
Label Engine
```

## 3. Trend vs Flat

这篇的重点不是给趋势下一个文学定义，而是把 trend / flat 转成可测状态。

可迁移到 Regime：

```text
MarketState
├── trend_continuation_probability
├── reversal_probability
├── block_scale
├── dominant_direction
├── transition_state
└── confidence
```

平台里不应该写：

```text
MA fast > MA slow => Trend
```

而应该写：

```text
StateEncoder(features) -> RegimeProbability
```

这和 Markov / HMM / Meta Labeling / Regime Engine 是同一层。

## 4. Self-Adapting Algorithm Series

这一组文章的可收藏点不是持仓系列、补仓或具体交易规则，而是三个思想：

### 4.1 Basic Pattern

把市场先离散成 block，再统计上涨/下跌 block 的比例、偏离和条件概率。

可迁移为：

```text
State Encoder
    ↓
Rolling Count
    ↓
Pattern Balance
    ↓
Deviation Score
    ↓
Signal / Regime Feature
```

### 4.2 Improving Efficiency

重点是动态窗口、阈值和多尺度检查。

可迁移为：

```text
AdaptiveParameterEngine
├── dynamic_window
├── dynamic_threshold
├── scale_selection
└── confidence_filter
```

### 4.3 Abandoning Optimization

这是系列中最值得收藏的思想：

```text
Do not search one fixed parameter set.
Let the algorithm infer its working scale from the current market.
```

对应平台模块：

```text
RegimeEngine
    ↓
ParameterPolicy
    ↓
StrategyConfig
```

而不是：

```text
Optimizer
    ↓
Best Params
    ↓
Static EA
```

### 4.4 Additional Functionality and Tests

这篇开始进入多尺度 position series 和补偿逻辑。交易实现本身风险较高，不建议原样复用。

值得提炼：

- 多尺度状态同时存在。
- 一个大尺度 trend 内部可以有小尺度 flat / swing。
- 策略应该根据当前有效尺度调整行为。
- 附加模块必须用统计验证，而不是凭直觉叠加。

## 建议沉淀的模块

```text
research/
├── sampling/
│   ├── time_bar.py
│   ├── range_bar.py
│   └── block_series.py
├── regime/
│   ├── state_encoder.py
│   ├── trend_flat_detector.py
│   └── scale_detector.py
├── adaptation/
│   ├── parameter_policy.py
│   ├── adaptive_window.py
│   └── adaptive_threshold.py
└── validation/
    ├── hypothesis_test.py
    ├── out_of_sample.py
    └── walk_forward.py
```

## 不建议收藏的部分

- 具体 position series / averaging 交易规则。
- 用盈利图替代统计验证。
- 把“自适应”理解成无限加仓或补偿亏损。
- 将单一市场样本结论直接推广到所有市场。

## 最终结论

这组文章应作为 Research Layer 的方法论基础收藏。

它补齐的是平台里很关键的一层：

```text
How to turn market intuition into testable research objects.
```

不是：

```text
How to copy an EA.
```

