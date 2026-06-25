# Weekend Gap Indicator

来源：

- MQL5 Article 22796：Price Action Analysis Toolkit Development (Part 71): Weekend Gap Structure Mapping in MQL5
- 源码文件：`WeekendGapIndicator.mq5`

定位：

```text
Chart Object Framework / 状态机 / Visual Layer 架构样例。
不是重点交易策略。
```

收藏重点：

- `WeekendGapRecord` Entity 结构；
- `ENUM_GAP_STATE` 状态机；
- 一个业务对象由多个 chart objects 组成；
- `CreateGapObjects()` / `UpdateGapVisuals()` / `ObjectsDeleteAll()` 生命周期；
- `VisualSettings` 外观配置；
- prefix 命名规范；
- Utility 函数：`PipSize()`、`GetWeekMonday()`、`ColorSetAlpha()`、`StateToString()`。

可迁移场景：

- FVG
- Order Block
- Supply / Demand Zone
- Liquidity Zone
- Opening Range
- Session Box
- VWAP Zone
- Manual Risk Zone

注意：

- Weekend Gap 本身不是高质量 alpha。
- 若要做交易，应增加 ATR、趋势、流动性、session、volume、news、历史回补统计等上下文特征。
