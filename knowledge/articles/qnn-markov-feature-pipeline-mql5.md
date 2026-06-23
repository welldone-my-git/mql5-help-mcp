# Quantum Neural Network in MQL5 Part II：Markov 状态建模与 Feature Pipeline

## 来源

- 标题：Quantum Neural Network in MQL5 (Part II): Training a Neural Network with Backpropagation on ALGLIB Markov Matrices
- 来源：https://www.mql5.com/en/articles/18785
- 作者：Yevgeniy Koshtenko
- 发布日期：2026-06-22
- 分类：MetaTrader 5 / Indicators
- 处理日期：2026-06-23

## 用户评审结论

这篇文章需要拆成两个视角看：

- 量化研究视角：★★☆☆☆
- 机器学习建模视角：★★★☆☆
- MQL5 工程实现视角：★★★★☆

总体判断：不要重点学习 “Quantum Neural Network” 这个包装。真正值得沉淀的是：

1. Markov 状态建模
2. Feature Pipeline
3. 状态 → 因子 → 收益的研究范式
4. 用纯 MQL5 拼出复杂模型管线的工程组织方式

## 量化研究问题

文章声称模型优于 LSTM / Transformer，并报告较高准确率、Sharpe 和较低回撤。但从严肃量化研究角度，证据不足。

缺失关键验证：

- 数据集划分细节
- Walk Forward
- Out-of-sample 测试
- IC / RankIC
- 分层回测
- 滚动窗口验证
- Feature importance
- Benchmark 和 ablation study

因此无法判断所谓预测能力是否来自真实 alpha，还是来自过拟合、数据泄露、样本选择或参数堆叠。

## Quantum 叙事的处理方式

文章使用：

- Superposition
- Interference
- Decoherence
- Resonance

但这里更像量子力学启发的经典非线性网络，并不是真正的量子计算。

不应把它等同于：

- Quantum Circuit
- QAOA
- Variational Quantum Network
- 真实量子硬件或量子模拟器

工程上可重新解释为：

```text
Superposition  -> 多状态/多特征同时表达
Interference   -> 特征交互或 attention-like interaction
Decoherence    -> 记忆衰减 / 时间衰减权重
Resonance      -> 上下文匹配时的信号放大
```

结论：保留这些机制背后的建模思想，不保留 quantum marketing。

## 值得学习的研究结构

### 1. Markov State Encoding

文章把市场状态离散化，例如：

- strong rise
- weak rise
- flat
- weak fall
- strong fall

然后构造状态转移关系。

这比直接把所有 feature 扔进模型更有结构：

```text
market data
→ state classification
→ transition matrix
→ next-state / return expectation
```

这与用户当前研究方向一致：

```text
(state, feature) -> future return
```

例如：

```text
异常成交额相关性
不是单独看 volume anomaly
而是在特定 state 下看它是否预测 return
```

### 2. Multi-Level Context

文章核心可迁移结构：

```text
Feature
  ↓
State
  ↓
Memory
  ↓
Prediction
```

这比直接：

```text
XGBoost(features) -> return
```

更符合市场现实。同一个因子可能：

- 牛市有效
- 熊市失效
- 高波动有效
- 低波动失效
- 高流动性有效
- 低流动性失真

因此更重要的是建立：

```text
state-dependent factor research
```

### 3. 类别不平衡处理

文章提到对上涨、下跌、震荡类别做动态权重。这一点有实际价值。

在金融数据中：

- 中性/小波动样本常常最多
- 强趋势/极端波动样本较少
- 模型容易学成“永远预测中性”

可迁移到 Python 或 MQL5：

```text
class_weight_i = total_samples / (num_classes * class_count_i)
```

但需要注意：类别权重会改变优化目标，应在 OOS 和分层回测里单独验证。

## MQL5 工程价值

文章从工程角度最值得看，因为它尝试在纯 MQL5 中组织完整模型管线：

