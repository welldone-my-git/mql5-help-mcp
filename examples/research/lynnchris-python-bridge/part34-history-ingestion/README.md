# Part 34：History Ingestion

文件：

- [History_Ingestor.mq5](./History_Ingestor.mq5)
- [engine.py](./engine.py)

## 核心流程

```text
MQL5 CopyRates
  ↓
Build JSON chunk
  ↓
WebRequest POST /upload_history
  ↓
Python Flask
  ↓
feature rows / training_set
```

可收藏点：

- 分块上传，避免 payload 过大；
- MQL5 → Python JSON bridge；
- Python 端统一接收并持久化；
- 适合作为 MT5 data exporter 的雏形。

平台建议：

- CSV 改 DuckDB / Parquet；
- JSON schema 版本化；
- 上传端和训练端解耦；
- 每批数据写入 ingestion log。

