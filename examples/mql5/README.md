# MQL5 示例

## BreakEven Framework

路径：[BreakEven_Framework](./BreakEven_Framework/)

定位：

```text
Trade Management / BreakEven Plugin Framework 收藏样例。
```

核心学习点：

- `CBreakEvenBase` 抽象基类；
- `CBreakEvenSimple` / `CBreakEvenAtr` / `CBreakEvenRR` 多态策略；
- `CBreakEven` Manager 与 `CreateBreakEven()` Factory；
- `MqlParam[]` 统一参数系统；
- ATR handle 生命周期管理；
- ticket 级 `position_be` 状态缓存。

## Local Stop Loss EA

路径：[Local_Stop_Loss](./Local_Stop_Loss/)

定位：

```text
EA 架构收藏样例，不是重点交易策略。
```

核心学习点：

- `CHashMap<ulong,double>` 管理 ticket → stop price；
- `PositionsCheck()` 扫描仓位；
- `ProcessPosition()` / `CheckProcessedPosition()` 表达仓位状态机；
- chart object 统一命名和清理；
- helper functions 拆分业务逻辑。

## MSNR Clean Edition

路径：[MSNR_CleanEdition](./MSNR_CleanEdition/)

定位：

```text
收藏版 / 二次开发模板，不是直接实盘 EA。
```

保留模块：

- Signal Layer / Confluence Engine
- Price Cluster
- Session Filter
- Spread Filter
- Risk Percent LotSizer
- Drawdown Guard
- Trade Executor 骨架
- CSV Logger
- Dashboard 骨架

推荐导入 MT5 的方式：

```text
MQL5/Include/MSNR_Clean/
MQL5/Experts/MSNR_CleanCollector.mq5
```

单文件版：

```text
MSNR_CleanEdition/MSNR_CleanEdition_SingleFile.mq5
```

## Rolling Sharpe

路径：[RollingSharpe](./RollingSharpe/)

定位：

```text
Statistical Analytics 收藏样例，不是交易策略。
```

核心学习点：

- `CReturnBuffer.mqh` 固定长度循环缓冲；
- `m_sum` / `m_sumSq` 增量维护 rolling mean / variance；
- `CSharpeCalculator.mqh` 负责 Sharpe 与标准误计算；
- `SSharpeResult` 统一返回结果、置信带和有效标志；
- `ComputeBar()` 无状态计算适配 MT5 完整重算行为。

## Weekend Gap Indicator

路径：[WeekendGapIndicator](./WeekendGapIndicator/)

定位：

```text
Chart Object Framework / Visual State Machine 示例。
```

核心学习点：

- `WeekendGapRecord` Entity；
- `ENUM_GAP_STATE` 状态机；
- 一个业务对象由多个 chart objects 组成；
- `CreateGapObjects()` / `UpdateGapVisuals()` / `ObjectsDeleteAll()` 生命周期；
- `VisualSettings` 外观配置；
- `WG_` prefix 命名规范。

## ZScore Source Essence

路径：[ZScore_Source_Essence](./ZScore_Source_Essence/)

定位：

```text
Signal Engine / Feature Engine 收藏样例，不是完整交易策略。
```

核心学习点：

- `SignalEngineBase.mqh` 抽象统一信号接口；
- `ZScoreEngine_Essence.mqh` 把数学计算从 EA / Indicator 中拆出；
- `OncePerBar.mqh` 让 EA 每根新 K 线只执行一次；
- `CopyClose()` 返回值和零标准差保护；
- `new` / `delete` 与 `OnInit()` / `OnDeinit()` 生命周期管理。
