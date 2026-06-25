# ZScore Source Essence

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22707>
- Title: Building an Object-Oriented Z-Score Statistical Arbitrage Engine in MQL5

定位：

```text
Signal Engine / Feature Engine 收藏样例，不是完整交易策略。
```

## 文件说明

- `SignalEngineBase.mqh` — 抽象信号接口，统一 `IsReady()` / `Value()`。
- `ZScoreEngine_Essence.mqh` — 可复用 Z-Score 计算引擎。
- `OncePerBar.mqh` — EA 每根新 K 线只执行一次的辅助类。
- `EA_ZScore_Template.mq5` — 最小 EA 模板，负责调用信号与执行交易。
- `Ind_ZScore_Template.mq5` — 最小指标模板，与 EA 复用同一套引擎。
- `README_收藏说明.md` — 原始收藏说明。

## 核心学习点

- 数学计算与 EA / Indicator 解耦；
- 默认 `shift=1`，只基于已完成 K 线；
- `Bars()` / `CopyClose()` / `StdDev=0` 防御检查；
- `new` / `delete` 生命周期管理；
- `OncePerBar` 避免 `OnTick()` 高频重复计算；
- 统一接口便于扩展 RSI、ATR、Hurst、Microstructure 等后续 Feature Engine。

## 不建议直接实盘的部分

- 固定阈值 Z-Score 均值回归；
- 固定手数；
- 缺少 spread / volatility / regime filter；
- 持仓管理仍是模板级别。

推荐用途：

```text
作为 MQL5 SignalEngine / FeatureEngine 的基础骨架。
```
