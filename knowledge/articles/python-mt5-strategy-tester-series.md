# Python-MetaTrader 5 Strategy Tester 系列：Python 研究与 RL 环境基础

来源作者：

- 作者：Omega J. Msigwa
- 作者主页：https://www.mql5.com/en/users/omegajoctan

## 系列链接

| Part | 标题 | 链接 |
|---:|---|---|
| 1 | Trade Simulator | https://www.mql5.com/en/articles/18971 |
| 2 | Bars, Ticks, and Overloading Built-in Functions | https://www.mql5.com/en/articles/20455 |
| 3 | MetaTrader 5-Like Trading Operations | https://www.mql5.com/en/articles/20782 |
| 4 | Tester 101 | https://www.mql5.com/en/articles/20917 |
| 5 | Multi-Symbols and Timeframes Strategy Tester | https://www.mql5.com/en/articles/20958 |

## 结论

这是 Omega 文章里对当前研究平台价值最高的一套。

它解决的问题：

```text
Python MetaTrader5 package 能连接终端，
但没有 Strategy Tester。
```

作者构建的是：

```text
Python MT5-like API
        │
        ▼
Trade Simulator
        │
        ▼
Bars / Ticks / Orders / Broker Constraints
        │
        ▼
Strategy Tester
        │
        ▼
Multi-Symbol / Multi-Timeframe
```

## 对当前框架的价值

这套比单个 ML 模型更重要，因为它可成为：

- factor backtest；
- ML model evaluation；
- RL environment；
- execution simulator；
- multi-asset portfolio tester；
- walk-forward engine 的底层。

## 已收录源码

- `examples/research/python-mt5-strategy-tester/part01`
- `examples/research/python-mt5-strategy-tester/part02`
- `examples/research/python-mt5-strategy-tester/part03`
- `examples/research/python-mt5-strategy-tester/part04`
- `examples/research/python-mt5-strategy-tester/part05`

## 推荐升级

```text
research/backtester/
│
├── data
├── broker
├── execution
├── portfolio
├── strategy
├── metrics
├── walkforward
└── gym_env
```

最终目标不是复刻 MT5，而是构建一个 Python-native 研究模拟器，同时保持 MT5 执行语义。
