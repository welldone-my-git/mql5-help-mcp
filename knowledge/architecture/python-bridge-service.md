# Python Bridge Service

## 定位

连接 MT5 / MQL5 与 Python Research Layer。

```text
MT5 / MQL5
  ↓ WebRequest / Python MT5 API
Python Service
  ↓
Feature / Model / Signal
```

来源样例：

- [LynnChris Python Bridge Pipeline](../../examples/research/lynnchris-python-bridge/)
- [Python + MT5 ONNX Integration](../../examples/research/python-mt5-onnx-integration/)

## 服务边界

生产平台中至少拆成：

```text
DataIngestionService
FeatureService
ModelService
SignalService
DecisionLogger
```

不要把 collect、train、backtest、serve 全部塞进一个长期进程。

## API Schema

最低限度：

```text
POST /signal
{
  "symbol": "...",
  "timeframe": "...",
  "bars": [...]
}

{
  "signal_id": "...",
  "direction": "BUY|SELL|FLAT",
  "confidence": 0.0,
  "stop_loss": 0.0,
  "take_profit": 0.0,
  "model_name": "...",
  "regime": "...",
  "metadata": {}
}
```

## 平台映射

```text
API response
  ↓
SignalEvent
  ↓
RiskEngine
  ↓
OrderManager
```

MQL5 EA 不应绕过 RiskEngine 直接交易。

## 存储

建议：

```text
DuckDB
  ├── bars
  ├── features
  ├── signals
  ├── decisions
  └── fills

Parquet
  └── historical archive
```

CSV 只能作为临时交换或 fallback。

## 必须记录

```text
request_id
model_version
feature_version
input_window
prediction
confidence
risk_decision
final_action
```

