# Economic Calendar API：从新闻挂单 EA 提炼事件因子模块

来源：

- MQL5 CodeBase: https://www.mql5.com/en/code/36603
- 代码名称：Sample detect economic calendar - expert for MetaTrader 5
- 作者：Tungman

## 结论

这份代码值得收藏，但收藏理由不是交易逻辑，而是它演示了 MQL5 官方 Economic Calendar API 的最小使用路径。

核心定位：

```text
Economic Calendar API / Event Feature / Risk Filter
```

不应定位为：

```text
News Breakout Strategy
```

## 原始代码做了什么

原始 EA 的流程很短：

```text
读取经济日历
      │
筛选 High Impact 新闻
      │
判断是否接近发布时间
      │
新闻前挂 Buy Stop / Sell Stop
```

这类新闻突破逻辑实战风险较高。新闻时段通常伴随点差扩大、滑点、拒单和成交延迟，原代码没有完整处理这些执行风险。

## 真正值得收藏的部分

### 1. Economic Calendar API

代码使用了 MT5 官方经济日历接口：

```mql5
CalendarValueHistory(value,before,end,"US",currencybase);
CalendarEventByCurrency(currencybase,ev1);
CalendarEventById(ev2,ev3);
```

这些 API 可以直接支撑一套事件引擎：

- 今天是否有重要新闻；
- 未来 N 分钟是否有红色新闻；
- 当前品种相关货币是否有事件；
- 指定国家是否有 CPI、NFP、利率决议等；
- 当前是否处于新闻禁交易窗口。

### 2. 新闻事件过滤

原代码按 `importance` 过滤：

```mql5
if(ev3.importance == CALENDAR_IMPORTANCE_HIGH)
```

这可以扩展成统一事件过滤器：

```text
country
currency
importance
event_id
event_name
release_time
```

长期看，事件过滤器比新闻突破策略更有价值。

### 3. 新闻时间窗口

原代码在新闻前 5 分钟触发：

```mql5
datetime BeforeReleaseTime = eanewsdata[i].ReleaseTime - PeriodSeconds(PERIOD_M5);
```

这类时间窗口判断应抽象为：

```text
IsQuietPeriod(before_minutes, after_minutes)
RedNewsWithin(minutes)
MinutesToNextEvent()
```

EA 不应该直接散落时间比较逻辑。

## 反模式

以下部分不建议按原样收藏：

- 新闻前双向挂单；
- 固定点数 SL/TP；
- 简化版 `LotSize()`；
- 仅处理 `currencybase == "USD"`；
- 没有独立 CalendarEngine；
- 没有点差、滑点、冻结级别和拒单处理；
- 没有缓存，可能重复请求日历数据。

## 推荐重构

建议提炼为：

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
├── RedNewsWithin(minutes)
├── IsQuietPeriod(before,after)
└── Cache()
```

EA 层只使用语义接口：

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

本仓库已将该思路落地为收藏版骨架：

- `examples/mql5/EconomicCalendarAPI/CalendarEngine.mqh`
- `examples/mql5/EconomicCalendarAPI/CalendarEngineDemo.mq5`

## 在 Python + MQL5 框架中的价值

更推荐把经济日历作为事件特征进入研究系统：

```text
Economic Calendar
        │
        ▼
NewsFeatureGenerator
        │
        ├── minutes_to_news
        ├── news_importance
        ├── is_red_news_window
        ├── country
        ├── currency
        └── event_type
        │
        ▼
Feature Matrix
        │
        ▼
Meta Label / ML / Regime Filter
```

DuckDB 表可以设计为：

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

这样可以研究：

- 新闻前后 ATR 变化；
- 新闻时段 spread / slippage；
- 新闻距离对信号胜率的影响；
- Meta Label 中新闻窗口是否应该过滤交易；
- 不同事件类型对不同品种的影响。

## 收藏评分

| 模块 | 收藏价值 | 说明 |
|---|---:|---|
| Economic Calendar API | ★★★★★ | 必收藏 |
| Event Filter | ★★★★☆ | 应抽象为通用过滤器 |
| 时间窗口处理 | ★★★★☆ | 新闻模块核心工程问题 |
| 新闻突破策略 | ★★☆☆☆ | 不建议直接实盘使用 |
| Python 研究迁移 | ★★★★★ | 适合作为事件因子 |

## 最终结论

这份源码应归类为：

```text
MQL5 Infrastructure / Calendar API / Event Feature
```

而不是：

```text
Trading Strategy / News Breakout EA
```

长期价值在于建立 `CalendarEngine`，供所有 EA 做新闻过滤、风险降低和事件特征生成。
