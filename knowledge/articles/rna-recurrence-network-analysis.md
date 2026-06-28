# RNA：从 Recurrence Matrix 到复杂网络特征

来源：

- 文章：https://www.mql5.com/en/articles/22652
- 标题：Recurrence Network Analysis (RNA) in MQL5: From Recurrence Matrices to Complex Networks
- 作者：Hammad Dilber / Homirana

## 结论

RNA 是整个 Recurrence 系列中研究价值最高的一篇。

它把 recurrence matrix 看作 graph adjacency matrix：

```text
Recurrence Matrix
      │
      ▼
Adjacency Matrix
      │
      ▼
Complex Network Metrics
```

## 核心指标

- clustering coefficient；
- transitivity；
- average path length；
- betweenness；
- assortativity；
- density；
- rolling RNA；
- joint RNA。

## 已收录源码

- `examples/mql5/RNA_Library/`

## 适用方向

- market structure complexity；
- nonlinear regime feature；
- graph feature engineering；
- ML feature matrix；
- joint network synchronization。

## 最终判断

RNA 比单纯 RQA 更适合作为高级因子，因为 graph metrics 更容易表达市场结构复杂度和 regime transition。
