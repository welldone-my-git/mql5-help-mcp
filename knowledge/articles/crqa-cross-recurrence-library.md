# CRQA：两个时间序列之间的 Cross Recurrence 特征库

来源：

- 文章：https://www.mql5.com/en/articles/22500
- 标题：Cross Recurrence Quantification Analysis (CRQA) in MQL5: Building a Complete Analysis Library
- 作者：Hammad Dilber / Homirana

## 结论

CRQA 是 RQA 的双序列扩展，用于分析两个市场或两个变量之间的动力学关系。

适合：

```text
Pair Trading
Intermarket Analysis
Lead-Lag Research
Cross-Asset Regime
```

## 核心新增

- dual-series embedding；
- cross recurrence matrix；
- CRR；
- CDET；
- CLAM；
- CENTR；
- rolling CRQA；
- optional OpenCL。

## 已收录源码

- `examples/mql5/CRQA_Library/`

## 收藏重点

重点不是 indicator，而是：

```text
CRQAMatrix
CRQAMetrics
CRQAWindow
```

它们可以直接变成 pair feature engine。
