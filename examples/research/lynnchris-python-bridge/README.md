# LynnChris Python Bridge Pipeline

来源：

- Part 34：https://www.mql5.com/en/articles/18979
- Part 35：https://www.mql5.com/en/articles/18985
- Part 36：https://www.mql5.com/en/articles/19065
- 作者：Christian Benjamin（LynnChris）

## 定位

```text
MQL5 WebRequest Client
  ↓
Python Flask Service
  ↓
Feature Engineering / Model
  ↓
Signal JSON
  ↓
MQL5 EA
```

这套源码不是生产级平台实现，但非常适合作为 Python Bridge / Research Pipeline 的反面与正面参考。

## 文件结构

| 目录 | 作用 |
|---|---|
| [part34-history-ingestion](./part34-history-ingestion/) | MQL5 历史数据分块上传到 Python |
| [part35-model-training](./part35-model-training/) | Python 训练、回测、serve；MQL5 EA 请求 signal |
| [part36-live-inference](./part36-live-inference/) | Python 直接读取 MT5、Parquet 存储、模型训练、Flask `/analyze` |

## 可收藏点

- MQL5 `WebRequest()` POST JSON；
- MQL5 分块上传历史 bars；
- Flask endpoint 接收 JSON；
- Python CLI：`collect / history / train / backtest / serve`；
- MT5 Python API `copy_rates_range()`；
- Parquet 作为研究数据文件；
- `joblib` 模型持久化；
- EA 侧解析 `signal / sl / tp / conf`；
- Python 和 MQL5 职责拆分。

## 需要升级的点

这套源码仍偏教程：

- JSON 手工拼接和手工解析；
- Flask API schema 不稳定；
- CSV / 本地文件路径写死较多；
- 模型训练与 live server 耦合；
- EA 可能直接交易，绕过统一 RiskEngine；
- 缺少 DecisionLog / TradeLog / FeatureStore。

平台化应升级为：

```text
MT5 / MQL5
  ↓
BrokerAdapter / DataAdapter
  ↓
Python API
  ↓
FeatureStore
  ↓
ModelService
  ↓
SignalEvent
  ↓
RiskEngine
```

