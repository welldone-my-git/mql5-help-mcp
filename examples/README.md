# 示例代码库

这里保存从文章、代码片段和用户提供源码中整理出的可复用示例。

原则：

- 示例代码用于学习、二次开发和框架抽取，不默认代表可直接实盘交易。
- 第三方来源应保留原始说明、来源背景和适用边界。
- 如果后续改写为项目自有实现，应补充测试、风险说明和版本记录。

## MQL5

- [Local Stop Loss EA](./mql5/Local_Stop_Loss/) — 本地止损 EA 架构样例，重点是 HashMap 仓位缓存、Position 状态机、Chart Object 生命周期和 Cleanup 管理。
- [MSNR Clean Edition](./mql5/MSNR_CleanEdition/) — 从 `MSNR_v531Plus_AEU1.mq5` 抽取的收藏版框架模板，包含 Signal Layer、Confluence Engine、Risk Guard、Trade Executor、CSV Logger 和 Dashboard 骨架。

## Research

- [Microstructure Feature Pipeline](./research/microstructure-feature-pipeline/) — AFML Chapter 19 微观结构特征工程 Python 原型，包含 bar-level / tick-level 两层 Feature Pipeline、Numba kernels 和统一 Feature Matrix 输出。
