# Prophet Forecasting

来源：

- 文章：https://www.mql5.com/en/articles/18549
- 标题：Data Science and ML (Part 45): Forex Time series forecasting using PROPHET by Facebook Model
- 作者：Omega J. Msigwa

## 定位

Prophet 时间序列预测样例，适合 trend / seasonality / calendar effect 研究。

## 文件

| 文件 | 说明 |
|---|---|
| `Experts/Data for Prophet.mq5` | MQL5 数据导出 EA。 |
| `Scripts/OHLC + News.mq5` | OHLC + news 数据脚本。 |
| `Python/Prophet-trading-bot.py` | Prophet bot 样例。 |
| `Python/main.ipynb` | notebook 实验。 |
| `Python/Trade/` | Python-MT5 风格交易 helper。 |

## 收藏价值

适合作为 calendar-aware forecasting baseline。对 intraday 高频交易价值有限，但对中低频研究、新闻/假日效应建模有参考价值。
