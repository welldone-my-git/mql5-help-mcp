# Feature Engineering for ML Part 6：AFML 微观结构特征工程

## 来源

- 标题：Feature Engineering for ML (Part 6): Microstructural Features in MQL5
- 来源：https://www.mql5.com/en/articles/22734
- 作者：Patrick Murimi Njoroge
- 发布日期：2026-06-18
- 分类：MetaTrader 5 / Trading systems
- 处理日期：2026-06-25

## 用户评审结论

综合评分：

| 项目 | 评分 |
| --- | --- |
| 研究价值 | 9.5/10 |
| 数学严谨性 | 9.5/10 |
| 工程质量 | 9/10 |
| MQL5 代码质量 | 9/10 |
| 可迁移到 Python | 10/10 |
| 直接交易价值 | 6/10 |
| 因子研究价值 | 9.5/10 |

结论：强烈推荐学习。尤其是：

- Roll Spread
- Corwin-Schultz Spread
- Amihud ILLIQ

这三个特征比很多 MQL5 “新指标”更有长期价值，适合作为多因子和机器学习模型中的基础流动性特征。

## 为什么这篇重要

文章实现的是 AFML 里经典的 bar-level 微观结构特征，而不是作者随手拼出来的新指标。

它是 Part 5 的 MQL5 移植篇。阅读顺序建议：

```text
22733 / Part 5:
  Python 微观结构 feature pipeline 设计
  bar-level + tick-level 两层架构
  包含 VPIN / imbalance / tick preprocessing

22734 / Part 6:
  MQL5 bar-level 层移植
  CMicrostructureFeatures.mqh
  数值一致性验证
```

所以 22733 更偏框架设计，22734 更偏 MQL5 工程移植。

核心特征：

- Roll Spread
- Roll Impact
- Corwin-Schultz Spread
- Corwin-Schultz Sigma
- Kyle Lambda
- Amihud Illiquidity
- Hasbrouck Lambda

这些特征描述的是：

- 流动性
- 买卖价差
- 冲击成本
- 市场效率
- 市场状态

它们更适合作为 ML 特征，而不是直接作为买卖信号。

## 和用户研究路线的关系

用户近期核心范式：

```text
State → Feature → Return
```

这篇正好属于 Feature Engineering。它不是直接预测收益，而是在构造更好的市场表示。

与已有方向的关系：

```text
异常成交额相关性
Kyle Lambda
Amihud Illiquidity
Roll Spread
Corwin-Schultz Spread
Hasbrouck Lambda
```

都属于：

```text
Market Microstructure / Liquidity Representation
```

也就是用价格、成交量、价差、冲击成本描述市场状态。

## 工程结构

文章的工程设计值得借鉴。

核心类：

```text
CMicrostructureFeatures
```

统一流程：

```text
Calculate()
  ↓
_CopyBars()
  ↓
_ComputeRoll()
_ComputeCS()
_ComputeLambdas()
  ↓
RollMeasure()
RollImpact()
CSSpread()
CSSigma()
KyleLambda()
AmihudLambda()
HasbrouckLambda()
```

优点：

- 不重复 `CopyRates` / `CopyOpen` / `CopyHigh` / `CopyLow` / `CopyClose` / `CopyTickVolume`。
- 所有特征共享 OHLCV 缓存。
- 各 estimator 独立写入自己的输出数组。
- EA 调用简单。
- OOP 分层合理。

这比每个指标各自复制一份 OHLC 数据更适合真实工程。

## 数学实现优点

### Roll Spread

文章没有机械照搬公式，而是用 running sums 做 single-pass covariance：

```text
Σx
Σy
Σxy
→ covariance
→ Roll Spread
```

优点：

- 不创建临时数组。
- 不做二次遍历。
- 更适合 MQL5 运行环境。

### OLS 实现

Kyle / Hasbrouck 需要 rolling OLS。

文章自己实现：

```text
Σx
Σy
Σx²
Σxy
→ β
→ t-value
```

