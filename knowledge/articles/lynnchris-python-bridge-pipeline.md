# LynnChris Python Bridge Pipeline：MQL5 WebRequest 到 Python ML 服务

来源：

- Part 34：https://www.mql5.com/en/articles/18979
- Part 35：https://www.mql5.com/en/articles/18985
- Part 36：https://www.mql5.com/en/articles/19065
- 作者：Christian Benjamin（LynnChris）
- 源码：[lynnchris-python-bridge](../../examples/research/lynnchris-python-bridge/)

## 结论

这套系列是 MQL5 Articles 中比较接近 “Research → Production” 的教程流。

它不够生产级，但它清楚展示了关键边界：

```text
MQL5
  = 数据采集 / 执行端 / WebRequest client

Python
  = 特征工程 / 模型训练 / 推理服务 / 存储
```

## Part 34：History Ingestion

MQL5 端：

```text
CopyRates
BuildJSON
WebRequest POST chunks
```

Python 端：

```text
Flask /upload_history
parse JSON
append rows
```

核心价值是数据出口层，不是模型。

## Part 35：Training and Deployment

Python 端开始承担：

```text
feature engineering
train
backtest
serve
```

MQL5 EA 承担：

```text
send latest bars
receive signal JSON
draw / trade
```

这证明了 Python service 可以作为 MT5 的外部 brain。

## Part 36：Python Direct MT5 Stream

Python 不再只等 MQL5 上传，而是直接调用 MetaTrader5 API：

```text
copy_rates_range
Parquet storage
train model
Flask /analyze
```

这更接近你的目标平台：

```text
MT5 data source
Python research layer
MQL5 execution adapter
```

## 可迁移设计

应沉淀为：

```text
DataAdapter
FeatureStore
ModelService
SignalAPI
ExecutionAdapter
DecisionLog
```

## 主要不足

- 服务边界不清：一个脚本同时 collect / train / backtest / serve；
- JSON schema 没有版本；
- EA 侧手工解析 JSON；
- CSV 和本地路径较多；
- 缺少统一 RiskEngine；
- 缺少可回放 DecisionLog。

## 对平台的建议

不要照搬这套代码。应该吸收架构方向：

```text
MQL5 WebRequest / Python MT5 API
  ↓
Data Ingestion
  ↓
DuckDB / Parquet
  ↓
Feature Engine
  ↓
Model Service
  ↓
SignalEvent
  ↓
Risk / Order / Broker
```

这篇适合作为 Python Bridge 资料进入一级知识库。

