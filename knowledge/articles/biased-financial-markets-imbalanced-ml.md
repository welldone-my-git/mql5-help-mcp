# Biased Financial Markets：金融 ML 的类别不平衡问题

来源：

- 文章：https://www.mql5.com/en/articles/17736
- 标题：Data Science and ML (Part 36): Dealing with Biased Financial Markets
- 作者：Omega J. Msigwa

## 结论

这是金融 ML 必修主题。

市场标签经常不平衡：

```text
up / down / range / no-trade
```

如果只看 accuracy，模型很容易看起来有效但没有交易价值。

## 收藏重点

- imbalance audit；
- oversampling / undersampling；
- class weights；
- precision / recall / F1；
- ROC / PR curve；
- resampling 不能破坏时间顺序；
- 最终仍要回到交易指标。

## 已收录源码

- `examples/research/biased-financial-markets/`

说明：

原始附件中的 `.onnx` 和 `.csv` 实验产物不作为源码精华提交。
