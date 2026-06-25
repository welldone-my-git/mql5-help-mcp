# Feature Engineering for ML Part 5：微观结构 Feature Pipeline 架构

## 来源

- 标题：Feature Engineering for ML (Part 5): Microstructural Features in Python
- 来源：https://www.mql5.com/en/articles/22733
- 作者：Patrick Murimi Njoroge
- 发布日期：2026-06-10
- 分类：MetaTrader 5 / Trading systems
- 处理日期：2026-06-25

## 用户评审结论

评分：

| 项目 | 评分 |
| --- | --- |
| 总体评价 | 8.8/10 |
| 思想价值 | 9.5/10 |
| 代码质量 | 8/10 |
| 创新性 | 7.5/10 |
| 收藏价值 | 9.5/10 |
| 数学价值 | 9.5/10 |
| 工程质量 | 9.5/10 |
| Python 可迁移 | 10/10 |
| MQL5 代码质量 | 9/10 |
| EA 直接使用 | 6/10 |

总体判断：这篇比单个公式实现更值得学习，因为它讲的是整个微观结构 feature framework，而不是某一个指标。

用户补充判断：

```text
这是目前 MQL5 上关于 Microstructure Feature 实现最完整的一篇。
真正值得学习的是整个 Feature Engine 的设计，而不是某一个指标。
```

当前源码已纳入示例库：

- [examples/research/microstructure-feature-pipeline/microstructure.py](/home/novo/quant/github/welldone-my-git/mql5-help-mcp/examples/research/microstructure-feature-pipeline/microstructure.py)

它和 Part 6 的关系：

```text
Part 5 / 22733:
  Python 微观结构 feature pipeline 总设计
  bar-level + tick-level 两层架构
  包含 VPIN / imbalance / tick preprocessing

Part 6 / 22734:
  把 bar-level 层移植到 MQL5
  重点是 CMicrostructureFeatures.mqh
  不覆盖完整 tick-level 层
```

## 核心价值

这篇真正值得学的是：

```text
OHLCV
↓
Microstructure Feature
↓
Feature Matrix
↓
Machine Learning
```

这和用户当前一直在构建的范式一致：

```text
State
↓
Feature
↓
Return
```

文章不是直接给交易信号，而是在构造市场表示。它回答的是：

```text
如何把交易过程、流动性、冲击成本和订单流信息编码成机器学习特征？
```

更直接地说：

```text
它不是提出新的金融因子，
而是把 AFML Chapter 19 的微观结构特征体系工程化实现。
```

## 两层 Feature 架构

文章最重要的设计是把 feature 按数据可得性分两层。

### 第一层：Bar-level Features

只需要 OHLCV：

- Roll Spread
- Roll Impact
- Corwin-Schultz Spread
- Corwin-Schultz Sigma
- Kyle Lambda
- Amihud Illiquidity
- Hasbrouck Lambda

适合：

- 大多数日线数据
- AkShare / Tushare
- 普通 MT5 历史数据
- 大规模横截面因子研究

### 第二层：Tick-level Features

需要 raw tick stream：

- VPIN
- tick imbalance
- volume imbalance
- dollar imbalance
- buy fraction
- order-flow style features

适合：

- 有逐笔成交数据
- 有主动买卖方向或可近似方向
- 高频 / intraday / order-flow 研究

这个分层非常实用：

```text
Base Feature
+ Optional Tick Feature
```

很多人只有日线或 bar 数据。框架不应该因为没有 tick 数据就不能运行；tick 数据应该是可选增强层。

## Feature Matrix 思维

文章没有把每个指标写成孤立文件，而是统一入口：

```text
compute_all_microfeatures()
```

输出统一的 bar-indexed feature DataFrame。

这比：

```text
Roll.py
Kyle.py
Amihud.py
...
```

各自返回零散结果更适合 ML pipeline。

未来增加新特征时，只需要：

```text
append_column()
```

而不是改动下游模型接口。

这体现了开放封闭原则：

```text
feature set 可扩展
downstream contract 稳定
```

当前 `microstructure.py` 的核心入口是：

```text
compute_all_microfeatures()
```

它统一输出：

- `roll_measure`
- `roll_impact`
- `cs_spread`
- `cs_sigma`
- `kyle_lambda`
- `kyle_lambda_t`
- `amihud_lambda`
- `hasbrouck_lambda`
- `hasbrouck_lambda_t`
- `tick_imbalance`
- `volume_imbalance`
- `dollar_imbalance`
- `buy_fraction`
- `vpin`

这就是标准 ML feature matrix。

## 源码收藏重点

当前目录提供的 `microstructure.py` 值得重点收藏这些模块：

