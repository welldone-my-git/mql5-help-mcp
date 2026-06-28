# VAR：多变量时间序列预测 baseline

来源：

- 文章：https://www.mql5.com/en/articles/18371
- 标题：Data Science and ML (Part 44): Forex OHLC Time series Forecasting using Vector Autoregression (VAR)
- 作者：Omega J. Msigwa
- 本地源码：[var-forecasting](../../examples/research/var-forecasting/)

## 核心价值

VAR 是传统多变量时间序列模型，适合作为多资产/多字段联动 baseline。

对当前框架有两个用途：

```text
1. research/models/baselines
2. intermarket / pair / OHLC dependency study
```

## 与其他模块的关系

- 与 CRQA / JRQA：都关注序列间关系；
- 与 feature engine：可输入多变量特征；
- 与 meta-labeling：可作为 primary / context signal。

## 收藏结论

保留为统计 baseline。实际 Alpha 需要另行验证，不应直接转成交易策略。
