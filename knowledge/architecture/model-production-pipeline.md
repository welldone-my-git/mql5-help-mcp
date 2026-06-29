# Model Production Pipeline：Python Research 到 MQL5 ONNX Runtime

参考来源：

- [Python + MetaTrader 5：Research → Production ONNX 流程](../articles/python-mt5-onnx-research-production.md)

## 目标

将研究模型稳定交付到执行环境：

```text
Research
  ↓
Model Package
  ↓
Runtime Inference
  ↓
SignalEvent
  ↓
Risk / Order / Broker
```

## 标准流程

```text
1. Load MT5 / research data
2. Build features
3. Train model
4. Select threshold / sizing rule
5. Export ONNX
6. Validate ONNX parity
7. Build model package
8. Load in MQL5 / Python runtime
9. Emit SignalEvent
10. Record DecisionLog
```

## Model Package

最低应包含：

```text
model.onnx
feature_schema.json
threshold.json
training_config.json
validation_report.json
parity_report.json
```

### feature_schema.json

必须约束：

```text
feature order
dtype
lookback
timeframe
bar_shift
normalization
missing policy
available_at
```

否则 Python 和 MQL5 的输入很容易不一致。

## Runtime 原则

模型 runtime 不直接下单。

```text
ONNX Runtime
  ↓
SignalEvent
  ↓
RiskEngine
```

这保持：

- research；
- signal；
- risk；
- execution；

四层职责分离。

## 必须有的验证

### 1. ONNX parity

```text
sklearn / pytorch output
ONNX output
max diff
correlation
```

### 2. Feature parity

同一批 bars：

```text
Python features == MQL5 features
```

至少应有抽样对比报告。

### 3. Replay parity

同一模型包：

```text
Python replay signal
MQL5 tester signal
```

应能解释差异来源。

## 当前 MVP 落地建议

先实现：

```text
research/models/export_onnx.py
research/models/model_package.py
storage/decision_log.py
brokers/mt5_broker.py  # stub
```

暂缓：

- 自动部署模型；
- 多模型热切换；
- GPU 加速；
- 在线训练。
