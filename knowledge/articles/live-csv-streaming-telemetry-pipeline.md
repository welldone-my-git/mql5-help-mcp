# Live CSV Streaming：实时交易会话遥测管线

来源：

- 文章：https://www.mql5.com/en/articles/23065
- 标题：CSV Data Analysis (Part 5): Real-Time CSV Streaming from Live MetaTrader 5 Sessions
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-24
- 源码目录：[examples/mql5/LiveCSVStreaming](../../examples/mql5/LiveCSVStreaming/)

## 收藏结论

收藏价值：★★★★★

这篇是 CSV Data Analysis 系列中最接近平台架构的一篇。CSV 只是传输介质，真正值得收藏的是：

```text
Live telemetry
Buffered writer
Daily rotation
File tail daemon
Rolling monitoring
Anomaly alert
```

## 核心价值

### 1. MT5 → Python 的实时观测层

传统回测只产生静态结果。这篇建立的是 live session telemetry：

```text
MT5 indicator / EA
  ↓
stream rows
  ↓
Python daemon
  ↓
dashboard / alerts
```

这对 Paper / Live 阶段很重要。

### 2. Buffer + Flush

`LiveCSVStreamer.mqh` 不是每条记录立即写盘，而是用 buffer 达到阈值后 flush。

平台版应迁移成：

```text
micro batch insert
```

而不是高频单行写入。

### 3. Daily Rotation

按日期切分 live stream 文件，避免单文件无限增长。

DuckDB / Parquet 侧对应 partition 设计：

```text
date
symbol
timeframe
stream_type
```

### 4. File Tail

Python daemon 维护 byte offset，只读取新追加的行。

这是比“定时全量重新读 CSV”更正确的实时消费方式。

## 平台迁移建议

原始结构：

```text
MQL5 → CSV → Python daemon
```

推荐结构：

```text
MQL5
  ↓
TelemetrySink
  ├── CSV fallback
  ├── DuckDB append
  ├── Parquet micro-batch
  └── Socket / IPC
  ↓
Monitor / API / Dashboard
```

## 对 quant_platform 的映射

| 模块 | 对应 |
|---|---|
| `storage/decision_log.py` | 记录模型决策与上下文 |
| `storage/trade_log.py` | 记录订单/成交/滑点 |
| `storage/feature_store.py` | 记录 live feature snapshot |
| `api/main.py` | 展示实时状态 |
| `replay` | 复用同一 schema 做回放 |

## 需要升级的点

- 增加 `event_id` / `decision_id` / `order_id`；
- CSV 只做 fallback，不做主总线；
- Python daemon 拆成 reader、parser、state、dashboard、alert；
- live schema 与 replay schema 统一；
- 加入 DuckDB sink。
