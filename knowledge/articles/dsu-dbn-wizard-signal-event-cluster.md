# MQL5 Wizard Part 95：DSU + DBN Signal 的事件聚类信号架构

## 来源

- 标题：MQL5 Wizard Techniques Part 95 — DSU + DBN Signal
- 正式标题：MQL5 Wizard Techniques you should know (Part 95): Using Disjoint Set Union and Deep Belief Network in a Custom Signal Class
- 来源：https://www.mql5.com/en/articles/22937
- 作者：Stephen Njuki
- 发布日期：2026-06-12
- 分类：MetaTrader 5 / Trading systems
- 主题：DSU（Disjoint Set Union）+ Deep Belief Network 构建 MQL5 Wizard 自定义 Signal
- 处理日期：2026-06-25

## 用户评审结论

一句话总结：

```text
文章真正的价值不是 DSU，也不是 DBN，
而是把连续波动抽象成事件 Cluster，
再基于事件评分和过滤做交易决策。
```

评分：

| 项目 | 评分 |
| --- | --- |
| 学习价值：架构 | ★★★★★ |
| 学习价值：算法 | ★★☆☆☆ |
| 工程价值 | ★★★★★ |
| 交易价值 | ★★☆☆☆ |

值得收藏：

- Wizard Signal 类组织方式；
- `Feature → Cluster → Score → Filter → Signal` pipeline；
- 多模式切换；
- Cluster / Score / Filter 分层；
- event-driven trading 思想。

不建议照搬：

- DSU 聚类实现；
- `DBNForwardPass()`；
- `MathTanh()` 假装深度网络；
- ATR + BB 简单特征。

## 核心思想

不要把每根 K 线都当作独立信号：

```text
Price Bars
  ↓
连续高波动检测
  ↓
Cluster / Event
  ↓
Cluster Score
  ↓
Filter
  ↓
Signal
```

核心转变：

```text
Event Driven > Bar Driven
```

这比“每根 bar 判断一次买卖”更接近真实市场结构。

## 文章 Pipeline

整体架构：

```text
Indicators
  ↓
Feature
  ↓
DSU Cluster
  ↓
DBN Filter
  ↓
Signal
  ↓
EA
```

也就是标准的：

```text
Feature Engineering
  ↓
Classifier / Filter
  ↓
Trading Signal
```

虽然文章里的 DBN 质量一般，但这个 pipeline 位置是对的。

## DSU 的作用

DSU 负责把连续异常波动合并成 cluster。

例如：

```text
ATR abnormal:
1 2 3 5 6 0 0 4 5

Cluster A:
■■■■■

Cluster B:
■■
```

本质不是复杂图算法，而是：

```text
连续事件聚类
```

如果只是单时间序列上的连续区间，DSU 并不是唯一选择，也不一定是最佳选择。

## 四种 Cluster 模式

### Mode 1：ATR Cluster

逻辑：

```text
ATR 连续扩大
  ↓
Union
  ↓
Cluster
```

适合：

- 新闻行情；
- 波动突然抬升；
- volatility expansion。

### Mode 2：Bollinger Band Width Cluster

逻辑：

```text
BB Width 持续扩大
  ↓
Cluster
```

适合：

- 突破；
- squeeze 后扩张；
- volatility breakout。

### Mode 3：ATR + BB Width Combined

逻辑：

```text
ATR
  +
BB Width
  ↓
共同确认
  ↓
Cluster
```

更保守，误触发更少，但也可能错过早期信号。

### Mode 4：Price Action Cluster

逻辑：

```text
实体越来越大
  ↓
Cluster
```

不用指标，更接近纯 price action event。

## 最值得学习的代码结构

用户提供的主流程骨架：

```text
LongCondition()
  ↓
StartIndex()
  ↓
switch(mode)
  ↓
DSUClusterXXX()
  ↓
DBNForwardPass() / threshold
  ↓
return signal weight
```

它体现了一个好的 Wizard Signal 写法：

```text
选择模式
  ↓
计算事件分数
  ↓
过滤器确认
  ↓
输出 Signal 权重
```

这是比在 `LongCondition()` 里堆几百行 if 更好的结构。

## 多模式设计

文章用：

```text
input int DSUMode = 1;
```

再内部切换：

- ATR；
- BB；
- ATR + BB；
- Price Action。

这个设计方向值得学，但建议改成 enum：

```text
enum ENUM_SIGNAL_MODE
{
  MODE_ATR_BREAKOUT = 0,
  MODE_BB_EXPANSION = 1,
  MODE_CUSUM_EVENT  = 2,
  MODE_ADAPTIVE_CHANNEL = 3
};
```

比裸 `int` 更安全、更可读。

## Cluster 函数拆分

文章把不同逻辑拆成：

```text
DSUClusterATR()
DSUClusterBB()
DSUClusterCombined()
DSUClusterPriceAction()
```

