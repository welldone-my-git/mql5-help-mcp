# Transformer Trading Research

来源：

- 文章：https://www.mql5.com/en/articles/18885
- 标题：Data Science and ML (Part 48): Are Transformers a Big Deal for Trading?
- 作者：Omega J. Msigwa

定位：

```text
Python Research / Sequence Model Experiment。
```

## 文件

附件包含：

- `features.py`
- `model.py`
- `train.py`
- `bot.py`
- `Trade/` helper classes
- `requirements.txt`

## 收藏重点

- Transformer / Attention 在金融序列中的实验；
- 适合做模型选型和 sequence modeling 参考；
- 不应把 Transformer 本身视为 Alpha；
- 需要严格 walk-forward、成本、泄漏检查。

## 推荐迁移

```text
OHLCV / Factors
      │
      ▼
Windowed Sequence Tensor
      │
      ▼
Transformer Encoder
      │
      ▼
Prediction / Embedding / Confidence
      │
      ▼
Meta Label / Portfolio / Risk
```
