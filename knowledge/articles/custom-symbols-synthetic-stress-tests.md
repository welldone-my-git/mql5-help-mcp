# Custom Symbols / Synthetic Markets：用 MT5 构建研究市场和压力测试

来源：

- 文章：https://www.mql5.com/en/articles/22391
- 标题：MetaTrader 5: Build a Market to Suit Your Strategy — Renko/Range/Volume, Synthetics, and Stress Tests on Custom Symbols
- 作者：Omega J. Msigwa

## 结论

这篇不是普通图表文章，而是研究基础设施：

```text
Custom Symbols + Synthetic Bars + Stress Tests
```

## 收藏重点

- custom symbol API；
- Renko / Range / Equal-Volume bar；
- synthetic tick generator；
- spread stress test；
- stop-level / broker condition stress；
- custom symbol order routing 到真实 symbol。

## 已收录源码

- `examples/mql5/CustomSymbolsStressTests/`

## 对研究平台的价值

```text
Historical Market
      │
      ▼
Synthetic Market Transform
      │
      ▼
Stress Scenario
      │
      ▼
Strategy Robustness Test
```
