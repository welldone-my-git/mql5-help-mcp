# Custom Symbols / Synthetic Markets / Stress Tests

来源：

- 文章：https://www.mql5.com/en/articles/22391
- 标题：MetaTrader 5: Build a Market to Suit Your Strategy — Renko/Range/Volume, Synthetics, and Stress Tests on Custom Symbols
- 作者：Omega J. Msigwa

定位：

```text
MQL5 Research Infrastructure / Custom Symbols / Synthetic Data / Stress Testing。
```

## 文件

- `CiCustomSymbol.mqh`
- `CBarAggregator.mqh`
- `CSyntheticTickGenerator.mqh`
- `CustomOrder.mqh`
- `CreateCustomSymbol.mq5`
- `CustomChartGenerator.mq5`
- `StressTest_SpreadModifier.mq5`

## 收藏重点

- MT5 custom symbols API；
- Renko / Range / Equal-Volume bar generation；
- synthetic tick generation；
- stress testing via spread modification；
- custom symbol → real symbol order routing wrapper。

## 适合当前框架

```text
Raw Tick / Bar
      │
      ▼
Synthetic Market Builder
      │
      ├── Renko
      ├── Range
      ├── Equal Volume
      └── Spread Stress
      │
      ▼
Strategy Robustness Test
```
