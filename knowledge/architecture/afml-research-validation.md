# AFML Research Validation：Sequential Bootstrap / Purged CV / CPCV

来源：

- Patrick Murimi Njoroge articles: https://www.mql5.com/en/users/patricknjoroge743/publications
- AFML / Lopez de Prado methodology
- [Patrick AFML Research Map](../articles/patrick-njoroge-afml-research-map.md)

## 目标

金融 ML 最大风险不是模型不够复杂，而是验证流程泄漏。

本层负责：

```text
sample uniqueness
sample weight
purging
embargo
CPCV
walk-forward
```

## 为什么普通 KFold 不够

金融标签经常有重叠持有期：

```text
label_i uses t0 -> t1
label_j uses t0+1 -> t1+1
```

如果直接 KFold，会导致训练集和测试集共享未来信息。

因此需要：

```text
Purging
Embargo
CPCV
```

## Sequential Bootstrap

目标：

```text
select samples with higher uniqueness
```

而不是随机抽样。

用途：

- 降低 label overlap；
- 提高训练样本独立性；
- 为 bagging / ensemble 构造更合理样本。

建议模块：

```text
research/sampling_weights/
├── indicator_matrix.py
├── uniqueness.py
└── sequential_bootstrap.py
```

## Purged / Embargo CV

Purging：

```text
remove training samples whose label interval overlaps test interval
```

Embargo：

```text
remove training samples shortly after test interval
```

用途：

- 避免时间泄漏；
- 避免持仓区间重叠泄漏；
- 更真实地估计 out-of-sample。

建议模块：

```text
research/validation/
├── purged_kfold.py
├── embargo.py
└── time_split.py
```

## CPCV

Combinatorial Purged Cross Validation 的目标：

```text
multiple train/test paths
    ↓
distribution of performance
```

不是只得到一个 Sharpe，而是得到策略表现分布。

平台应输出：

- mean；
- median；
- percentile；
- probability of loss；
- probability Sharpe > threshold；
- path stability。

建议模块：

```text
research/validation/cpcv.py
```

## 与 Meta Labeling 的关系

Meta Labeling 流程：

```text
Primary Signal
    ↓
Triple Barrier Label
    ↓
Meta Features
    ↓
Purged / Embargo CV
    ↓
Meta Model
    ↓
Probability
    ↓
Bet Sizing
```

如果 CV 有泄漏，meta model 的 probability 会被系统性高估。

## ValidationReport

建议统一输出：

```python
@dataclass
class ValidationReport:
    experiment_id: str
    model_name: str
    feature_set: str
    label_name: str
    splitter: str
    metrics: dict
    path_metrics: list[dict]
    leakage_checks: dict
    metadata: dict
```

## 进入 Paper / Live 的 gate

最低要求：

```text
1. no leakage check passed
2. purged CV score stable
3. CPCV lower percentile acceptable
4. transaction cost stress passed
5. regime split not catastrophic
```

不满足时，模型不能进入 PaperBroker。

## MVP

第一版可先实现：

```text
TimeSeriesSplit
PurgedKFold stub
Embargo window
ValidationReport schema
```

Sequential Bootstrap 和 CPCV 可作为第二阶段。

