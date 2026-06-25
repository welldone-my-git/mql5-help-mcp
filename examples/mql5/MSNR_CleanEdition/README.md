# MSNR Clean Edition — 源码精华收藏版

来源文件：`MSNR_v531Plus_AEU1.mq5`

本版本不是原 EA 的精简可交易版，而是把其中值得长期收藏和复用的部分抽成框架：

- Signal Layer / Confluence Engine
- Price Cluster
- Session Filter
- Spread Filter
- Risk Percent LotSizer
- Drawdown Guard
- Trade Executor 骨架
- CSV Logger
- Dashboard 骨架

## 保留原则

保留：可复用架构、通用工具、风控、聚类、日志、面板、信号层接口。

删除：大量 input、Whitelist Hell、过拟合组合、视觉对象海量绘制、策略魔法数字、强绑定 XAUUSD M5 的细节。

## 推荐用法

把 `Include/MSNR_Clean/` 放进 MT5 的 `MQL5/Include/` 目录；
把 `Experts/MSNR_CleanCollector.mq5` 放进 `MQL5/Experts/` 目录。

这是收藏版/二次开发模板，不是直接实盘 EA。
