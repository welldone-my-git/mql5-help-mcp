# Repository Pattern in MQL5：可测试 EA Analytics 架构

## 来源

- 标题：The Repository Pattern in MQL5: Abstracting Trade History Access for Testable EA Logic
- 来源：https://www.mql5.com/en/articles/22958
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-17
- 分类：MetaTrader 5 / Statistics and analysis
- 处理日期：2026-06-25

## 用户评审结论

一句话评价：

```text
这是 MQL5 官方文章里软件工程质量最高的一类文章之一，
但几乎没有量化研究价值。
```

评分：

| 项目 | 评分 |
| --- | --- |
| MQL5 语法 | ★★★★★ |
| 面向对象设计 | ★★★★★ |
| 软件架构 | ★★★★★ |
| Quant 思想 | ★ |
| 策略研究 | ★ |
| 专业 EA 开发学习价值 | 9.8/10 |
| 量化研究员学习价值 | 7.5/10 |

这篇不要重点学习胜率、回撤如何计算，而要学习：

- 分层架构
- 依赖倒置
- 依赖注入
- Repository 接口
- Mock 测试
- Analytics 与数据源解耦

## 它真正解决的问题

很多 EA 会让 analytics 代码直接调用：

- `HistorySelect()`
- `HistoryDealGetDouble()`
- `HistoryDealGetInteger()`
- `HistoryDealsTotal()`

于是出现：

```text
Analytics
  ↓
MT5 History API
  ↓
Terminal State / Broker Connection / Account History
```

表面上 `CalculateWinRate()` 像纯函数，实际依赖：

- 终端连接
- broker 历史数据
- 正确的 `HistorySelect()` 时间范围
- account state
- deal classification

这导致：

- 难以单元测试
- 难以模拟空历史、全亏损、极端 outlier 等 edge case
- 难以替换 CSV / SQLite / database 数据源
- History API 调用散落各处，维护成本高

## Repository Pattern 的核心

文章把直接依赖：

```text
EA / Analytics
↓
History API
```

改成：

```text
EA
↓
Analytics
↓
ITradeRepository
├── CLiveTradeRepository
└── CMockTradeRepository
```

这本质是：

```text
Dependency Inversion Principle
```

高层 analytics 不依赖低层 History API，而依赖抽象接口。

## 核心结构

### `STradeRecord`

统一 trade record 数据结构：

```text
ticket
open_time
close_time
open_price
close_price
volume
profit
commission
swap
symbol
direction
comment
```

价值：

- 所有 repository 和 analytics consumer 使用同一结构。
- 避免每个模块自己定义 trade record。
- 默认构造为安全空值，非法 index 时不会读垃圾内存。

### `ITradeRepository`

接口定义：

```text
GetTradeCount()
GetClosedTrade(index)
GetDailyPnL(date)
GetWinRate()
GetTotalProfit()
GetMaxDrawdown()
GetAverageTrade()
GetRepositoryType()
```

以后新增：

- CSV Repository
- SQLite Repository
- REST API Repository
- Redis Repository

只需要实现同一个接口，Analytics 不需要改。

### `CLiveTradeRepository`

数据源：

```text
MetaTrader 5 History API
```

职责：

- `HistorySelect()`
- deal enumeration
- magic filter
- entry/exit deal classification
- net PnL with commission and swap

优点是封装了所有直接 History API 访问。

### `CMockTradeRepository`

数据源：

```text
hardcoded in-memory STradeRecord array
```

价值最大。

它让以下测试无需 broker / terminal / account history：

- 空交易历史
- 全亏损交易
- 单笔极端 outlier
- 固定胜率
- 固定 drawdown
- 固定 average trade

这不是量化 backtest，而是现代软件开发里的 unit test / deterministic test。

## 最大优点：真正解耦

以前：

```text
double GetWinRate() {
  HistorySelect(...)
  HistoryDealGetDouble(...)
}
```

现在：

```text
Analytics
↓
repo.GetWinRate()
```

Analytics 不知道数据来自：

- History API
- Mock array
- CSV
- SQLite
- database
- REST service

这就是优秀架构。

## 文章值得学习的工程点

### 1. 依赖注入

EA 在初始化时决定：

```text
g_repository = use_mock ? mock_repo : live_repo
```

而不是让 analytics 自己 new 数据源。

这让测试和生产只差一个 pointer assignment。

### 2. Consumer 不关心数据源

这些模块都只依赖：

```text
ITradeRepository*
```

例如：

