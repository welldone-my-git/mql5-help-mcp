# News Filter：Economic Calendar + CSV Fallback

来源：

- 文章：https://www.mql5.com/en/articles/22580
- 标题：News Filtering with MetaTrader 5 Economic Calendar and CSV Fallback
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-05-28

## 定位

```text
CalendarEngine v2 / News Risk Filter。
```

这份源码不是新闻突破策略，真正价值是把 MT5 官方 Economic Calendar 封装成可复用风控过滤器，并提供 Strategy Tester 可用的 CSV fallback。

## 文件

| 文件 | 作用 |
|---|---|
| `NewsFilter.mqh` | 新闻过滤核心模块，封装日历读取、CSV fallback、新闻窗口判断和风险辅助函数 |
| `NewsEventLogger.mq5` | 将 MT5 Economic Calendar 数据导出为 CSV，供回测或离线研究使用 |
| `NewsFilterDemo.mq5` | 示例 EA，演示新闻窗口暂停交易、新闻日降风险和 dashboard 输出 |

## 值得抽取的模块

### 1. Calendar Provider

`NewsFilter.mqh` 同时支持：

- live 模式：调用 MT5 Economic Calendar API；
- tester / fallback 模式：读取 `FILE_COMMON` 下的 CSV；
- 按 symbol 推导相关 currency；
- 手工指定 currencies；
- 按 high / medium importance 过滤。

这比单纯 `CalendarValueHistory()` demo 更接近生产模块。

### 2. Quiet Period Filter

核心接口：

```text
IsNewsWindow()
IsPostNewsWindow()
IsHighImpactNewsToday()
```

用途：

- 新闻前暂停开仓；
- 新闻后等待 spread/slippage 恢复；
- 高影响新闻日降低仓位；
- 作为 `RiskEngine` 的外部事件过滤器。

### 3. CSV Fallback

MT5 Strategy Tester 不一定能稳定使用在线经济日历。该源码用 `NewsEventLogger.mq5` 先导出新闻事件，再由 `NewsFilter.mqh` 在回测中读取。

对平台设计的启发：

```text
Live Calendar API
        │
        ├── CSV / DuckDB fallback
        │
        ▼
CalendarEvent
        │
        ▼
RiskEngine / FeatureEngine
```

## 可迁移到平台的设计

建议落地为：

```text
CalendarProvider
├── MT5CalendarProvider
├── CSVCalendarProvider
└── DuckDBCalendarProvider

NewsRiskFilter
├── IsQuietPeriod()
├── RedNewsWithin()
├── ReduceRiskOnHighImpactDay()
└── NextNews()

CalendarFeature
├── minutes_to_news
├── news_importance
├── news_currency_match
└── is_news_window
```

## 与现有示例关系

仓库已有基础版：

- [Economic Calendar API](../EconomicCalendarAPI/)

本目录适合作为升级版参考：增加 CSV fallback、symbol-currency mapping 和新闻日 risk hook。

## 不建议保留的部分

- demo 中的具体交易动作；
- 把新闻过滤直接写死在 EA 主逻辑；
- 长期以 CSV 作为主存储。

长期应改为：

```text
MT5 Calendar / CSV
        ↓
DuckDB calendar_events
        ↓
Replay / Paper / Live 统一读取
```
