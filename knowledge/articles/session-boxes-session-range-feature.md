# Session Boxes：Session Range 可视化到特征工程骨架

来源：

- CodeBase: https://www.mql5.com/en/code/74119
- 标题：Session Boxes
- 作者：Duy Van Nguy / WazaTrader
- 文件：`DVN_Session_Boxes.mq5`
- 发布日期：2026-06-18

## 结论

这是一个指标，不是 EA，也不是完整策略。

价值定位：

```text
Session Range / Chart Utility / Feature Engineering Seed
```

评分：

```text
7/10，值得收藏，偏工具层。
```

## 原始功能

指标用 H1 数据绘制三大交易时段的 high-low rectangle：

- Asia；
- London；
- New York。

核心流程：

```text
CopyRates(PERIOD_H1)
      │
      ▼
server hour - broker GMT offset
      │
      ▼
GMT hour
      │
      ▼
IsHourInSession()
      │
      ▼
session high / low
      │
      ▼
OBJ_RECTANGLE
```

## 最值得收藏的代码点

### 1. Session 定义

```mql5
struct SessionDef
{
   string name;
   int    startGMT;
   int    endGMT;
   color  clr;
};
```

这是 `SessionBox` / `SessionFeature` 的雏形。

### 2. Broker time → GMT

源码通过：

```mql5
int gmtHour = dt.hour - InpBrokerGMTOffset;
```

将 broker server hour 转成 GMT hour。

局限：

- offset 需要手工配置；
- DST / summer time 未自动处理；
- 不适合跨市场长期回测直接使用。

### 3. 跨午夜 session 判断

```mql5
bool IsHourInSession(int gmtHour, int startGMT, int endGMT)
{
   if(startGMT <= endGMT)
      return (gmtHour >= startGMT && gmtHour < endGMT);
   return (gmtHour >= startGMT || gmtHour < endGMT);
}
```

这是整份代码最值得复用的函数。

### 4. Session high / low 聚合

每个 session 独立扫描 H1 bars，维护：

```text
boxHigh
boxLow
boxStart
boxEnd
active
```

这可以直接升级成：

```text
SessionRangeRecord
```

### 5. Chart Object 生命周期

源码统一 prefix：

```mql5
DVN_SB_<ChartID>_
```

并在退出时：

```mql5
ObjectsDeleteAll(0, g_prefix);
```

这是 chart utility 应保留的对象生命周期管理。

## 不值得过度研究

- 它没有交易逻辑；
- 没有 indicator buffer；
- 没有数据导出；
- 没有统计检验；
- 没有 breakout / sweep / false breakout 判断；
- 可视化代码本身价值有限。

## 推荐重构

建议抽象为：

```text
SessionBox
├── session_name
├── start_gmt
├── end_gmt
├── broker_gmt_offset
├── session_start_time
├── session_end_time
├── session_high
├── session_low
├── range_size
├── draw_rectangle()
└── is_hour_in_session()
```

更进一步：

```text
SessionFeatureEngine
├── AsiaRange()
├── LondonRange()
├── NYRange()
├── BreakAsiaHigh()
├── BreakAsiaLow()
├── SweepAsiaHighThenReverse()
├── SweepAsiaLowThenReverse()
├── LondonOpenDirection()
├── NYContinuation()
└── ExportToDuckDB / Parquet
```

## 在研究平台中的价值

MQL5 侧：

- 实时画 session box；
- 给交易员做 chart annotation；
- 给 EA 提供当前 session range 状态。

Python 侧：

- 批量生成 session high / low；
- 计算 session range size；
- 统计 Asia breakout；
- 识别 liquidity sweep；
- 生成 SMC / ICT / opening range 特征；
- 写入 DuckDB / Parquet。

推荐表结构：

```text
session_features(
    date,
    symbol,
    session,
    start_time,
    end_time,
    high,
    low,
    range_size,
    breakout_direction,
    sweep_high,
    sweep_low,
    false_breakout
)
```

## 最终判断

这份 CodeBase 应归类为：

```text
Session / Market Structure / Feature Engineering
```

而不是：

```text
Strategy / Alpha
```

它适合作为后续 Session、SMC、Liquidity、Breakout 特征工程的基础组件。
