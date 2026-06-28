# Prophet：带趋势/季节性/日历效应的预测 baseline

来源：

- 文章：https://www.mql5.com/en/articles/18549
- 标题：Data Science and ML (Part 45): Forex Time series forecasting using PROPHET by Facebook Model
- 作者：Omega J. Msigwa
- 本地源码：[prophet-forecasting](../../examples/research/prophet-forecasting/)

## 核心价值

Prophet 的优势不是高频预测，而是：

- trend；
- seasonality；
- holiday / calendar effects；
- 中低频 baseline。

结合 Economic Calendar 后，可以作为 calendar-aware forecast 参考。

## 对平台的映射

```text
research/models/baselines/prophet.py
research/features/calendar_features.py
research/regime/session_calendar.py
```

## 收藏结论

适合中低频研究和 baseline，不适合作为 intraday 高频策略核心。
