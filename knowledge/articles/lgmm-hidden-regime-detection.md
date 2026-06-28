# LGMM：指标数据中的 Hidden Pattern / Regime Detection

来源：

- 文章：https://www.mql5.com/en/articles/18497
- 标题：Data Science and ML (Part 43): Hidden Patterns Detection in Indicators Data Using Latent Gaussian Mixture Models (LGMM)
- 作者：Omega J. Msigwa
- 本地源码：[lgmm-regime](../../examples/research/lgmm-regime/)

## 核心价值

这篇适合归入 Regime Detection。

不是重点学习“LGMM 预测价格”，而是学习：

```text
Indicator Feature Matrix
    -> latent clusters / hidden states
    -> Regime Feature
    -> Strategy / Risk / Meta Label
```

## 可迁移设计

```text
research/regime/
    base.py
    gaussian_mixture.py
    hidden_state_encoder.py
```

输出不应直接下单，而应变成：

```text
RegimeEvent
SignalEvent.regime
DecisionLog.regime
```

## 附件处理

本次只收源码和 notebook。ONNX 模型、CSV 数据属于生成物，未纳入。

## 收藏结论

适合作为 Regime Engine 参考。实际交易价值需要通过 walk-forward 和 meta-labeling 验证。