没有依赖矩阵库。对 MQL5 来说这是很好的工程取舍。

### Corwin-Schultz

Corwin-Schultz 用 high-low range，不依赖成交量或 tick volume，因此更适合 MT5 bar data。

它的可迁移价值很高：

- 外汇
- 指数
- 商品
- A 股日线
- 期货日线

只要 high / low 可靠，就可以计算。

## 源码审查补充

用户提供了 `CMicrostructureFeatures.mqh` 源码内容。源码本体不落盘保存；这里只记录审查结论和复现时需要注意的实现细节。

### 优点

1. 缓存与计算分层清楚

`_CopyBars()` 统一复制：

- open
- high
- low
- close
- tick volume / real volume fallback

随后 `_ComputeRoll()`、`_ComputeCS()`、`_ComputeLambdas()` 共享同一份 OHLCV 缓存。这避免了每个 feature 重复请求历史数据。

2. 结果数组和 accessor 清晰

每个特征有独立数组和只读 accessor：

- `RollMeasure()`
- `RollImpact()`
- `CSSpread()`
- `CSSigma()`
- `KyleLambda()`
- `AmihudLambda()`
- `HasbrouckLambda()`

这适合 EA / indicator 复用。

3. Roll 和 OLS 都用 single-pass running sums

源码里 Roll covariance 和 OLS 都没有依赖矩阵库，也没有构造额外临时矩阵。对 MQL5 这种运行环境是务实选择。

4. `MICRO_EMPTY` sentinel 明确

不足数据、奇异矩阵、无效成交量等场景统一返回 `MICRO_EMPTY`，比返回 0 更安全。

### 需要修正或谨慎处理的问题

#### 1. `_OLS()` 注释和实现不一致

源码注释写的是：

```text
y = beta * x, no intercept
```

但 beta 的计算公式实际是带截距的一元回归斜率：

```text
beta = (n * Σxy - Σx * Σy) / (n * Σx² - (Σx)²)
```

如果是 no-intercept OLS，应更接近：

```text
beta = Σxy / Σx²
```

更重要的是，源码后续残差用的是：

```text
e = y - beta * x
```

没有减去截距：

```text
alpha = mean(y) - beta * mean(x)
e = y - alpha - beta * x
```

因此当前 `t_stat` 的标准误计算在统计意义上不严谨。虽然源码没有把 t-stat 暴露成特征，但如果未来要用 t-value，必须修正。

推荐：

```text
方案 A：明确使用带截距 OLS，并正确计算 alpha、residual、df = n - 2。
方案 B：明确使用 no-intercept OLS，beta = Σxy / Σx²，并按 no-intercept 模型计算标准误。
```

#### 2. Amihud 实现使用 price diff，而不是 log return

源码中：

```text
dp = close[i] - close[i+1]
x_amihud = abs(dp) / (close[i] * volume[i])
```

而标准 Amihud ILLIQ 更常见形式是：

```text
abs(return) / dollar_volume
```

其中 return 通常用百分比收益或 log return：

```text
abs(log(close_t / close_t-1)) / dollar_volume
```

源码版本会受价格量纲影响。迁移到 Python / A 股研究时，建议使用收益率版本：

```text
amihud = abs(log_return) / amount
```

如果保留源码公式，应明确命名为 price-diff-based illiquidity。

#### 3. `_TickRule()` 注释说 carry-forward，但 caller 没做

源码 `_TickRule()` 平价时返回 0，并注释“carry-forward handled in caller”。

但 `_ComputeLambdas()` 中没有看到实际 carry-forward 逻辑。

影响：

- 相邻 close 相等的 bar 会产生 signed volume = 0。
- Kyle / Hasbrouck 的回归自变量会多出 0。
- 在低波动或报价不活跃品种上会影响估计。

更稳健版本：

```text
if close_t > close_t-1: sign = +1
else if close_t < close_t-1: sign = -1
else: sign = previous_nonzero_sign
```

#### 4. accessor 缺少负 offset 防护

源码 accessor 逻辑类似：

