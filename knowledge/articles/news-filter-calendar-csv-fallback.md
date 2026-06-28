# News Filtering：Economic Calendar + CSV Fallback

来源：

- 文章：https://www.mql5.com/en/articles/22580
- 标题：News Filtering with MetaTrader 5 Economic Calendar and CSV Fallback
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-05-28
- 源码目录：[examples/mql5/NewsFilter](../../examples/mql5/NewsFilter/)

## 收藏结论

收藏价值：★★★★★

这篇应归类为：

```text
Event Feature / Calendar Risk Filter / Tester-Compatible News Engine
```

它不是新闻交易策略，而是把经济日历变成可复用的风控与特征模块。

## 核心价值

### 1. 官方 Calendar API + CSV fallback

live 环境可以直接用 MT5 Economic Calendar API，回测或离线环境则通过 CSV fallback 保持一致输入。

这解决了一个现实问题：

```text
Live 有新闻源
Tester 不一定有新闻源
```

因此需要：

```text
Calendar API
  ↓
Export CSV
  ↓
Tester / Replay 读取同一批事件
```

### 2. 新闻过滤不是策略，是 Risk Filter

最值得保留的接口是：

```text
IsNewsWindow()
IsPostNewsWindow()
IsHighImpactNewsToday()
```

这些函数应挂在 `RiskEngine` 或 `CalendarFeature` 上，而不是直接生成交易方向。

### 3. 事件因子化

新闻可以被转成 ML / Meta Label 特征：

```text
minutes_to_news
minutes_since_news
news_importance
news_currency_match
is_pre_news_window
is_post_news_window
is_high_impact_day
```

这比“新闻前挂双向单”更有长期研究价值。

## 平台迁移建议

```text
CalendarProvider
├── MT5CalendarProvider
├── CSVCalendarProvider
└── DuckDBCalendarProvider

NewsRiskFilter
├── quiet_period_before
├── quiet_period_after
├── importance_filter
└── currency_filter

CalendarFeatureEngine
├── event_distance
├── event_importance
└── event_context
```

## 与当前平台设计关系

映射到 Python + MT5 平台：

| 平台模块 | 对应职责 |
|---|---|
| `data/mt5` | 拉取 MT5 Calendar 或导出 CSV |
| `storage/feature_store.py` | 存储事件特征 |
| `trading/risk.py` | 新闻窗口内拒绝/降仓 |
| `research/features` | 生成 `minutes_to_news` 等特征 |
| `replay` | 使用 CSV/DuckDB 事件表保证可回放 |

## 反模式

不建议：

- 直接照搬新闻突破交易；
- 只在 live 用新闻过滤，回测不提供同源事件；
- 用 CSV 作为长期主存储；
- 把 news filter 写死在 strategy。

推荐：

```text
Strategy 只产生 SignalEvent
RiskEngine 结合 CalendarEvent 决定 allow / reduce / reject
```