- `CAnalyticsEngine`
- `CEquityCurvePanel`
- Risk Manager
- Position Sizing Module

### 3. Mock Repository 支持离线测试

固定数组构造交易历史，让 analytics 输出可重复。

这对 CI / 回归测试 / 边界条件测试非常关键。

### 4. Equity Curve Panel 也依赖接口

`CEquityCurvePanel` 通过 `GetClosedTrade()` 画累计利润曲线。

它不依赖 live terminal history，因此可以用 mock data 渲染图表。

这是 UI / analytics 解耦的好例子。

## 主要问题

### 1. 重复遍历

当前设计中：

```text
GetWinRate()
  → 遍历 History

GetTotalProfit()
  → 再遍历 History

GetMaxDrawdown()
  → 第三次遍历 History

GetAverageTrade()
  → GetTradeCount() + GetTotalProfit()
```

大型系统应优化为：

```text
LoadTrades()
↓
Vector<Trade>
↓
single pass metrics
```

一次循环计算：

- trade count
- wins
- total pnl
- max drawdown
- average trade
- profit factor
- expectancy

### 2. Live Repository 每次都 `HistorySelect()`

如果每个指标方法都调用 `HistorySelect()`，会增加不必要开销。

更好的结构：

```text
Live Repository
↓
LoadHistory(from, to, magic)
↓
cache STradeRecord[]
↓
Analytics reads cached records
```

必要时：

```text
Refresh()
```

而不是每个 getter 都重新查询 terminal state。

### 3. Repository 缺少 cache 层

当前：

```text
Repository
↓
History API
↓
History API
↓
History API
```

更成熟的版本：

```text
History API
↓
TradeRepository.Load()
↓
TradeRecord[]
↓
Analytics
```

### 4. Analytics 太薄

当前 `CAnalyticsEngine` 更像 API wrapper，只是调用：

- win rate
- total profit
- average trade
- max drawdown

后续应扩展为真正的 performance analytics：

- Sharpe
- Sortino
- MAR
- Recovery Factor
- Profit Factor
- Expectancy
- Kelly
- SQN
- MAE
- MFE
- streaks
- trade duration
- exposure
- symbol-level attribution

## 对用户项目的价值

如果未来做大型 EA、Dashboard、Portfolio、Risk Engine、Execution Engine，这篇非常值得学。

建议分层：

```text
MarketData
    ↓
Repository
    ↓
Feature Engine
    ↓
Factor Engine
    ↓
Signal Engine
    ↓
Portfolio Engine
    ↓
Risk Engine
    ↓
Execution
```

每一层都应该：

- 可替换
- 可测试
- 可 mock
- 可离线验证

而不是所有逻辑耦合在一个 EA 或策略脚本里。

## 推荐改造版架构

### Repository

```text
ITradeRepository
  Load(from, to, magic)
  Refresh()
  Count()
  TradeAt(index)
```

### Analytics

```text
PerformanceAnalyzer
  Analyze(repository)
  returns PerformanceReport
```

### PerformanceReport

```text
trade_count
win_rate
total_profit
max_drawdown
profit_factor
expectancy
sharpe
sortino
avg_win
avg_loss
payoff_ratio
```

### Testing

```text
MockTradeRepository(empty)
MockTradeRepository(all_losses)
MockTradeRepository(outlier)
MockTradeRepository(known_drawdown)
```

## 和已有知识条目的关系

相关条目：

- `decorator-pattern-indicator-factor-pipeline.md`
  - Decorator 解决横切功能组合；Repository 解决数据访问解耦。
- `weekend-gap-state-machine-buffer-interface.md`
  - Signal buffer 可通过 Repository 风格接口接入 analytics。
- `inside-bar-hypothesis-research-ea.md`
  - 假设验证型 EA 需要可测试 analytics。
- `afml-microstructure-feature-pipeline-python.md`
  - Python feature pipeline 同样需要 repository/data layer。

组合起来是完整工程路线：

```text
Repository
→ Feature Pipeline
→ Signal Engine
→ Analytics
→ Risk / Execution
```

## 结论

这篇几乎没有 alpha 研究价值，但有非常高的软件工程价值。

要学的不是胜率或回撤计算代码，而是：

```text
Repository Interface
Dependency Injection
Mock Repository
Analytics/Data Access Separation
```

这些比很多具体指标实现更有长期价值。

## 标签

- MQL5
- repository pattern
- dependency inversion
- dependency injection
- testable EA
- mock repository
- live repository
- trade history
- analytics engine
- unit testing
- software architecture
- EA architecture
- performance analytics