| 模块 | 收藏价值 | 原因 |
| --- | --- | --- |
| `compute_all_microfeatures()` | ★★★★★ | 统一入口，面向 ML pipeline |
| `bar_microstructure_features()` | ★★★★★ | tick → bar 聚合架构 |
| Tick Mapping | ★★★★★ | `searchsorted()` 一次映射，供所有 kernel 复用 |
| Numba kernels | ★★★★☆ | `@njit` / `prange` / `parallel`，便于迁移为 MQL5 loops |
| Rolling OLS | ★★★★☆ | Kyle / Hasbrouck 的滚动回归实现 |
| Roll / CS / Amihud | ★★★★★ | bar-level 流动性基础特征 |
| VPIN Bucket | ★★★★☆ | 更适合作为 regime feature，不建议单独做 signal |

## `searchsorted()` 映射设计

源码中最值得收藏的工程设计之一：

```text
tick_times
bar_times
  ↓
np.searchsorted(bar_times, tick_times, side="right")
  ↓
bar_membership
  ↓
bar_start / bar_end
```

很多低质量实现会在每个 tick feature 里重复扫描 tick：

```text
feature_1 → search ticks
feature_2 → search ticks
feature_3 → search ticks
```

这份源码的做法是：

```text
一次 tick-to-bar mapping
  ↓
所有 bar-level tick kernel 共用 start/end 边界
```

这把后续 feature 的计算变成复用边界数组的纯数组计算。

对 MQL5 迁移也很重要：

```text
先建立 TickIndexRange[]
再让所有 FeatureKernel 共用。
```

## Numba Kernel 设计

源码没有把计算都交给：

```text
pandas.rolling().apply()
```

而是使用：

```text
@njit(cache=True)
@njit(parallel=True, cache=True)
prange
pre-allocated arrays
float32 output
```

这更接近可迁移到 MQL5 的实现方式：

```text
Numba loop
  ↓
MQL5 for loop
```

因此收藏价值高于普通 pandas notebook。

## Feature 分层使用建议

如果做 EA 或实时系统，应分层使用：

### 必须优先实现

- Roll Spread：流动性 / spread 风险 proxy；
- Amihud：`return / dollar volume`，经典流动性因子；
- Corwin-Schultz：只需 high / low，不需要 tick，泛化性强。

### 推荐保留

- Kyle Lambda：price impact，但方向识别容易错；
- Hasbrouck Lambda：Kyle 的增强思路，可作为 impact feature。

### 谨慎使用

- VPIN：学术价值高，实盘争议较大，更适合作为 regime feature，不建议单独做 signal。

## 可升级方向

如果继续把它升级成长期量化基础库，建议：

### 1. Feature Registry

不要让统一入口里堆：

```text
if include_vpin:
if include_roll:
```

而是：

```text
Register(feature)
  ↓
FeatureFactory
  ↓
Compute()
```

### 2. Dependency Graph

显式管理依赖：

```text
TickRule
  ↓
Kyle
  ↓
Hasbrouck
  ↓
VPIN
```

避免重复计算。

### 3. Cache

可缓存：

- tick direction；
- dollar volume；
- log return；
- bar start/end；
- rolling sums；
- OLS sufficient statistics。

### 4. Incremental Update

当前源码偏 batch：

```text
whole DataFrame
  ↓
compute all
```

EA 实时运行更需要：

```text
new tick / new bar
  ↓
Update()
```

这是迁移到 MQL5 的最重要升级。

### 5. Feature Metadata

每个 feature 应声明：

```text
need_tick?
need_ohlc?
need_volume?
need_high_low?
window?
output_columns?
warmup?
```

以后 pipeline 可自动决定哪些 feature 能算，哪些缺数据。

## References 研究链

这篇文章的参考文献本身也值得保留。它基本覆盖了 AFML Chapter 19 背后的市场微观结构研究脉络，可以作为后续扩展 feature library 的路线图。

### 总框架

- López de Prado, M. (2018). *Advances in Financial Machine Learning*. Wiley. Chapter 19.

价值：

```text
Microstructure Feature Library 的总纲。
```

### 第一代：Spread / High-Low / Volatility Estimator

- Roll, R. (1984). *A Simple Implicit Measure of the Effective Bid-Ask Spread in an Efficient Market*. Journal of Finance.
- Parkinson, M. (1980). *The Extreme Value Method for Estimating the Variance of the Rate of Return*. Journal of Business.
- Beckers, S. (1983). *Variances of Security Price Returns Based on High, Low, and Closing Prices*. Journal of Business.
- Corwin, S. A., & Schultz, P. (2012). *A Simple Way to Estimate Bid-Ask Spreads from Daily High and Low Prices*. Journal of Finance.

对应实现：

