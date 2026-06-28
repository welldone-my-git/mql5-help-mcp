# MQL5 Bootstrap：Python Schedule 风格定时任务模块

来源：

- 文章：https://www.mql5.com/en/articles/18913
- 标题：Implementing Practical Modules from Other Languages in MQL5 (Part 03): Schedule Module from Python, the OnTimer Event on Steroids
- 作者：Omega J. Msigwa
- 本地源码：[Bootstrap_Schedule](../../examples/mql5/Bootstrap_Schedule/)

## 核心价值

这篇不是策略，而是 Runtime Scheduler 基础设施。MQL5 原生只有 `OnTimer()`，但复杂 EA 需要管理多类周期任务：

```text
Every 1 minute  -> 刷新新闻日历
Every 5 minutes -> flush logs
Every 1 hour    -> sync account snapshot
Every day       -> reset daily risk
```

Schedule 模块的价值是把 timer callback 从一堆 `if(TimeCurrent()...)` 里解放出来。

## 对 quant_platform 的映射

```text
core/clock.py
runtime/scheduler.py
MQL5 OnTimer bridge
CalendarEngine refresh
RiskEngine periodic checks
Storage flush
```

## 收藏建议

保留：

- `schedule.mqh`；
- timer orchestration 思路；
- EA / script 测试方式。

不重点保留：

- 具体 demo 交易逻辑；
- 与当前框架无关的输出细节。

结论：应作为 MQL5 Bootstrap 基础设施收录。
