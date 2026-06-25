# Z-Score OOP Engine：EA / Indicator 共用的统计信号引擎

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22707>
- Title: Building an Object-Oriented Z-Score Statistical Arbitrage Engine in MQL5
- Author: Amanda Vitoria De Paula Pereira
- Date: 2026-06-08
- Category: MetaTrader 5 / Trading systems
- Local source essence: [ZScore_Source_Essence](../../examples/mql5/ZScore_Source_Essence/)

## 总体评价

| 项目 | 评分 |
|---|---|
| 交易思想 | ⭐⭐⭐☆☆ |
| MQL5 架构 | ⭐⭐⭐⭐☆ |
| 代码质量 | ⭐⭐⭐⭐☆ |
| 可复用程度 | ⭐⭐⭐⭐⭐ |
| 值得收藏 | 推荐收藏，偏 Engine / Template |

一句话总结：

> 这篇真正值得收藏的是“统计信号计算引擎与 EA / Indicator 解耦”的工程结构，而不是 Z-Score 均值回归策略本身。

## 文章核心价值

Z-Score 公式本身非常基础：

```text
Z = (Price - Mean) / StdDev
```

交易思想也不新：

```text
ZScore > +threshold  → 价格偏高，考虑做空
ZScore < -threshold  → 价格偏低，考虑做多
ZScore 回到 0 附近  → 退出
```

真正有价值的是作者把计算逻辑封装成独立引擎，使同一套 Z-Score 逻辑可以同时用于：

- 指标可视化；
- EA 自动交易；
- 后续 Feature Engine；
- 其他均值回归模块。

这比把数学计算直接写在 `OnTick()` 或 `OnCalculate()` 里更适合作为长期维护的 MQL5 基础设施。

## 建议收藏的内容

### 1. Engine 与 Indicator / EA 解耦

核心结构：

```text
CZScoreEngine
      │
      ├── Ind_ZScore_Template.mq5
      └── EA_ZScore_Template.mq5
```

引擎只负责：

- 读取价格；
- 计算均值；
- 计算标准差；
- 返回 Z-Score。

Indicator 只负责显示。

EA 只负责交易。

这是标准的职责分离。以后替换成 RSI、ATR、Entropy、Hurst、Microstructure Feature，也应该保持同样结构。

### 2. 新 K 线触发计算：Once Per Bar

EA 不应该在每个 tick 都重复计算 rolling mean / stddev。

更合理的执行方式：

```text
OnTick()
    ↓
IsNewBar()
    ↓
SignalEngine.Value(shift=1)
    ↓
Trade Logic
```

`OncePerBar.mqh` 的价值不在代码复杂度，而在它强制 EA 使用已完成 K 线，减少噪声、重绘和 Strategy Tester 的无意义 CPU 消耗。

### 3. 生命周期管理

文章示例使用动态对象：

```text
OnInit()
    new CZScore(...)

OnDeinit()
    delete CZScore
```

这点值得保留。

MQL5 没有自动垃圾回收。只要使用 `new`，就必须在 `OnDeinit()` 中配套 `delete`，并用 `CheckPointer()` 做防御检查。

这类生命周期模板可以迁移到任何需要动态对象的 EA 框架。

### 4. 数据有效性检查

Z-Score 很容易因为数据不足或零波动出错。

必须检查：

- `Bars(symbol, timeframe)` 是否足够；
- `CopyClose()` 是否返回足够数据；
- `StdDev` 是否为 0；
- 默认是否使用 `shift=1`，避免当前未完成 K 线。

这是比策略本身更重要的工程细节。

### 5. 统一接口设计

源码精华版把接口进一步抽象成：

```cpp
class ISignalEngine
  {
public:
   virtual bool   IsReady(void) const = 0;
   virtual double Value(const int shift=1) = 0;
  };
```

这比单独写 `GetZScore()` 更适合扩展。

未来可以统一为：

```text
ISignalEngine
    ├── CZScoreEngine
    ├── CRSIEngine
    ├── CATRRegimeEngine
    ├── CHurstEngine
    └── CMicrostructureEngine
```

EA 不需要知道底层特征怎么计算，只调用：

```text
engine.Value(1)
```

这是构建 MQL5 Feature Engine 的基础接口。

## 策略价值评价

Z-Score 均值回归本身只能作为 baseline。

问题：

- 强趋势中 Z-Score 可以长期极端；
- 单品种均值回归缺少协整关系支撑；
- 没有 regime filter；
- 没有波动率 / spread / liquidity 过滤；
- 固定手数不适合实盘；
- Hedging 账户下只用 `PositionSelect(_Symbol)` 不够严谨。

所以不建议把它当作完整交易系统。

更合理定位：

```text
Z-Score = 统计偏离 Feature
不是完整 Alpha
```

## 建议升级方向

### 1. Rolling Cache

当前每次计算都 `CopyClose()` 并循环计算均值和标准差。

可升级为：

```text
OnNewBar()
    ↓
Update rolling sum
Update rolling square sum
    ↓
O(1) GetZScore()
```

这样适合多品种、多周期和高频扫描。

### 2. RiskEngine

EA 模板中固定 lot 只适合作演示。

应改成：

```text
Signal
    ↓
RiskEngine
    ↓
LotSizer
    ↓
TradeExecutor
```

### 3. Regime Filter

Z-Score 均值回归必须区分趋势和震荡。

可加入：

- ADX；
- ATR regime；
- Hurst；
- Kalman slope；
- volatility filter；
- spread / liquidity filter。

### 4. Spread / execution filter

极端 Z-Score 往往出现在波动扩大时，此时点差也可能扩大。

EA 入场前应检查：

```text
Ask - Bid <= max_spread * _Point
```

### 5. FeatureEngine 化

建议最终不要保留为“ZScore 策略”，而是纳入统一 Feature Engine：

```text
FeatureEngine
    ├── ZScore
    ├── ATR
    ├── TrendSlope
    ├── Liquidity
    └── Microstructure
```

然后交给 Signal / Model / Risk 层使用。

## 源码收藏建议

建议保留：

- `SignalEngineBase.mqh`
- `ZScoreEngine_Essence.mqh`
- `OncePerBar.mqh`
- `EA_ZScore_Template.mq5`
- `Ind_ZScore_Template.mq5`

不建议重点收藏：

- 固定阈值均值回归策略本身；
- 固定手数交易逻辑；
- 缺少 Magic / ticket loop 的简单持仓管理。

## 最终结论

这篇文章的策略思想普通，但工程模板值得收藏。

它提供了一个清晰的 MQL5 信号引擎骨架：

```text
Math Engine
    ↓
统一 Value() 接口
    ↓
Indicator / EA 复用
    ↓
Once Per Bar 执行
    ↓
生命周期和数据防御检查
```

如果目标是建立个人 MQL5 量化框架，这篇适合归入：

```text
MQL5 Framework
└── Signal Engine
    └── ZScore Baseline Engine
```

收藏价值高于策略价值。

## 标签

```text
Z-Score
Mean Reversion
Signal Engine
Feature Engine
Once Per Bar
EA Indicator Shared Engine
MQL5 OOP
```