这个组织方式值得保留。

更推荐的命名：

```text
CalcATRBreakoutScore(index)
CalcBBExpansionScore(index)
CalcChannelBreakoutScore(index)
CalcRegimeScore(index)
```

重点是：

```text
LongCondition() 只编排流程；
具体 feature / score 由独立函数负责。
```

## Filter 层位置是对的

文章中：

```text
cluster score
  ↓
DBNForwardPass()
  ↓
threshold
```

虽然 DBN 本身不可靠，但 filter 的位置很好。

可以替换为：

```text
PassTrendFilter(index)
PassVolatilityFilter(index)
PassSpreadFilter()
PassRegimeFilter(index)
PassLiquidityFilter(index)
```

也就是：

```text
Signal Score
  ↓
Filter
  ↓
Trade / No Trade
```

## DBN 的问题

文章名义上是：

```text
Cluster
  ↓
DBN
  ↓
Probability
  ↓
Trade
```

但用户评审指出，实际更像：

```text
MathTanh()
  ↓
Threshold
```

这不像真正的 Deep Belief Network。

更准确的评价：

```text
DBN 是 AI 包装，工程位置可借鉴，模型本身不值得收藏。
```

## 更推荐的事件检测方法

DSU 可以学习其“事件聚类”思想，但不一定照搬。

更适合研究的替代方法：

| 方法 | 价值 | 用途 |
| --- | --- | --- |
| CUSUM | ★★★★★ | 波动/收益累计触发事件开始 |
| Change Point Detection | ★★★★★ | regime shift / event boundary |
| HMM | ★★★★★ | 市场状态识别 |
| DBSCAN | ★★★★☆ | 多维 volatility / liquidity cluster |
| HDBSCAN | ★★★★☆ | 自动层级聚类 |

如果只做连续异常区间，简单状态机或 CUSUM 往往比 DSU 更直接。

## 推荐升级版本

文章特征：

```text
ATR
BB Width
Body
  ↓
DBN
```

建议升级：

```text
ATR
Volume
Order Flow
VWAP Distance
Liquidity
Microstructure
Market State
  ↓
LightGBM / Logistic / Calibrated Model
  ↓
Probability
```

核心不是换更花的模型，而是加强：

```text
事件定义 + 特征质量 + 状态分组
```

## 推荐收藏的 Signal 骨架

比原文更适合实战的结构：

```text
int CSignalXXX::LongCondition(void)
{
  int idx = StartIndex();

  double score = CalcSignalScore(idx);
  if(score <= 0.0)
    return 0;

  if(!PassRegimeFilter(idx))
    return 0;

  if(!PassRiskFilter())
    return 0;

  return int(m_pattern_0 * MathMin(score, 1.0));
}
```

对应层次：

```text
CalcSignalScore()
  ↓
PassRegimeFilter()
  ↓
PassRiskFilter()
  ↓
Signal Weight
```

这可以作为未来 MQL5 Wizard 自定义 Signal 的通用模板。

## 和本项目已有知识的关系

可接入当前知识库中的多个方向：

- G Channel：作为 `MODE_ADAPTIVE_CHANNEL` 或 trend structure feature；
- Universal Breakout Study：把 breakout 从 bar-driven 改成 event-driven；
- Market State Classification：cluster 后按 regime 分组评估；
- Microstructure Features：用 Kyle / Amihud / spread 过滤事件质量；
- Decorator Pattern：给 signal score 增加 logging / cache / threshold decorator；
- Repository Pattern：对 signal 结果做可测试统计；
- Object Pool：大量 event/cluster 对象可池化。

## 实际研究建议

不要问：

```text
DSU + DBN 能不能赚钱？
```

而应该问：

```text
连续波动 cluster 这个事件定义，
在不同市场状态下是否有 forward return 差异？
```

建议验证：

1. cluster start 后 N bars forward return；
2. cluster duration 与后续波动/收益的关系；
3. cluster score 分层后的收益差异；
4. ATR cluster vs BB width cluster vs price action cluster；
5. cluster 在 trend / range / expansion 状态下的条件效果；
6. cluster 加 microstructure filter 后是否改善。

## 最终结论

这篇文章的算法包装不强，但架构思想值得收藏。

真正要保留的是：

```text
Bar Signal
  ↓
Event Cluster Signal
```

以及：

```text
Feature → Cluster → Score → Filter → Signal
```

一句话沉淀：

```text
No.95 的价值不是 DSU 或 DBN，
而是提供了一个适合 Wizard Signal 的事件驱动信号骨架。
```

## 标签

- MQL5
- Wizard Signal
- DSU
- DBN
- Event Driven Trading
- Volatility Cluster
- Cluster Scoring
- Signal Pipeline
- Feature Engineering
- Regime Filter