```text
return((bar_offset < m_n) ? array[bar_offset] : MICRO_EMPTY);
```

如果传入 `bar_offset = -1`，条件仍成立，可能访问负索引。

建议改为：

```text
if(bar_offset < 0 || bar_offset >= m_n)
   return MICRO_EMPTY;
```

#### 5. tick volume / real volume fallback 的语义要小心

源码先用 `CopyTickVolume()`，失败才 fallback 到 `CopyRealVolume()`。

对外汇这合理，因为通常只有 tick volume。

但对交易所品种、股票、期货，真实成交量可能比 tick volume 更有研究含义。Python/A 股复现时应优先使用：

```text
amount / turnover
real volume
```

而不是 tick count。

#### 6. `Calculate()` 每次重新分配和填充输出数组

对 EA 单品种新 bar 计算可以接受。

如果未来做多品种、多周期、批量扫描，应考虑：

- 缓存数组容量。
- 增量更新。
- 避免每次全量 `ArrayResize + ArrayFill`。

## Python 复现时的推荐修正版

优先不要逐行翻译源码，而是实现研究语义更清楚的版本：

```text
roll_spread:
  use close diff covariance

corwin_schultz:
  use high-low estimator

amihud:
  use abs(log_return) / amount

kyle:
  use signed volume if available
  otherwise mark as proxy

hasbrouck:
  use signed sqrt(dollar volume)
  expose beta and t-stat separately

ols:
  choose intercept or no-intercept explicitly
```

测试要求：

```text
1. hand-crafted small samples
2. monotonic / flat price edge cases
3. zero volume / missing amount
4. Python vs MQL5 agreement for formulas intentionally copied
5. separate tests for corrected formulas that intentionally differ
```

## 科学性：tick volume 限制讲清楚

这篇最好的地方之一是作者没有夸大 MT5 数据能力。

MT5 的 `CopyTickVolume()` 返回的是 bar 内价格变化次数，不是真实逐笔成交量，也不是 signed volume。

因此：

```text
Kyle Lambda
Hasbrouck Lambda
```

在 MQL5 bar-level 实现中只能作为：

```text
ordinal regime signal
```

而不是：

```text
true cardinal price impact estimate
```

也就是说：

- 可以比较“当前比过去冲击成本更高/更低”。
- 不应该解释绝对数值。
- 不应该跨 broker 直接比较绝对值。

优先级判断：

| 特征 | 评价 | 原因 |
| --- | --- | --- |
| Roll Spread | ★★★★★ | 不依赖 volume，适合 bar data |
| Corwin-Schultz Spread | ★★★★★ | 不依赖 volume，适合 high-low 数据 |
| Amihud ILLIQ | ★★★★★ | 股票研究常用，迁移到真实成交额数据更强 |
| Kyle Lambda | ★★★☆ | MQL5 中 signed volume 只是近似 |
| Hasbrouck Lambda | ★★★☆ | 同样受 tick volume / bar-close tick rule 限制 |

## 验证方式

文章做了 Python → MQL5 数值一致性验证，并报告高度一致。

这点非常重要，因为很多 MQL5 文章只给实现，不给跨语言校验。

对用户后续复现建议：

```text
Python reference implementation
↓
MQL5 implementation
↓
same OHLCV input
↓
assert numerical agreement
```

如果做 Python 研究框架，应反过来：

```text
MQL5 article logic
↓
Python vectorized implementation
↓
unit tests against small hand-crafted examples
↓
Alphalens IC / RankIC
```

## Python 迁移价值

用户当前环境：

- AkShare
- Tushare
- VectorBT
- Alphalens
- LightGBM
- XGBoost

这篇最适合先迁移到 Python，而不是先做 EA。

建议目录：

```text
features/
  liquidity.py
  microstructure.py
```

最小实现：

```text
roll_spread(high, low, close, volume, window)
roll_impact(close, volume, window)
corwin_schultz_spread(high, low)
corwin_schultz_sigma(high, low)
kyle_lambda(close, volume, window)
amihud_illiq(close, amount, window)
hasbrouck_lambda(close, volume_or_amount, window)
```

