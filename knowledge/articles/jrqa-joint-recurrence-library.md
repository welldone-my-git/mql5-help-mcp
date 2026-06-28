# JRQA：双系统同步 recurrence 的 Regime 特征库

来源：

- 文章：https://www.mql5.com/en/articles/22610
- 标题：Joint Recurrence Quantification Analysis (JRQA) in MQL5: Detecting Simultaneous Recurrence in Two Series
- 作者：Hammad Dilber / Homirana

## 结论

JRQA 关注的是两个系统是否同时回到各自历史状态。

这与 CRQA 不同：

```text
CRQA：A 与 B 是否相似
JRQA：A 和 B 是否同时 recurrence
```

## 核心新增

- joint recurrence matrix；
- dual epsilon；
- JRR；
- JDET；
- JLAM；
- JENTR；
- JTREND；
- COMPLEXITY；
- rolling JRQA；
- OpenCL + CPU fallback。

## 已收录源码

- `examples/mql5/JRQA_Library/`

## 适用方向

- market co-movement；
- market resonance；
- risk-on / risk-off；
- regime synchronization；
- multi-asset portfolio risk feature。
