# LGMM Regime / Hidden Pattern Detection

来源：

- 文章：https://www.mql5.com/en/articles/18497
- 标题：Data Science and ML (Part 43): Hidden Patterns Detection in Indicators Data Using Latent Gaussian Mixture Models (LGMM)
- 作者：Omega J. Msigwa

## 定位

Regime / hidden pattern detection 研究样例。

## 文件

| 文件 | 说明 |
|---|---|
| `Include/Gaussian Mixture.mqh` | MQL5 LGMM / Gaussian mixture helper。 |
| `Include/Random Forest.mqh` | Random Forest helper。 |
| `Experts/LGMM BASED EA.mq5` | EA 示例。 |
| `Indicators/LGMM Indicator.mq5` | Indicator 示例。 |
| `Scripts/Get XAUUSD Data.mq5` | 数据导出脚本。 |
| `Python/main.ipynb` | Python 研究 notebook。 |

## 未收录内容

附件中的 ONNX 模型和 CSV 数据属于生成物/数据资产，本次未纳入源码库。

## 收藏价值

适合作为 `research/regime/` 的素材。长期更应抽象为：

```text
Feature Matrix -> Latent Regime Model -> RegimeEvent / RegimeFeature
```
