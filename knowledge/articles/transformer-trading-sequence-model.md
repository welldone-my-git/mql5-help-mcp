# Transformer Trading：序列模型研究素材，不是直接 Alpha

来源：

- 文章：https://www.mql5.com/en/articles/18885
- 标题：Data Science and ML (Part 48): Are Transformers a Big Deal for Trading?
- 作者：Omega J. Msigwa

## 结论

Transformer 适合作为 sequence modeling 的研究候选，但不能因为模型先进就假设有 Alpha。

收藏价值：

```text
Model Architecture / Sequence Embedding / Attention Research
```

## 收藏重点

- windowed sequence tensor；
- attention / transformer encoder；
- feature extraction；
- forecast / classification；
- 必须做 walk-forward、成本、泄漏检查。

## 已收录源码

- `examples/research/transformer-trading/`

## 推荐迁移

```text
Transformer output
      │
      ├── direction probability
      ├── embedding
      └── confidence
      │
      ▼
Meta Label / Risk Engine
```
