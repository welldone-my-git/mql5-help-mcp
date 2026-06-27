# Biased Financial Markets

来源：

- 文章：https://www.mql5.com/en/articles/17736
- 标题：Data Science and ML (Part 36): Dealing with Biased Financial Markets
- 作者：Omega J. Msigwa

定位：

```text
ML Evaluation / Imbalanced Dataset / Financial Classification。
```

## 文件

保留：

- `Python/main.ipynb`
- `Experts/Test Resampling Techniques.mq5`
- `Scripts/Collectdata.mq5`
- `Include/pandas.mqh`

未纳入提交：

- `.onnx` 训练产物；
- `.csv` 样例数据。

这些属于实验产物，不是源码精华。

## 收藏重点

- financial labels 往往不平衡；
- accuracy 在金融分类中经常误导；
- oversampling / undersampling / SMOTE 类方法需要谨慎；
- 应关注 precision、recall、F1、ROC、PR curve、交易后收益指标；
- resampling 不能跨时间乱打散导致泄漏。

## 推荐迁移

```text
Label Distribution Audit
      │
      ▼
Resampling / Class Weight
      │
      ▼
Walk-Forward Validation
      │
      ▼
Trading Metric Evaluation
```
