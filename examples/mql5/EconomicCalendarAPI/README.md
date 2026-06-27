# Economic Calendar API

来源：

- MQL5 CodeBase: https://www.mql5.com/en/code/36603
- 原始名称：`Sample detect economic calendar - expert for MetaTrader 5`
- 作者：Tungman

定位：

```text
Event Feature / Economic Calendar API 使用样例。
```

这份代码不应按新闻突破策略收藏。它真正值得保留的是 MT5 官方 Economic Calendar API 的调用方式、新闻过滤方法和事件时间处理。

## 文件

- `SampleDetectEconomicCalendar.mq5` — 原始 CodeBase EA 示例，演示检测高重要性经济新闻并在新闻前挂 Buy Stop / Sell Stop。
- `CalendarEngine.mqh` — 从原始示例提炼出的收藏版日历引擎骨架，覆盖缓存、过滤、NextNews、QuietPeriod 和 RedNews 判断。
- `CalendarEngineDemo.mq5` — 最小调用示例，只演示事件过滤和风控窗口，不执行交易。

## 值得保留的部分

### 1. 官方 Economic Calendar API

示例中直接调用 MT5 经济日历接口：

```mql5
CalendarValueHistory(value,before,end,"US",currencybase);
CalendarEventByCurrency(currencybase,ev1);
CalendarEventById(ev2,ev3);
```

可迁移方向：

- `CalendarEngine::LoadRange(from,to,country,currency)`
- `CalendarEngine::Upcoming(minutes)`
- `CalendarEngine::FilterImpact(CALENDAR_IMPORTANCE_HIGH)`
- `CalendarEngine::NextRedNews()`
- `CalendarEngine::IsQuietPeriod(minutes)`

### 2. Event Filter

原代码按重要性筛选：

```mql5
if(ev3.importance == CALENDAR_IMPORTANCE_HIGH)
```

建议升级为统一过滤器：

```text
country
currency
importance
event_id
event_name
release_time
```

后续可用于：

- 禁止开仓；
- 降低仓位；
- 扩大/收紧交易过滤；
- 生成机器学习事件特征。

### 3. 时间窗口判断

原代码在新闻前 5 分钟进入挂单逻辑：

```mql5
datetime BeforeReleaseTime = eanewsdata[i].ReleaseTime - PeriodSeconds(PERIOD_M5);

if(TimeTradeServer() > BeforeReleaseTime && TimeTradeServer() < eanewsdata[i].ReleaseTime)
```

这是新闻模块最值得复用的工程点之一。实际框架中应统一处理：

- calendar time；
- trade server time；
- broker timezone；
- local time；
- event countdown。

## 不建议直接复用的部分

- 新闻前双向挂单突破；
- 固定点数 SL/TP；
- 简化版 money management；
- `currencybase != "USD"` 的硬过滤；
- 未考虑新闻时段点差扩大、滑点、拒单和成交延迟。

## 收藏版 CalendarEngine

```text
CalendarEngine
│
├── LoadToday()
├── LoadRange(from,to)
├── GetUpcoming(minutes)
├── FilterCountry(country)
├── FilterCurrency(currency)
├── FilterImpact(importance)
├── MinutesToEvent(event)
├── IsQuietPeriod(before,after)
├── RedNewsWithin(minutes)
└── Cache()
```

本目录已落地 `CalendarEngine.mqh`，核心接口：

- `Cache(from,to,currency,country,min_importance)`
- `LoadToday(currency,country,min_importance)`
- `GetUpcoming(hours,currency,country,min_importance)`
- `FilterCountry(country_code)`
- `FilterImpact(min_importance)`
- `MinutesToEvent()`
- `IsQuietPeriod(minutes_before,minutes_after)`
- `IsRedNewsNow(minutes_before,minutes_after)`
- `RedNewsWithin(minutes_ahead)`
- `NextNews(out_event)`
- `PrintCache()`

EA 使用方式：

```mql5
#include "CalendarEngine.mqh"

CCalendarEngine Calendar;

int OnInit()
{
   EventSetTimer(60);
   Calendar.GetUpcoming(24,"USD","",CALENDAR_IMPORTANCE_HIGH);
   return INIT_SUCCEEDED;
}

void OnTimer()
{
   Calendar.GetUpcoming(24,"USD","",CALENDAR_IMPORTANCE_HIGH);
}

void OnTick()
{
   if(!Calendar.IsQuietPeriod(30,15))
      return;

   if(Calendar.RedNewsWithin(30))
      return;
}
```

## Python + MQL5 研究框架中的定位

建议把经济日历沉淀为事件因子，而不是直接新闻交易：

```text
Economic Calendar
        │
        ▼
NewsFeatureGenerator
        │
        ├── minutes_to_news
        ├── news_importance
        ├── is_red_news_window
        ├── country / currency
        └── event_type
        │
        ▼
Feature Matrix / Meta Label / Regime Filter
```

可进入 DuckDB 表：

```text
economic_calendar(
    time,
    country,
    currency,
    importance,
    event_name,
    forecast,
    previous,
    actual
)
```

收藏结论：

```text
收藏 API 和事件因子设计，不收藏原始新闻突破策略。
```
