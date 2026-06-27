# Session Boxes

来源：

- CodeBase: https://www.mql5.com/en/code/74119
- 标题：Session Boxes
- 作者：Duy Van Nguy / WazaTrader
- 文件：`DVN_Session_Boxes.mq5`
- 发布日期：2026-06-18

定位：

```text
Session Range / Chart Tool / Feature Engineering Seed。
```

## 文件

- `DVN_Session_Boxes.mq5` — 原始 CodeBase 指标，用 H1 数据绘制 Asia / London / New York session high-low box。

## 核心设计

```text
H1 rates
   │
   ▼
broker server hour → GMT hour
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

## 值得收藏

- `SessionDef` 结构；
- Asia / London / NY session 参数化；
- `InpBrokerGMTOffset` 做 server time → GMT；
- `IsHourInSession()` 支持跨午夜 session；
- 每个 session 独立计算 high / low；
- `OBJ_RECTANGLE` 作为 chart object 可视化；
- `ObjectsDeleteAll(0,prefix)` 做生命周期清理。

## 局限

- 只是可视化指标；
- 固定使用 H1；
- 没有输出 indicator buffer；
- 没有 session feature export；
- 没有统计验证；
- 没有 DST / summer time 自动处理。

## 推荐升级

```text
SessionFeatureEngine
│
├── AsiaRange()
├── LondonRange()
├── NewYorkRange()
├── BreakAsiaHigh()
├── BreakAsiaLow()
├── SweepAsiaHighThenReverse()
├── SweepAsiaLowThenReverse()
├── LondonOpenDirection()
├── NYContinuation()
└── ExportToDuckDB / CSV / Parquet
```

## Python 研究侧落点

```text
date
session
start_time
end_time
high
low
range_size
breakout_direction
sweep_high
sweep_low
false_breakout
```

收藏结论：

```text
收藏 Session Range 工程骨架，不收藏其可视化本身。
```
