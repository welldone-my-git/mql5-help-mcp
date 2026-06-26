# Meta-Labeling the Classics Part 2：ADX HPO Gate、Meta Model 与 Bet Sizing

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22754>
- Title: Meta-Labeling the Classics (Part 2): Filtering and Sizing ADX Trades
- Published: 2026-06-26
- Local source: [meta-labeling-adx](../../examples/research/meta-labeling-adx/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| Python 研究价值 | ⭐⭐⭐⭐⭐ |
| Feature Engineering | ⭐⭐⭐⭐⭐ |
| ML Pipeline | ⭐⭐⭐⭐⭐ |
| 可迁移到个人框架 | ⭐⭐⭐⭐⭐ |
| ADX 策略本身 | ⭐⭐⭐☆☆ |
| 收藏价值 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 这篇不是 ADX 策略文章，而是 classic indicator upgrade framework：Primary Signal → HPO Gate → Meta Label → Probability → Bet Size。

## 与 Part 1 的关系

Part 1 用 RSI 展示了 Meta Labeling 思想：

```text
Primary Model
    ↓
Meta Model
    ↓
Trade / Skip / Size
```

Part 2 用 ADX 展示了更完整的工程化流程：

```text
OHLC
    ↓
ADX / DI Cross
    ↓
Optimized Regime Gate
    ↓
ADX-centered Features
    ↓
Triple Barrier
    ↓
Random Forest
    ↓
Probability
    ↓
Bet Size
```

这更接近长期可复用的 Python research framework。

## 核心问题

ADX 的问题不是指标完全无效。

真正问题是：

```text
DI Cross 在震荡市场频繁产生低质量信号
```

文章的处理方式不是直接丢弃 ADX，而是把它升级成两层系统：

```text
Gate filters regime
Meta model filters signal quality
```

## 1. ADXSystem

`adx_system.py` 实现 Wilder 风格 ADX：

- `+DI`;
- `-DI`;
- `DX`;
- `ADX`;
- `ADXR`.

这部分值得保留，因为它把 classic indicator 作为 primary model 明确封装。

以后可以替换为：

- RSI；
- MACD；
- MA Cross；
- Bollinger；
- Breakout；
- CCI。

## 2. ADXSignalGenerator

信号来自 DI crossover：

```text
+DI crosses above -DI → long candidate
-DI crosses above +DI → short candidate
```

并加入 gate：

```text
ADXR >= threshold
abs(+DI - -DI) >= min_di_separation
```

这说明 primary signal 不等于最终交易。

primary signal 只是候选事件。

## 3. Optuna HPO Gate

文章没有固定 Wilder 的经验值 25。

而是用 Optuna 搜索：

```text
adxr_threshold
di_period
min_di_separation
```

这是全文最值得迁移的设计之一。

以后任何传统指标都应这样处理：

```text
Indicator default params
    ↓
HPO gate
    ↓
out-of-sample validation
```

不要手工迷信默认参数。

## 4. ADX Feature Engine

`adx_features.py` 的价值很高。

特征围绕 ADX signal context 构造，而不是裸 OHLC：

- `adx_level`;
- `adxr_level`;
- `adx_slope_5`;
- `di_separation`;
- `di_separation_delta`;
- `adx_above_both_di`;
- ATR ratio / volatility context；
- `bars_since_last_cross`;
- `dominant_di_duration`;
- `session_sin`;
- `session_cos`.

核心原则：

```text
Feature should describe signal quality, not blindly describe price.
```

## 5. Triple Barrier Meta Label

候选信号通过 triple barrier 标记：

```text
profit taking barrier
stop loss barrier
vertical time barrier
```

然后 meta model 学习：

```text
哪些 ADX/DI-cross 信号最终是好交易？
```

这保持了与 Part 1 RSI pipeline 的一致性。

## 6. Meta Model

`adx_pipeline.py` 使用 RandomForestClassifier 作为 baseline。

重点不是 Random Forest。

重点是模型目标：

```text
P(signal is worth taking)
```

而不是：

```text
P(next bar rises)
```

这是 Meta Labeling 和普通方向预测的根本区别。

## 7. Probability → Bet Sizing

pipeline 调用 AFML bet sizing：

```text
probability → position size
```

最终输出不应只是：

```text
BUY / SELL
```

而应是：

```text
side + confidence + size
```

这正是 Python research layer 与 MT5 execution layer 的接口。

## 8. 三轨对比

文章对比：

```text
Track 1 — 原始 ADX / DI Cross
Track 2 — HPO Gate only
Track 3 — HPO Gate + Classifier + Sizing
```

这个实验设计值得保留。

任何策略增强都必须比较：

```text
baseline
gate
gate + meta model
gate + meta model + sizing
```

否则无法证明新增模块真的有贡献。

## 对个人框架的迁移

建议抽象为：

```text
research/
├── primary_models/
│   ├── adx.py
│   ├── rsi.py
│   ├── macd.py
│   └── breakout.py
├── gate/
│   └── optuna_gate.py
├── features/
│   ├── adx_features.py
│   └── signal_context.py
├── labeling/
│   └── triple_barrier.py
├── models/
│   ├── random_forest.py
│   ├── lightgbm.py
│   └── xgboost.py
├── sizing/
│   └── bet_sizing.py
├── walkforward/
│   └── wf_engine.py
└── execution/
    └── mt5.py
```

## 值得收藏的内容

一级收藏：

- ADX primary model 封装；
- DI cross signal generator；
- ADXR / DI separation regime gate；
- Optuna HPO gate；
- ADX-centered feature engine；
- triple barrier meta label；
- RandomForest meta classifier baseline；
- probability threshold；
- AFML bet sizing；
- track-based performance comparison；
- classic indicator upgrade framework。

二级收藏：

- Wilder ADX 具体实现；
- AFML helper 子集；
- session sin/cos；
- demo data loading。

不重点收藏：

- 单一 EURUSD H1 结果；
- parquet 数据文件；
- 固定阈值；
- RandomForest 本身；
- ADX 作为独立 alpha 的宣传。

## 不足与生产化建议

### 1. HPO 需要严格 walk-forward

Optuna 很容易过拟合。

必须配合：

```text
walk-forward
purged CV
embargo
out-of-sample reporting
```

### 2. Probability calibration 必须补上

RandomForest probability 往往未校准。

生产版建议加入：

```text
Platt scaling
Isotonic calibration
calibration curve
Brier score
```

### 3. Feature Engine 应通用化

ADX features 不应写成孤立脚本。

应抽象为：

```text
SignalContextFeatureEngine
```

供 RSI、MACD、Breakout 共用。

### 4. MT5 执行层只接收最终决策

MT5 不应承担 HPO 和训练。

更合理：

```text
Python:
    research / training / validation / probability / size

MT5:
    signal mirror / risk check / execution / logging
```

## 最终结论

这篇应作为一级知识条目收录。

它的长期价值是展示如何把传统指标升级成：

```text
Classic Indicator
    ↓
Primary Signal
    ↓
Optimized Gate
    ↓
Meta Labeling
    ↓
Probability
    ↓
Bet Sizing
```

这正适合 Python + AkShare/TdxQuant + DuckDB + vectorbt + MT5 的研究执行分离架构。

## 标签

```text
Meta Labeling
ADX
DI Cross
Optuna
HPO
Triple Barrier
AFML
Bet Sizing
Random Forest
Signal Context Features
Python Research
MT5 Execution
```
