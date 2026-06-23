# DA-CG-LSTM：动态特征注意力与时序注意力

## 来源

- 标题：Neural Networks in Trading: LSTM Optimization for Multivariate Time Series Forecasting (Final Part)
- 来源：https://www.mql5.com/en/articles/17939
- 作者：Dmitriy Gizlyk
- 发布日期：2026-06-19
- 分类：MetaTrader 5 / Trading systems
- 处理日期：2026-06-23

## 用户评审结论

这篇比 “Quantum NN” 那篇更值得学习，因为它至少来自一个明确的论文式框架：

```text
Dual Attention
+
CG-LSTM
→ Multivariate Time Series Forecasting
```

评价：

- 学习价值：★★★★☆
- 研究价值：★★★★☆
- 工程价值：★★★☆☆
- Alpha 价值：★★☆☆☆

核心判断：

```text
这篇教的是如何利用 Alpha，
不是如何发现 Alpha。
```

因此现阶段不建议急着复现完整 LSTM / Transformer 架构。更应该先验证已有因子是否有正 IC。

## 为什么比 Quantum NN 强

Quantum NN 条目的主要问题：

- 名词很多：Quantum、Resonance、Interference。
- 数学定义少。
- 实验验证少。
- Alpha 来源不清楚。

DA-CG-LSTM 的价值更清晰：

- 有明确结构：Dual Attention + CG-LSTM。
- 目标是多变量时间序列预测。
- 核心机制可解释为动态特征选择和动态历史窗口选择。
- 与用户当前的 `(State, Feature) -> Return` 研究范式一致。

## 核心模块

### 1. Feature Attention

第一层注意力回答：

```text
当前哪些特征重要？
```

例如：

- return
- volume
- volatility
- spread
- liquidity factor
- state factor
- market impact factor

关键思想：

```text
Feature importance is dynamic.
```

同一个因子在不同市场状态下有效性不同。静态 feature importance 不够，真正需要的是：

```text
State
↓
Feature Weight
↓
Return
```

这与用户当前研究高度一致：

- 异常成交额相关性
- Takens 状态
- Kyle Lambda
- Kalman Gain
- Markov state

这些都可以进入 feature set，由 attention 或更简单的模型决定当前权重。

### 2. Temporal Attention

第二层注意力回答：

```text
过去哪些历史时刻重要？
```

它不是固定窗口：

```text
MA20
RSI14
过去20天平均
```

而是：

```text
过去 N 个时间点
↓
动态寻找关键时刻
```

这对于金融时间序列有意义，因为有效信息不一定均匀分布在窗口里。异常成交、流动性真空、跳空、新闻冲击、波动突增等事件可能只发生在少数 bar 上。

### 3. CG-LSTM

CG-LSTM 可以理解为带额外控制机制的 recurrent block，用于：

- 管理长期记忆。
- 抑制噪声特征。
- 聚合多时间尺度信息。
- 让模型对长序列仍能保留有效状态。

对当前阶段而言，不需要马上复现 CG-LSTM。更重要的是吸收其建模顺序：

```text
先筛特征
再筛时间
再做记忆聚合
最后预测或决策
```

## 对用户当前框架的启发

用户已有环境：

- AkShare
- VectorBT
- Alphalens
- LightGBM
- XGBoost

当前更缺的是：

```text
有效 Feature
```

而不是：

```text
更复杂 Model
```

基本判断：

```text
如果原始因子 IC = 0.01，
复杂 Transformer 可能也只是 0.012。

如果原始因子 IC = 0.05，
普通 LightGBM 可能已经足够。
```

因此优先级应是：

1. 验证 Takens / Kyle Lambda / 异常成交额相关性是否有 IC。
2. 做状态分组下的 IC / RankIC / 分层回测。
3. 用 LightGBM / XGBoost 建立 baseline。
4. 如果 baseline 有稳定信息，再考虑 attention / LSTM / Transformer。

## 最值得抄的部分：Feature Attention Layer

不建议现阶段直接复现完整 DA-CG-LSTM。

最值得迁移的是：

```text
Feature Attention Layer
```

