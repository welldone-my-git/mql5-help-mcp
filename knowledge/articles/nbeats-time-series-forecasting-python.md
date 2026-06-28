# N-BEATS：深度时间序列预测模型样例

来源：

- 文章：https://www.mql5.com/en/articles/18242
- 标题：Data Science and ML (Part 46): Stock Markets Forecasting Using N-BEATS in Python
- 作者：Omega J. Msigwa
- 本地源码：[nbeats-forecasting](../../examples/research/nbeats-forecasting/)

## 定位

N-BEATS 属于 research model zoo。它不是交易平台骨架依赖，而是预测模型候选。

## 适合用途

- 与 DeepAR / Transformer 做对照；
- 做多步 forecast；
- 作为 `research/models/forecasting` 参考；
- 输出 `SignalEvent` 的上游模型。

## 不足

- 预测准确不等于可交易；
- 需要严格 walk-forward；
- 需要概率校准 / meta-labeling / risk filter；
- 不应绕过 RiskEngine。

## 收藏结论

保留源码和 notebook 作为模型实验素材。平台层面只需要抽象：

```text
Model.predict_proba / predict
    -> SignalEvent
```
