# MQL5 Bootstrap：Python-like Logging Facade

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/20458>
- Title: Log Like a Pro in MQL5: Build a Python-Inspired Logging Library
- Author: Omega Joctan
- Local source: [Bootstrap_Logging](../../examples/mql5/Bootstrap_Logging/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 策略思想 | ☆☆☆☆☆ |
| 数学算法 | ☆☆☆☆☆ |
| MQL5 技巧 | ⭐⭐⭐⭐☆ |
| 工程设计 | ⭐⭐⭐⭐⭐ |
| Bootstrap 依赖价值 | ⭐⭐⭐⭐⭐ |
| 收藏价值 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 这篇不是交易文章，而是给 MQL5 Bootstrap 系列补上诊断日志层。

## 与 Bootstrap 系列的关系

`20695` 是 File IO facade。

`20458` 是 Logging facade。

合理分层是：

```text
File IO
    ↓
Logger
    ↓
EA / Indicator / Script diagnostics
```

如果要长期维护 EA 框架，日志系统是基础设施，不是可选功能。

## 核心设计

源码提供一个 `CLogger` 类，把这些行为收进统一接口：

- 日志等级；
- 格式化输出；
- 文件写入；
- 控制台输出；
- 文件轮转；
- 缓存写入；
- `FILE_COMMON` 支持；
- EA / Indicator / Script program type 标记。

这比在业务代码里到处写 `Print()` 更可维护。

## 1. LogLevels

日志等级设计接近 Python logging：

```text
DEBUG    = 10
INFO     = 20
WARNING  = 30
ERROR    = 40
CRITICAL = 50
```

过滤逻辑简单有效：

```text
if(level < current_level)
    return
```

这适合作为所有 EA 的统一诊断标准。

## 2. CLogger 接口

公共接口包括：

- `basicConfig()`;
- `debug()`;
- `info()`;
- `warning()`;
- `error()`;
- `critical()`;
- `WriteCache()`.

EA 层可以用宏补充上下文：

```text
logger.info(msg, __FUNCTION__, __LINE__)
```

这比裸 `Print()` 更适合排查实盘问题。

## 3. Formatter

源码支持类似 Python logging 的占位符：

```text
%(asctime)s
%(levelname)s
%(programname)s
%(functionname)s
%(linenumber)d
%(programtype)s
%(message)s
```

这是全文最值得收藏的设计之一。

日志格式应该由框架配置，不应该散落在业务逻辑中。

## 4. File Rotation

`fileRotate()` 根据文件大小切换：

```text
logs.log
logs_1.log
logs_2.log
...
```

这对长期运行 EA 很关键。

没有 rotation 的日志系统最终会遇到：

- 文件过大；
- 写入变慢；
- 排查困难；
- 同步到外部工具成本高。

## 5. Cache Mode

源码支持缓存模式：

```text
cache_mode
write_cache_automatically
```

缓存模式可以减少高频 `FileWriteString()` 和 `FileFlush()` 带来的 I/O 成本。

缺点也明确：

- 崩溃时可能丢失未写入日志；
- 需要明确 flush 时机；
- 需要限制缓存上限。

## 6. FILE_COMMON

`basicConfig()` 支持：

```text
file_common = true
```

这对 MQL5 + Python 很实用：

```text
MQL5 writes logs to Common Files
Python tails / parses / archives logs
```

它可以和前面的 `File IO facade`、`CSVExporter`、`TradeJournal` 组成完整持久化链路。

## 值得收藏的内容

一级收藏：

- `CLogger` facade；
- `LogLevels` 统一等级；
- `basicConfig()` 配置入口；
- formatter placeholder 设计；
- file rotation；
- cache mode；
- destructor 自动 close / cache flush；
- `FILE_COMMON` 支持；
- `ProgramTypeToString()`。

二级收藏：

- 示例里的日志宏；
- EA / Script 使用方式；
- 文件扩展名校验。

不重点收藏：

- 演示 EA 交易逻辑；
- 具体日志文案；
- 固定宏常量本身；
- 当前实现中偏硬编码的配置。

## 不足与生产化建议

### 1. 高频日志需要节流

非缓存模式每条日志都会：

```text
FileWriteString
FileFlush
```

这很安全，但在 `OnTick()` 高频日志下成本高。

建议生产版加入：

- async-like buffer；
- batch flush；
- severity-based flush；
- rate limit；
- per-module enable / disable。

### 2. Logger 不应随意复制

源码提供 assignment operator，但只复制配置，不复制 live file handle。

框架里更建议：

```text
Logger as singleton service
or reference-owned dependency
```

不要在模块之间按值复制 logger。

### 3. Rotation 参数应配置化

当前：

```text
MAX_FILE_SIZEMB
MAX_LOG_FILES
MAX_CACHE_SIZE
```

是宏。

生产框架建议放到：

```text
LoggerConfig
```

并允许不同 EA / VPS 环境调整。

### 4. Sinks 可以继续拆分

当前 `CLogger` 同时负责：

- 格式化；
- 文件写入；
- 控制台写入；
- rotation；
- cache。

更长期的框架可以拆成：

```text
ILogger
LogFormatter
ILogSink
FileSink
ConsoleSink
RotatingFileSink
BufferedSink
```

这会比单类实现更容易扩展。

## 推荐框架结构

建议归入：

```text
Framework/
├── IO/
│   ├── File.mqh
│   └── FileIO.mqh
├── Diagnostics/
│   ├── Logger.mqh
│   ├── LogFormatter.mqh
│   ├── LogLevel.mqh
│   ├── LogSinkFile.mqh
│   └── LogRotation.mqh
└── Persistence/
    ├── CsvExporter.mqh
    └── TradeJournal.mqh
```

## 最终结论

这篇应该作为 Bootstrap 依赖链收录。

它的价值不在算法，而在工程基础设施：

```text
统一日志等级
统一日志格式
统一文件输出
统一 rotation
统一 Python / MQL5 共享日志路径
```

对于多 EA、多模块、长期 VPS 运行，这类 Logging facade 的复用价值很高。

## 标签

```text
MQL5 Bootstrap
Logging
CLogger
Diagnostics
File Rotation
FILE_COMMON
Python-like Logging
EA Framework
```
