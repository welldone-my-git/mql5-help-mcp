# Bootstrap Schedule

来源：

- 文章：https://www.mql5.com/en/articles/18913
- 标题：Implementing Practical Modules from Other Languages in MQL5 (Part 03): Schedule Module from Python, the OnTimer Event on Steroids
- 作者：Omega J. Msigwa

## 定位

MQL5 版 Python `schedule` 风格任务调度模块。

适合用于：

- 定时刷新数据；
- 定时同步状态；
- 定时写日志；
- 定时执行风控检查；
- 定时更新 Economic Calendar；
- 定时 flush CSV / DuckDB / Parquet bridge。

## 文件

| 文件 | 说明 |
|---|---|
| `Include/schedule.mqh` | 核心 schedule 模块。 |
| `Scripts/schedule test.mq5` | 脚本测试样例。 |
| `Experts/Schedule testing EA.mq5` | EA 中结合 timer 使用的样例。 |

## 收藏价值

这是 `core/clock.py`、runtime scheduler、MQL5 OnTimer orchestration 的参考素材。不要把它当交易策略，应该归入基础设施层。
