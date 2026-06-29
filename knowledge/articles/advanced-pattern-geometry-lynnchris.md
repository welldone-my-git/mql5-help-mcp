# Advanced Pattern Geometry：Wedge / Fibonacci / Head & Shoulders

来源：

- Part 63：https://www.mql5.com/en/articles/21518
- Part 65：https://www.mql5.com/en/articles/21890
- Part 66：https://www.mql5.com/en/articles/22194
- 作者：Christian Benjamin（LynnChris）
- 源码：
  - [WedgePatternDetector](../../examples/mql5/WedgePatternDetector/)
  - [FibonacciMonitor](../../examples/mql5/FibonacciMonitor/)
  - [HeadShouldersScanner](../../examples/mql5/HeadShouldersScanner/)

## 结论

这三篇应归入 Geometry / Pattern Engine，而不是策略库。

```text
Pivot / Manual Object
  ↓
Geometry Entity
  ↓
Pattern State
  ↓
Feature / Event / Signal
```

## Part 63：Wedge

值得收藏的是 OOP lifecycle：

```text
Pivot
Wedge
OverlapsWith()
UpdateStatus()
Delete()
```

这比普通函数式 pattern 检测更适合长期扩展。

## Part 65：Fibonacci Monitor

真正价值是 manual object adapter：

```text
OBJ_FIBO
  ↓
anchor points
  ↓
level ratios
  ↓
actual prices
  ↓
level monitors
```

这可以直接进入 Chart Object Event Monitor 架构。

## Part 66：Head & Shoulders

值得收藏的是 Pattern score：

```text
shoulder symmetry
time symmetry
neckline slope
ATR-normalized height
```

它把主观形态转换成可量化的 quality score，适合 Meta Labeling。

## 平台建议

统一抽象：

```text
PatternEntity
  ├── type
  ├── anchors
  ├── geometry
  ├── score
  ├── state
  └── metadata
```

统一事件：

```text
PatternEvent
  ├── detected
  ├── updated
  ├── breakout
  ├── failed
  └── expired
```

## 研究特征

```text
distance_to_neckline
pattern_score
wedge_convergence
fib_distance
fib_ratio
pattern_age
breakout_age
```

这些应作为 context features 输入 meta model，而不是直接作为交易规则。

## 收藏评分

| 模块 | 收藏价值 |
|---|---:|
| Wedge OOP lifecycle | 5/5 |
| Fibonacci object adapter | 5/5 |
| H&S scoring model | 5/5 |
| 视觉绘制细节 | 3/5 |
| 交易规则 | 2/5 |

