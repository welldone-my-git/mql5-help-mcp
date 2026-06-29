# Part 36：Live MT5 Market Streams and Inference

文件：

- [market_ai_engine.py](./market_ai_engine.py)
- [trained_model_f10.mq5](./trained_model_f10.mq5)

## 核心流程

```text
Python MetaTrader5 API
  ↓
bootstrap / collect
  ↓
Parquet history
  ↓
train / backtest
  ↓
Flask /analyze
  ↓
MQL5 EA polling
```

可收藏点：

- Python 直接从 MT5 拉取 M1 bars；
- Parquet + zstd 作为历史存储；
- `GradientBoostingClassifier` + `RandomizedSearchCV`；
- Flask `/analyze` 服务；
- EA `OnTimer()` 周期请求；
- 响应包含 `signal / sl / tp / conf`。

平台建议：

- 把 `bootstrap / collect / train / serve` 拆成独立服务；
- 用 DuckDB 管理 FeatureStore 和 DecisionLog；
- 将 Flask 响应转换为统一 `SignalEvent`；
- MT5 EA 只做 adapter，不做完整交易系统。

