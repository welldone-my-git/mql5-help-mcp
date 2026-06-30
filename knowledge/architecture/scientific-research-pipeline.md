# Scientific Research Pipeline：从交易想法到可验证模型

来源：

- Maxim Romanov: https://www.mql5.com/en/users/223231/publications
- `A scientific approach to the development of trading algorithms`: https://www.mql5.com/en/articles/8231
- `Price series discretization, random component and noise`: https://www.mql5.com/en/articles/8136
- `What is a trend and is the market structure based on trend or flat?`: https://www.mql5.com/en/articles/8184
- `Self-adapting algorithm` series: https://www.mql5.com/en/articles/8616

## 目标

把策略开发从：

```text
Indicator
    ↓
Buy / Sell
    ↓
Backtest Profit
```

升级为：

```text
Observation
    ↓
Hypothesis
    ↓
Sampling
    ↓
Feature / Label
    ↓
Statistical Test
    ↓
Model
    ↓
Walk-forward
    ↓
Replay / Paper / Live
```

这层是 Research Platform 的根。

## 平台职责划分

| 模块 | 职责 | 不做什么 |
|---|---|---|
| Observation | 记录市场现象 | 不直接交易 |
| Hypothesis | 把现象转成可检验命题 | 不用模糊描述 |
| Sampling | 定义时间/价格/成交采样 | 不默认 time bar 是唯一真相 |
| Feature | 生成可测输入 | 不混入未来数据 |
| Label | 生成研究目标 | 不事后偷看 |
| Statistical Test | 验证显著性和稳定性 | 不只看净利润 |
| Model | 输出概率/置信度 | 不直接下单 |
| Walk-forward | 检查时间稳定性 | 不只做一次 train/test |
| Replay/Paper/Live | 验证执行链路 | 不改变研究定义 |

## 推荐目录

```text
research/
├── observations/
├── hypotheses/
├── sampling/
├── features/
├── labels/
├── tests/
├── models/
├── regime/
├── adaptation/
└── reports/
```

## Hypothesis 对象

每个研究想法应该被结构化：

```python
@dataclass
class Hypothesis:
    hypothesis_id: str
    name: str
    description: str
    universe: list[str]
    sampling: str
    feature_set: str
    label: str
    expected_effect: str
    invalidation_rule: str
    metadata: dict
```

示例：

```text
不是：趋势线突破有效。

而是：
在 London Session，若价格突破 Asia Range High 后 20 根 M5 内未回落到区间内，
则未来 N 根 bar 的上行收益分布相对无突破样本有正偏。
```

## Sampling Engine

Romanov 的 discretization 文章对平台最大的提醒是：

```text
Sampling is a modeling choice.
```

因此平台需要明确采样层：

```text
Tick
    ↓
SamplingEngine
    ├── TimeBar
    ├── TickBar
    ├── VolumeBar
    ├── RangeBar
    ├── SessionBar
    └── EventBar
```

Feature 和 Label 必须绑定采样方式：

```text
feature = f(sampled_series, sampling_config)
label   = g(sampled_series, sampling_config)
```

## Regime / State 层

Trend / Flat 不应该由单个指标硬编码。

建议统一成：

```python
@dataclass
class RegimeState:
    symbol: str
    timestamp: datetime
    state_id: str
    trend_probability: float
    mean_reversion_probability: float
    volatility_state: str
    scale: float
    confidence: float
    metadata: dict
```

用途：

```text
SignalEvent.regime
RiskEvent.regime_filter
ParameterPolicy.regime_config
```

## Adaptive Parameter Policy

“Abandoning optimization”的平台级解释：

```text
Parameter selection should be state-dependent.
```

不要只有：

```text
best_ma = 20
best_atr = 14
```

而应该有：

```python
class ParameterPolicy:
    def resolve(self, regime: RegimeState, symbol: str) -> StrategyParams:
        ...
```

例如：

```text
low_vol_range  -> shorter target, tighter stop, mean-reversion enabled
high_vol_trend -> wider target, volatility throttle, trend-follow enabled
news_window    -> no new position / reduce size
```

## Validation Gates

任何研究对象进入 Paper / Live 前至少经过：

```text
1. In-sample hypothesis sanity check
2. Out-of-sample validation
3. Walk-forward stability
4. Regime split performance
5. Transaction cost sensitivity
6. Slippage / spread stress
7. Replay execution audit
```

这些 gate 应该成为 CI / Research Report 的一部分。

## 与 Event-Driven 平台连接

研究层最终只输出：

```text
SignalEvent
DecisionEvent
FeatureSnapshot
ModelOutput
RegimeState
```

不会直接调用 broker。

```text
Research
    ↓
SignalEvent
    ↓
RiskEngine
    ↓
OrderManager
    ↓
BrokerAdapter
```

## 反模式

避免：

- 先写 EA，再找理由解释收益。
- 用一次优化结果代表规律。
- 把 time bar 当成唯一市场表示。
- 把 trend / flat 写成不可验证的主观描述。
- ML 模型直接下单，绕过 RiskEngine。
- 只看净利润，不看显著性、稳定性和成本敏感性。

## MVP 中的最小落地

第一版不需要复杂统计库，但要保留接口：

```text
research/sampling/
research/features/
research/labels/
research/regime/
research/tests/
```

最小闭环：

```text
BarEvent
    ↓
FeatureEngine
    ↓
MockRegimeEngine
    ↓
MockModel
    ↓
SignalEvent
```

后续再把 Romanov 的 block/range sampling、trend-flat probability、adaptive parameter policy 接入。

