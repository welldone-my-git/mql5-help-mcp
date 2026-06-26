# Meta-Labeling the Classics Part 1：RSI 信号过滤与 Bet Sizing

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22274>
- Title: Meta-Labeling the Classics (Part 1): Filtering and Sizing RSI Trades
- Local source: [meta-labeling-rsi](../../examples/research/meta-labeling-rsi/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 架构设计 | ⭐⭐⭐⭐⭐ |
| Python 研究价值 | ⭐⭐⭐⭐⭐ |
| MQL5 / MT5 迁移价值 | ⭐⭐⭐⭐☆ |
| 策略本身 | ⭐⭐☆☆☆ |
| 可迁移到个人框架 | ⭐⭐⭐⭐⭐ |
| 收藏价值 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 文章价值不在 RSI，而在 Lopez de Prado 的 Meta Labeling：Primary Model 负责产生候选信号，Meta Model 负责过滤与仓位。

## 核心思想

普通策略：

```text
RSI
    ↓
Buy / Sell
    ↓
Trade
```

Meta Labeling：

```text
RSI
    ↓
Primary Signal
    ↓
Context Features
    ↓
Meta Label
    ↓
Meta Model Probability
    ↓
Trade / Skip
    ↓
Bet Size
```

这不是让机器学习直接预测市场方向。

它让机器学习回答更实用的问题：

```text
这个已有策略信号，现在是否值得执行？
```

## 为什么值得收藏

这篇比很多直接用 ML 预测涨跌的文章更有价值。

原因是它把问题拆成两层：

```text
Primary Model: where to trade
Meta Model: whether to trade and how much
```

这更接近可落地的量化系统。

任何已有策略都可以套上这层：

- RSI；
- MA Cross；
- MACD；
- Breakout；
- Order Flow；
- Mean Reversion；
- Microstructure Alpha；
- discretionary signal。

## 源码 Pipeline

附件中的 `rsi_meta_pipeline.py` 包含完整研究流程：

```text
load_data
    ↓
compute_features
    ↓
generate_rsi_signals
    ↓
triple_barrier_label
    ↓
train_meta_model
    ↓
predict probability
    ↓
backtest_three_tracks
```

这是非常标准的研究 pipeline。

## 1. Primary Signal

源码用 RSI 作为 primary model：

```text
RSI crosses above oversold → long candidate
RSI crosses below overbought → short candidate
```

注意：RSI 只是示例。

真正值得收藏的是 primary signal interface：

```text
Signal = {timestamp, side}
```

后续任何策略都可以产生这种候选信号。

## 2. Feature Engineering

源码没有只用 OHLC。

它构建了 signal context：

- RSI depth；
- RSI momentum；
- ADX；
- ATR；
- volatility ratio；
- momentum；
- EMA trend；
- distance to recent high / low；
- session flags；
- Fourier time features；
- session conditional volatility。

核心思想：

```text
不要让模型预测价格。
让模型判断当前 signal 的上下文质量。
```

## 3. Triple Barrier Labeling

源码用 ATR 定义：

```text
profit taking barrier
stop loss barrier
max holding time
```

然后给每个 RSI signal 打标签：

```text
+1 = hit profit barrier / time exit profitable
-1 = hit stop barrier / time exit losing
```

这是 Meta Labeling 的关键。

标签不是每根 K 线都有，而是只对 primary signal 发生的位置打。

## 4. Meta Model

源码使用：

```text
StandardScaler
RandomForestClassifier
class_weight = balanced
```

模型输出：

```text
P(signal is good)
```

不是：

```text
P(price goes up)
```

这是本文最重要的区别。

## 5. Probability Filter

源码用阈值：

```text
p >= 0.55
```

才执行交易。

这就是：

```text
Meta Model → Trade / Skip
```

在你的框架里，这可以变成：

```text
if meta_prob < threshold:
    skip signal
```

## 6. Bet Sizing

源码进一步把概率转成仓位：

```text
bet_size = clip((p - 0.5) / 0.5, 0, 1)
```

这比固定手数高级。

系统输出不再是：

```text
BUY
```

而是：

```text
BUY, confidence=0.83, size=0.66
```

这正是 Meta Labeling 的长期价值。

## 7. 三轨回测

源码比较：

```text
Plain RSI
Meta-labeled
Meta + Bet-sized
```

这点值得保留。

以后你评估任何策略增强器，都应该保留 baseline：

```text
原策略
过滤后策略
过滤 + 仓位后策略
```

否则无法判断 Meta Model 是否真的增值。

## 可迁移到你的框架

建议拆成：

```text
research/
├── signals/
│   ├── rsi.py
│   ├── breakout.py
│   └── momentum.py
├── labeling/
│   ├── triple_barrier.py
│   └── meta_label.py
├── features/
│   └── feature_engine.py
├── models/
│   ├── lightgbm.py
│   ├── xgboost.py
│   └── random_forest.py
├── sizing/
│   └── bet_sizing.py
└── execution/
    └── mt5.py
```

MT5 端只负责：

```text
receive signal / probability / size
    ↓
risk check
    ↓
execute
```

Python 端负责：

```text
labeling
training
feature research
model validation
bet sizing calibration
```

## 值得收藏的内容

一级收藏：

- Primary Model + Meta Model 双层架构；
- signal-level labeling；
- triple barrier label；
- feature engineering around signal context；
- probability threshold；
- probability → bet size；
- baseline / filtered / sized 三轨对比；
- Python research + MT5 execution 分离。

二级收藏：

- RSI signal 示例；
- RandomForest baseline；
- time/session features；
- performance summary helper。

不重点收藏：

- RSI 策略本身；
- 具体参数 `70/30`；
- 固定阈值 `0.55`；
- 单一 EURUSD H1 结果；
- parquet 数据文件。

## 不足与生产化建议

### 1. 模型可替换

RandomForest 是 baseline。

生产研究可替换为：

```text
LightGBM
XGBoost
CatBoost
Logistic Regression with calibration
```

重点是 probability calibration，而不是模型复杂度。

### 2. 阈值需要 walk-forward

`0.55` 不能固定相信。

应该用：

```text
walk-forward
purged CV
embargo
out-of-sample calibration
```

### 3. Bet sizing 应考虑成本和风险

当前：

```text
(p - 0.5) / 0.5
```

只是演示。

更稳健做法：

- probability calibration；
- Kelly fraction clipping；
- drawdown control；
- volatility targeting；
- liquidity penalty；
- transaction cost adjustment。

### 4. 标签需要防 leakage

Feature、label、split 必须严格避免未来函数。

源码已有时间切分，但生产版应进一步使用：

```text
PurgedKFold
Embargo
Event overlap control
```

## 最终结论

这篇应归入：

```text
ML Architecture / Meta Labeling / Bet Sizing
```

不是 RSI 策略文章。

它的长期价值是把任何已有 primary strategy 升级为：

```text
Candidate Signal
    ↓
Trade Quality Model
    ↓
Probability
    ↓
Position Size
```

对于 Python + MT5 双引擎量化框架，这属于核心架构参考。

## 标签

```text
Meta Labeling
Lopez de Prado
Triple Barrier
Primary Model
Meta Model
Bet Sizing
RSI
Python Research
MT5 Execution
ML Architecture
```
