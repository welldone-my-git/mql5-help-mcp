# Discord Notification

来源：

- 文章：https://www.mql5.com/en/articles/18550
- 标题：Sending Messages from MQL5 to Discord, Creating a Discord-MetaTrader 5 Bot
- 作者：Omega J. Msigwa

## 定位

MQL5 → Discord 通知桥。

适合用于：

- live trade alert；
- risk alert；
- daily PnL report；
- strategy exception report；
- fill / order / position 通知；
- 后续 OpenAlgo-style notification service。

## 文件

| 文件 | 说明 |
|---|---|
| `Include/Discord.mqh` | Discord webhook / message 封装。 |
| `Include/discord emojis.mqh` | emoji 常量。 |
| `Include/jason.mqh` | JSON helper。 |
| `Include/logging.mqh` | 日志 helper。 |
| `Experts/Discord EA.mq5` | 调用样例。 |

## 收藏价值

这不是策略，而是 Notification Adapter。后续可迁移为：

```text
notification/
    discord.py
    telegram.py
    email.py
    webhook.py
```
