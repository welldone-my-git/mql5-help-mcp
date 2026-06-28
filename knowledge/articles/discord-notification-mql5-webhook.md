# Discord Notification：MQL5 到 Discord 的通知桥

来源：

- 文章：https://www.mql5.com/en/articles/18550
- 标题：Sending Messages from MQL5 to Discord, Creating a Discord-MetaTrader 5 Bot
- 作者：Omega J. Msigwa
- 本地源码：[DiscordNotification](../../examples/mql5/DiscordNotification/)

## 核心价值

这篇的价值不在 Discord 本身，而在 Notification Adapter：

```text
Trading System
    -> Event / Alert
    -> Notification Adapter
    -> Discord / Telegram / Email / Webhook
```

对交易平台来说，通知系统是 live monitoring 的基础设施。

## 可迁移设计

建议后续抽象为：

```text
notification/
    base.py
    discord.py
    telegram.py
    webhook.py
```

事件来源：

- order accepted / rejected；
- fill；
- risk blocked；
- daily loss hit；
- strategy exception；
- broker disconnected。

## 收藏建议

保留：

- `Discord.mqh` webhook 封装；
- JSON message payload；
- emoji / formatting；
- logging integration。

不保留为核心：

- Discord 平台绑定；
- demo EA 逻辑。

结论：适合归入 OpenAlgo-style notification layer。
