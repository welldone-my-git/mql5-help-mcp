# Live CSV Streaming：MT5 Live Session → Python Daemon

来源：

- 文章：https://www.mql5.com/en/articles/23065
- 标题：CSV Data Analysis (Part 5): Real-Time CSV Streaming from Live MetaTrader 5 Sessions
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-24

## 定位

```text
Live Telemetry / Streaming Export / Python Monitoring Bridge。
```

这篇是 CSV Data Analysis 系列里最接近实时平台的一篇。CSV 不是最终形态，但 streaming、buffer、rotation、tail daemon 的设计值得保留。

## 文件

| 文件 | 作用 |
|---|---|
| `LiveCSVStreamer.mqh` | MQL5 侧 streaming include，负责 bar/tick record、buffer、flush、daily rotation |
| `LiveStream_Indicator.mq5` | 示例指标，计算 EMA 并输出 bar/tick telemetry |
| `live_stream_daemon.py` | Python daemon，tail 活跃 CSV 文件，维护 rolling metrics 并渲染控制台 dashboard |

## 值得抽取的模块

### 1. Buffered Writer

`CStreamBuffer` 用内存缓冲减少高频文件写入：

```text
Push(row)
  ↓
flush threshold
  ↓
FlushToFile()
```

适合改造成：

```text
DuckDB batch insert
Parquet micro-batch
Socket / IPC publisher
```

### 2. Daily Rotation

文件名按 symbol / timeframe / date 组织，跨天自动切换。

平台侧对应：

```text
partition by date / symbol / timeframe
```

### 3. Bar / Tick 两类 Record

源码区分：

- `SLiveBarRecord`
- `SLiveTickRecord`

这对应平台里的：

```text
BarEvent
TickEvent
TelemetryEvent
```

### 4. File Tail Daemon

Python 端不是反复全量读 CSV，而是维护 byte offset，只读取新增内容。

这是实时消费文件流时的正确基础模式。

## 平台迁移建议

原始文章：

```text
MQL5
  ↓ CSV append
Python daemon tail
```

建议升级：

```text
MQL5
  ↓ buffered telemetry
Bridge Sink
  ├── DuckDB append
  ├── Parquet micro-batch
  ├── ZeroMQ / socket
  └── CSV fallback
Python Monitor / API / Dashboard
```

## 与当前平台关系

可映射到：

```text
storage/decision_log.py
storage/trade_log.py
storage/feature_store.py
api/dashboard
replay/live_telemetry_adapter.py
```

## 不建议保留的部分

- 长期以 CSV 作为主实时总线；
- dashboard 和 parsing 逻辑绑死在一个脚本；
- 只记录指标值，不记录 event_id / decision_id / order_id；
- live telemetry 与 replay schema 不一致。
