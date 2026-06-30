# AFML Feature Engine：从 OHLCV 到机器学习特征矩阵

来源：

- Patrick Murimi Njoroge articles: https://www.mql5.com/en/users/patricknjoroge743/publications
- [Microstructure Feature Pipeline in Python](../articles/afml-microstructure-feature-pipeline-python.md)
- [Microstructure Features in MQL5](../articles/afml-microstructure-features-mql5.md)
- [Patrick AFML Research Map](../articles/patrick-njoroge-afml-research-map.md)

## 目标

建立统一 FeatureEngine，让研究侧和执行侧共享同一套特征定义：

```text
Market Data
    ↓
FeatureEngine
    ↓
Feature Matrix
    ↓
Model / MetaLabel / Regime / Risk
```

## Feature 分层

```text
FeatureEngine
├── Geometry
├── PriceAction / Structure
├── Calendar
├── Session
├── Microstructure
├── Entropy
├── Regime
└── Forecast
```

### Geometry

低成本基础特征：

- body size；
- wick ratio；
- bar range；
- close position；
- gap；
- body / range ratio。

### Structure

市场结构特征：

- swing high / low；
- breakout；
- BOS / ChoCH；
- liquidity sweep；
- range compression；
- distance to object / level。

### Calendar

时间特征：

- hour；
- weekday；
- month；
- session；
- holiday / news distance。

建议使用 cyclic encoding：

```text
sin(time)
cos(time)
```

### Session

交易时段特征：

- Asia range；
- London range；
- NY range；
- overlap；
- distance to session high / low；
- session breakout state。

### Microstructure

AFML 微观结构特征：

- Roll spread；
- Corwin-Schultz spread；
- Kyle lambda；
- Amihud illiquidity；
- Hasbrouck lambda；
- VPIN；
- imbalance。

### Entropy

状态复杂度特征：

- Shannon entropy；
- plug-in entropy；
- Lempel-Ziv；
- Kontoyiannis。

用途：

```text
Regime confidence
Risk throttle
Meta feature
Model input
```

## Python / MQL5 Parity

核心原则：

```text
The same feature definition must be reproducible in research and live execution.
```

Python：

```text
bulk compute
walk-forward
feature store
model training
```

MQL5：

```text
closed-bar real-time compute
execution filter
lightweight feature snapshot
```

不要让 Python 研究特征和 MQL5 live 特征语义不一致。

## FeatureSnapshot

建议事件：

```python
@dataclass
class FeatureSnapshot:
    event_id: str
    timestamp: datetime
    symbol: str
    timeframe: str
    features: dict[str, float]
    source: str
    closed_bar: bool
    metadata: dict
```

所有模型只消费 `FeatureSnapshot`，不直接读取 broker。

## 存储

FeatureStore 最少包含：

```text
symbol
timeframe
timestamp
feature_set
feature_name
feature_value
source
version
```

实际落地可用 wide table：

```text
features_bar_m5
features_tick_agg
features_session
features_microstructure
```

## 反模式

避免：

- feature 函数内部偷看未来；
- open bar 特征混入 closed bar 训练集；
- Python 和 MQL5 使用不同窗口定义；
- 训练时用真实 volume，live 时只有 tick volume，却不标注；
- feature 名称不带版本；
- 每个策略各自复制一套特征计算。

## MVP

第一版只需要：

```text
FeatureEngine
├── calendar_features()
├── session_features()
├── candle_geometry_features()
├── microstructure_bar_features()
└── feature_snapshot()
```

后续再加入 entropy、alternative bars、tick-level imbalance。