```text
400+ feature pipeline
→ Markov matrix
→ transformer / attention-like layer
→ state-space memory
→ risk manager
→ EA / signal output
```

### Feature Pipeline

文章整合了多类特征：

- OHLC
- Volume
- RSI
- MA
- Stochastic
- Candlestick Pattern
- Time Feature
- Cycle Feature

这相当于 MQL5 版的 `sklearn Pipeline`。

可迁移到用户 Python quant 框架：

```text
features/
  price.py
  volume.py
  momentum.py
  volatility.py
  pattern.py
  cycle.py
  calendar.py

states/
  markov.py
  regime.py
  transition.py

research/
  state_feature_return.py
  ic_by_state.py
  rankic_by_state.py
  layered_backtest.py
```

### Markov Matrix / Regime Switching

如果未来要做：

- 市场状态机
- HMM
- Regime Switching
- 状态转移概率
- 状态条件下的因子有效性

文章的 Markov matrix 结构可以作为工程参考。

研究上更推荐先做简单可解释版本：

```text
state_t = classify(price_return, volatility, volume_state)
transition_prob = P(state_t+1 | state_t)
factor_ic_by_state = IC(factor_t, return_t+1 | state_t)
```

### Online Retraining

文章提到周期性重新训练机制。工程结构值得学，但研究上必须谨慎：

- 重新训练窗口如何选？
- 是否引入未来函数？
- 参数选择是否泄漏 OOS？
- 是否在交易成本后仍稳定？
- 是否有 walk-forward 记录？

建议把 online retraining 作为工程机制，而不是默认提升收益的假设。

## 对用户当前研究的优先级

### 值得学

1. Markov 状态建模

优先级最高。适合和异常成交额相关性、流动性状态、Kalman Gain 等状态因子组合。

2. Feature Pipeline

适合迁移到 Python quant 框架，把 feature 生产标准化。

3. 状态 → 因子 → 收益

这是当前最应该强化的研究范式。不要直接卷模型复杂度，先把状态条件下的因子有效性做扎实。

### 不值得学

Quantum 部分可以忽略。将其视作经典非线性变换、attention、记忆衰减和状态机的重命名。

## 推荐落地任务

### 1. 状态条件 IC 分析

建立研究模板：

```text
for state in states:
  compute IC(factor, future_return | state)
  compute RankIC(factor, future_return | state)
  compute layered returns by factor quantile
```

### 2. Markov 状态转移表

最小实现：

```text
states = classify_market(price_return, volatility, volume_ratio)
transition_matrix = count_transition(states) / row_sum
```

输出：

- 状态分布
- 转移矩阵
- 状态持续时间
- 状态下未来收益均值/分位数

### 3. Feature Pipeline 规范

不要先做复杂 QNN。先建立可测试 feature pipeline：

```text
raw bars
→ feature table
→ state labels
→ target future returns
→ IC / RankIC / layered backtest
```

### 4. Ablation Study

如果未来重现文章结构，必须做模块消融：

```text
baseline features
+ Markov state
+ memory decay
+ attention
+ risk manager
```

每加一层都要证明独立贡献。

## 后续示例候选

1. `knowledge/patterns/state-dependent-factor-research.md`

沉淀：

- state classification
- IC by state
- RankIC by state
- layered backtest by state
- Markov transition diagnostics

2. `examples/research/markov-state-factor-template/`

Python 研究模板：

- 输入 OHLCV
- 输出 state labels
- 输出 transition matrix
- 输出 factor IC by state

3. `examples/mql5/feature-pipeline-skeleton/`

MQL5 工程模板：

- price features
- volume features
- indicator features
- time features
- state classifier
- feature vector export

## 标签

- MQL5
- machine learning
- Markov chain
- market state
- regime switching
- feature pipeline
- ALGLIB
- transformer
- state-space model
- online retraining
- class imbalance
- factor research
- state-dependent IC
