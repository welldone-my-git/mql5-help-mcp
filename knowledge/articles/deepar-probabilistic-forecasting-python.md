# DeepAR：多序列概率预测在交易研究中的位置

来源：

- 文章：https://www.mql5.com/en/articles/20571
- 标题：Data Science and ML (Part 47): Forecasting the Market Using the DeepAR model in Python
- 作者：Omega J. Msigwa

## 结论

DeepAR 的价值不在于直接给出买卖信号，而在于：

```text
多序列概率预测 + 不确定性估计
```

适合 Python research layer，不适合直接移植到 MQL5。

## 收藏重点

- autoregressive neural forecasting；
- 多资产 / 多时间序列共享模型；
- forecast mean / quantile / uncertainty；
- 可作为 meta feature；
- 需要严格 walk-forward，避免预测泄漏。

## 已收录源码

- `examples/research/deepar-forecasting/`

## 推荐用法

```text
DeepAR forecast
      │
      ├── expected return
      ├── forecast uncertainty
      └── quantile band
      │
      ▼
Meta Label / Position Sizing / Risk Filter
```
