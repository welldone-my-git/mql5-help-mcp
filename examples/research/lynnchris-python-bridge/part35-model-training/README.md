# Part 35：Model Training and REST Inference

文件：

- [Spike_DETECTOR.mq5](./Spike_DETECTOR.mq5)
- [engine.py](./engine.py)

## 核心流程

```text
MQL5 EA
  ↓ POST latest bars
Python Flask /analyze
  ↓ feature engineering
  ↓ model inference
JSON signal
  ↓
MQL5 draw / trade
```

可收藏点：

- Python CLI：`collect / history / train / backtest / serve / info`；
- `MetaTrader5` Python API；
- `joblib` model cache；
- Flask `/analyze` 返回 signal / side / SL / TP / confidence；
- EA 端 retry 和简单 JSON parser。

平台建议：

- EA 不应直接交易，应转成 `SignalEvent`；
- Python service 不应同时承担训练、回测、live 推理；
- 模型输出应进入 DecisionLog；
- RiskEngine 应统一处理 SL/TP、confidence threshold 和仓位。

