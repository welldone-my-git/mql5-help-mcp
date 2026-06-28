# JRQA Library

来源：

- 文章：https://www.mql5.com/en/articles/22610
- 标题：Joint Recurrence Quantification Analysis (JRQA) in MQL5: Detecting Simultaneous Recurrence in Two Series
- 作者：Hammad Dilber / Homirana

定位：

```text
Nonlinear Dynamics / Joint Recurrence Feature Engine。
```

## 文件结构

- `Include/RQA/JRQAMatrix.mqh`
- `Include/RQA/JRQAMetrics.mqh`
- `Include/RQA/JRQAWindow.mqh`
- `Indicators/RQA/JRQA_Indicator.mq5`
- 同时包含 RQA / CRQA 基础模块。

## 收藏重点

- joint recurrence matrix；
- dual epsilon configuration；
- JRR、JDET、JLAM、JENTR、JTREND、COMPLEXITY；
- rolling JRQA；
- OpenCL acceleration + CPU fallback；
- timestamp alignment / normalization。

## 适用方向

```text
Market Co-Movement
Regime Synchronization
Multi-Asset Resonance
Risk-On / Risk-Off Detection
```
