# CRQA Library

来源：

- 文章：https://www.mql5.com/en/articles/22500
- 标题：Cross Recurrence Quantification Analysis (CRQA) in MQL5: Building a Complete Analysis Library
- 作者：Hammad Dilber / Homirana

定位：

```text
Nonlinear Dynamics / Cross Recurrence Feature Engine。
```

## 文件

- `CRQAMatrix.mqh` — 双序列 embedding 与 cross-recurrence matrix。
- `CRQAMetrics.mqh` — CRR、CDET、CLAM、CENTR 等 cross recurrence metrics。
- `CRQAWindow.mqh` — rolling CRQA。
- `CRQA_Indicator.mq5` — 双品种实时比较指标。
- 同目录还包含 RQA 基础模块副本。

## 收藏重点

- dual-series embedding；
- cross recurrence matrix；
- adapted RQA metrics；
- rolling window；
- symbol pair alignment / normalization；
- optional OpenCL acceleration。

## 适用方向

```text
Pair Trading
Intermarket Analysis
Lead-Lag Research
Cross-Asset Regime Feature
```
