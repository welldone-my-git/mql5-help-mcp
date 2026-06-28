# ARIMA：传统时间序列预测 baseline

来源：

- 文章：https://www.mql5.com/en/articles/18247
- 标题：Data Science and ML (Part 42): Forex Time series Forecasting using ARIMA in Python, Everything you need to Know
- 作者：Omega J. Msigwa
- 本地源码：[arima-forecasting](../../examples/research/arima-forecasting/)

## 核心价值

ARIMA 是传统统计预测 baseline。对当前平台的价值是建立模型基准线，而不是直接生产 Alpha。

## 使用建议

用于：

- sanity check；
- 与 DeepAR / N-BEATS / Transformer 对比；
- 残差分析；
- 教学和 baseline benchmark。

不建议：

- 直接作为实盘 signal；
- 在非平稳高噪声序列上无验证使用；
- 跳过 walk-forward。

## 收藏结论

归入 `research/models/baselines`。价值在 benchmark。