注意：

- A 股应优先用 amount / turnover，而不是 tick volume。
- 股票日线 Amihud 更直接。
- Roll / Corwin-Schultz 可先做横截面因子。
- Kyle / Hasbrouck 要谨慎解释 signed volume。

## 推荐研究流程

不要先训练模型。先做因子验证：

```text
microstructure features
↓
winsorize / zscore / neutralize
↓
Alphalens
↓
IC / RankIC
↓
分层回测
↓
state-conditioned IC
```

候选组合：

```text
Microstructure Features
+ Momentum
+ Volatility
+ Liquidity
↓
LightGBM / XGBoost
```

如果单个特征有稳定 IC，再进入模型阶段。

## 推荐优先级

未来三个月研究优先级：

### 第一梯队

- 异常成交额相关性
- Kyle Lambda
- Amihud ILLIQ
- Roll Spread
- Corwin-Schultz Spread

### 第二梯队

- Takens Embedding
- Markov State

### 第三梯队

- LightGBM
- XGBoost

### 最后

- LSTM
- Transformer
- Quantum NN

原因：

```text
现在最缺的不是 Prediction Engine，
而是 Market Representation。
```

这篇文章本质上就在解决：

```text
如何把市场流动性编码成特征。
```

## 与已有知识条目的关系

这篇是已有微观结构条目的上位基础。

相关条目：

- `kyles-lambda-market-impact-liquidity-factor.md`
  - 单独讨论 Kyle Lambda 的交易解释和事件用法。
- `afml-microstructure-feature-pipeline-python.md`
  - 作为 Part 5 上游设计篇，给出 Python 两层 feature pipeline 架构。
- `da-cg-lstm-dynamic-feature-attention.md`
  - 微观结构特征可作为 feature attention 的输入。
- `qnn-markov-feature-pipeline-mql5.md`
  - Feature Pipeline 可以加入这些 microstructure features。
- `decorator-pattern-indicator-factor-pipeline.md`
  - 用 pipeline decorator 组织 winsorize / zscore / logging / cache。
- `adaptive-kalman-smoother-regime-factor.md`
  - Kalman Gain 可与 liquidity features 组合做状态识别。

组合研究框架：

```text
Market Microstructure Features
+ State Classification
+ Dynamic Feature Weight
→ Return / Risk / Regime
```

## 后续落地任务

1. `knowledge/patterns/microstructure-feature-engineering.md`

沉淀：

- Roll
- Corwin-Schultz
- Amihud
- Kyle
- Hasbrouck
- tick volume limitation
- Python / MQL5 validation protocol

2. `examples/research/microstructure-liquidity-features/`

Python 模板：

- 输入 OHLCV / amount
- 输出 7 个微观结构特征
- Alphalens IC / RankIC
- 分层回测
- state-conditioned IC

3. `examples/mql5/features/microstructure-feature-pipeline/`

MQL5 模板：

- `CMicrostructureFeatures` 风格 feature cache
- new-bar guard
- feature accessors
- ONNX / EA feature vector 输出

## 结论

这篇是目前 MQL5 文章里非常少见的高质量 feature engineering 文章。

它的价值不在“直接产生交易信号”，而在构造长期可复用的市场微观结构特征。

推荐先复现：

```text
Roll Spread
Corwin-Schultz Spread
Amihud ILLIQ
```

再谨慎扩展：

```text
Kyle Lambda
Hasbrouck Lambda
```

最后进入：

```text
IC / RankIC / 分层回测 / LightGBM
```

## 标签

- MQL5
- AFML
- feature engineering
- market microstructure
- liquidity
- Roll Spread
- Roll Impact
- Corwin-Schultz Spread
- Corwin-Schultz Sigma
- Kyle Lambda
- Amihud Illiquidity
- Hasbrouck Lambda
- tick volume
- ordinal regime signal
- Python migration
- Alphalens
- IC
- RankIC
- LightGBM