未来框架可以这样设计：

```text
features/
  momentum.py
  liquidity.py
  state.py
  volume_anomaly.py
  kyles_lambda.py
  kalman_gain.py

models/
  linear.py
  lightgbm.py
  xgboost.py
  attention.py
  lstm.py
  transformer.py
```

先输出统一特征矩阵：

```text
X = [momentum, liquidity, state, lambda, volume_anomaly, ...]
```

再计算：

```text
attention_weight_t = f(state_t, X_t)
```

目标不是炫模型，而是回答：

```text
当前状态下，哪些因子最重要？
```

## 推荐研究路径

### 阶段 1：传统因子验证

```text
factor
→ IC
→ RankIC
→ 分层回测
→ 状态分组
```

候选因子：

- Kyle Lambda
- Kalman Gain
- 异常成交额相关性
- Takens 状态特征
- Markov state transition probability

### 阶段 2：Baseline 模型

```text
features
→ LightGBM / XGBoost
→ OOS
→ walk-forward
→ feature importance
```

必须记录：

- 数据划分
- OOS 表现
- 交易成本
- 分状态表现
- rolling IC

### 阶段 3：轻量 Attention

如果 baseline 有正向结果，再加入：

```text
state-conditioned feature weighting
```

可以先不用深度学习，先做简单门控：

```text
weight_i,t = softmax(W * state_t)
score_t = sum(weight_i,t * factor_i,t)
```

### 阶段 4：LSTM / Transformer

只有当：

- 特征稳定有效；
- baseline 模型有清楚收益；
- 序列信息确实提升；
- 数据量足够；
- walk-forward 稳定；

才考虑完整 LSTM / Transformer / DA-CG-LSTM。

## 工程设计建议

### 模型目录预留

```text
models/
  linear.py
  lightgbm.py
  xgboost.py
  attention.py
  lstm.py
  transformer.py
```

但实现顺序建议：

```text
linear
→ lightgbm
→ xgboost
→ attention
→ lstm
→ transformer
```

### Attention 输出应可解释

如果未来实现 attention，必须输出：

- 每期 feature weight
- 每个状态下平均 feature weight
- 不同市场状态下权重变化
- 与收益贡献的对应关系

否则 attention 只会变成另一个黑箱。

### 避免模型堆叠污染研究

不要一开始就把：

```text
Takens
Kyle Lambda
Kalman Gain
Markov State
LSTM
Transformer
Risk Manager
Reinforcement Learning
```

全部堆在一起。

正确方式是逐层验证：

```text
baseline
+ feature group
+ state group
+ attention
+ temporal model
+ risk layer
```

每一层都要做 ablation。

## 与已有知识条目的关系

这篇和已有条目可以形成一条清晰研究线：

```text
kyles-lambda-market-impact-liquidity-factor.md
adaptive-kalman-smoother-regime-factor.md
qnn-markov-feature-pipeline-mql5.md
decorator-pattern-indicator-factor-pipeline.md
→ da-cg-lstm-dynamic-feature-attention.md
```

组合范式：

```text
Feature Pipeline
→ State Recognition
→ Dynamic Feature Weight
→ Return Prediction
```

其中：

- Kyle Lambda：流动性/价格冲击因子
- Kalman Gain：市场状态强度
- Markov State：状态转移结构
- Decorator Pipeline：因子处理工程框架
- DA-CG-LSTM：动态选择特征和历史时刻的模型思想

## 结论

这篇文章的核心价值不是 LSTM 本身，而是：

```text
Feature Selection 是动态的。
历史窗口的重要性也是动态的。
```

对当前阶段最务实的落地方式：

```text
先用 LightGBM / XGBoost 验证因子。
如果因子有效，再实现轻量 Feature Attention。
最后才考虑 LSTM / Transformer。
```

## 标签

- MQL5
- neural network
- DA-CG-LSTM
- dual attention
- feature attention
- temporal attention
- dynamic feature selection
- multivariate time series
- factor research
- state-dependent feature weight
- LightGBM baseline
- XGBoost baseline
- model architecture