- Roll Spread
- Roll Impact
- Corwin-Schultz Spread
- Corwin-Schultz / Parkinson-Beckers volatility

价值：

```text
只依赖 OHLC / close 序列即可估算 spread / volatility，
适合日线、A 股、期货、普通 MT5 bar data。
```

### 第二代：Price Impact / Illiquidity

- Kyle, A. S. (1985). *Continuous Auctions and Insider Trading*. Econometrica.
- Amihud, Y. (2002). *Illiquidity and stock returns: cross-section and time-series effects*. Journal of Financial Markets.
- Hasbrouck, J. (2009). *Trading costs and returns for U.S. equities: Estimating effective costs from daily data*. Journal of Finance.

对应实现：

- Kyle Lambda
- Amihud ILLIQ
- Hasbrouck Lambda
- rolling OLS t-stat

价值：

```text
把 return / price change 与 volume / signed flow 关联起来，
用于刻画流动性、价格冲击和交易成本。
```

### 第三代：PIN / VPIN / Flow Toxicity

- Easley, D., Kiefer, N., O'Hara, M., & Paperman, J. (1996). *Liquidity, Information, and Infrequently Traded Stocks*. Journal of Finance.
- Easley, D., López de Prado, M., & O'Hara, M. (2011). *The Microstructure of the Flash Crash*. Journal of Portfolio Management.
- Easley, D., López de Prado, M., & O'Hara, M. (2012). *Flow Toxicity and Liquidity in a High-frequency World*. Review of Financial Studies.
- Easley, D., López de Prado, M., & O'Hara, M. (2016). *Discerning information from trade data*. Journal of Financial Economics.
- Andersen, T. G., & Bondarenko, O. (2014). *VPIN and the Flash Crash*. Journal of Financial Markets.

对应实现：

- VPIN
- volume bucket
- buy/sell volume imbalance
- informed trading / flow toxicity proxy

价值：

```text
适合作为 regime feature / liquidity stress feature，
不建议单独作为交易信号。
```

注意：

```text
VPIN 争议较大，尤其依赖 buy/sell volume 分类质量。
tick rule 只是近似，不等于真实主动买卖方向。
```

### 下一层：Order Book / FIX / Options

- Eisler, Z., Bouchaud, J., & Kockelkoren, J. (2012). *The price impact of order book events: market orders, limit orders and cancellations*. Quantitative Finance.
- Tóth, B., Palit, I., Lillo, F., & Farmer, J. (2011). *Why is order flow so persistent?* arXiv working paper.
- Muravyev, D., Pearson, N., & Broussard, J. (2013). *Is there price discovery in equity options?* Journal of Financial Economics.
- Cremers, M., & Weinbaum, D. (2010). *Deviations from Put-Call Parity and Stock Return Predictability*. Journal of Financial and Quantitative Analysis.

对应未来扩展：

- order size distribution；
- cancellation rate；
- TWAP / order splitting detection；
- signed order flow autocorrelation；
- order book event impact；
- options market price discovery；
- put-call parity deviation。

价值：

```text
这是 full order book / FIX / options data 才能做的下一层，
普通 MT5 bar/tick 数据不足以完整复现。
```

### 基础教材

- O'Hara, M. (1995). *Market Microstructure Theory*. Blackwell.
- Hasbrouck, J. (2007). *Empirical Market Microstructure*. Oxford University Press.

价值：

```text
如果要系统理解 quote formation、adverse selection、inventory risk、
price impact 和 empirical microstructure，这两本应作为底层教材。
```

## References 对 Feature Library 的启发

这组文献可以直接映射成后续开发路线：

```text
Level 1: OHLC / Close
  Roll
  Parkinson / Beckers
  Corwin-Schultz

Level 2: OHLCV / Amount
  Amihud
  Hasbrouck proxy
  Kyle proxy

Level 3: Tick
  tick imbalance
  volume imbalance
  VPIN
  signed flow autocorrelation

Level 4: Order Book / FIX
  cancellation rates
  order size distribution
  book event impact
  TWAP detection

Level 5: Options
  options price discovery
  put-call parity deviation
```

这比单纯收藏公式更重要：它提供了 microstructure feature library 的扩展地图。

## 对 Python 框架的直接启发

用户已有环境：

- AkShare
- Tushare
- VectorBT
- Alphalens
- LightGBM
- XGBoost

建议优先实现：

```text
FeaturePipeline
  |
  |--- PriceFeature
  |--- VolumeFeature
  |--- LiquidityFeature
  |--- MicrostructureFeature
  |--- VolatilityFeature
  |--- MomentumFeature
  |
  ↓
Merge
  ↓
Feature Matrix
  ↓
AlphaLens
  ↓
LightGBM / XGBoost
  ↓
VectorBT
```

具体目录：

