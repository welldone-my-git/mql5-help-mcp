# DeepAR Forecasting

来源：

- 文章：https://www.mql5.com/en/articles/20571
- 标题：Data Science and ML (Part 47): Forecasting the Market Using the DeepAR model in Python
- 作者：Omega J. Msigwa

定位：

```text
Python Research / Probabilistic Time-Series Forecasting。
```

## 文件

附件包含：

- `main.py`
- `train.py`
- `config.py`
- `Trade/` helper classes
- `requirements.txt`

## 收藏重点

- DeepAR 作为 autoregressive neural forecasting；
- 多时间序列预测思路；
- 适合 Python research layer；
- 不适合直接移植到 MQL5；
- 输出应转成 forecast distribution / confidence feature，而不是直接交易信号。

## 推荐迁移

```text
Feature Matrix
      │
      ▼
DeepAR / probabilistic forecast
      │
      ▼
forecast_mean / forecast_quantile / uncertainty
      │
      ▼
Meta Label / Risk Sizing / Regime Filter
```