```text
features/
  price.py
  volume.py
  liquidity.py
  microstructure.py
  volatility.py
  momentum.py

pipeline/
  feature_pipeline.py
  merge.py
  validation.py

research/
  alphalens_eval.py
  ic_by_state.py
  layered_backtest.py
```

## 为什么框架比公式更重要

如果未来研究 5000 只股票 × 100 个 feature，不能让每个 feature 都重新读取 DataFrame 或重新对齐索引。

正确模式：

```text
一次读取
↓
统一缓存
↓
批量计算
↓
统一 feature matrix
```

这和 22734 的 `CMicrostructureFeatures` 思路一致，只是 22733 在 Python 层更完整。

## 与 AFML Chapter 19 的关系

文章按 AFML Chapter 19 的 microstructure 研究脉络组织：

### 第一代

- Roll Spread
- Corwin-Schultz

重点：从价格序列和 high-low range 推断 spread。

### 第二代

- Kyle Lambda
- Amihud Illiquidity
- Hasbrouck Lambda

重点：把价格变化和订单流 / volume 联系起来。

### 第三代

- VPIN
- imbalance features

重点：从 tick stream 和 volume-synchronized buckets 中提取 informed trading / order-flow imbalance 信息。

## 不足

### 1. 数据限制

真正的微观结构研究最好有：

- trades
- signed volume
- order book
- Level-2
- quote updates
- FIX messages

普通 MT5 / 日线数据通常只有：

- OHLC
- tick volume
- real volume（部分品种）

因此许多特征只能做近似版本。

### 2. 缺少完整统计验证

文章重点是 feature implementation，不是完整量化研究。

仍需补：

- IC / RankIC
- 因子分层收益
- AlphaLens 分析
- 稳健性检验
- 不同市场泛化
- transaction cost sensitivity
- state-conditioned IC

## 结合用户研究路线的优先级

如果目标是搭建长期可扩展的 Python 多因子研究平台，当前优先级应是：

| 排名 | 文章 | 推荐指数 | 原因 |
| --- | --- | --- | --- |
| 1 | 22733 | ★★★★★ | 学 Feature Pipeline、微观结构特征体系、Python 架构 |
| 2 | 22734 | ★★★★★ | 学 MQL5 bar-level 移植、源码工程组织、数值验证 |
| 3 | 23016 / Kalman Gain | ★★★★☆ | 学状态强度 / regime filter |
| 4 | 22962 / Decorator | ★★★★☆ | 学工程设计模式 |
| 5 | 22993 / Weekend Gap | ★★☆☆☆ | 工程模板可学，策略研究深度有限 |

更大的判断：

```text
好特征 > 好模型
Market Representation > Prediction Engine
```

## 推荐落地任务

1. `examples/research/microstructure-feature-pipeline/`

Python 原型：

- 输入 OHLCV / amount / tick optional
- 输出统一 feature matrix
- 支持 bar-level only
- tick-level features 作为 optional extension

2. `features/microstructure.py`

先实现 bar-level：

- Roll
- Corwin-Schultz
- Amihud
- Kyle proxy
- Hasbrouck proxy

3. `features/microstructure_tick.py`

有 tick 数据后再实现：

- tick imbalance
- volume imbalance
- dollar imbalance
- VPIN

4. `research/ic_by_state.py`

把 microstructure features 接到：

- IC
- RankIC
- 分层回测
- state-conditioned IC

## 与已有知识条目的关系

这篇是 `afml-microstructure-features-mql5.md` 的上游设计篇。

推荐阅读顺序：

```text
afml-microstructure-feature-pipeline-python.md
→ afml-microstructure-features-mql5.md
→ kyles-lambda-market-impact-liquidity-factor.md
→ da-cg-lstm-dynamic-feature-attention.md
```

其中：

- 22733 给 framework。
- 22734 给 MQL5 bar-level port。
- Kyle Lambda 条目给单因子解释。
- DA-CG-LSTM 条目说明这些 features 后续如何进入动态 feature weighting。

## 结论

这篇是目前最值得深入消化的 MQL5 系列文章之一。

它的价值不是某个单一公式，而是：

```text
如何把 market microstructure 系统化地转成 feature matrix。
```

对用户当前 Python 因子研究平台，最直接的启发是：

```text
先搭 Feature Pipeline，
再做 AlphaLens / IC / LightGBM，
最后才考虑复杂模型。
```

## 标签

- MQL5
- Python
- AFML
- feature engineering
- feature pipeline
- market microstructure
- Roll Spread
- Corwin-Schultz
- Kyle Lambda
- Amihud
- Hasbrouck
- VPIN
- order flow
- imbalance features
- Feature Matrix
- AlphaLens
- LightGBM
- VectorBT
