# Python-MetaTrader 5 Strategy Tester

来源系列：

- Part 1：https://www.mql5.com/en/articles/18971
- Part 2：https://www.mql5.com/en/articles/20455
- Part 3：https://www.mql5.com/en/articles/20782
- Part 4：https://www.mql5.com/en/articles/20917
- Part 5：https://www.mql5.com/en/articles/20958
- 作者：Omega J. Msigwa

定位：

```text
Python Research / MT5-like Backtest Simulator / RL Environment Foundation。
```

## 目录

- `part01/` — trade simulator 基础。
- `part02/` — bars / ticks 与 MetaTrader5-like built-ins。
- `part03/` — open / close / modify orders 与 request validation。
- `part04/` — Tester 101，示例 robot、report template、tester config。
- `part05/` — multi-symbol / multi-timeframe、parallel 与 single-thread tester。

## 收藏重点

```text
MT5 terminal
   │
   ▼
Python-compatible API surface
   │
   ▼
Simulator / Tester
   │
   ▼
ML / RL / Portfolio Research
```

真正价值：

- 在 Python 中模拟 MT5 Strategy Tester；
- 保留类似 MetaTrader5 Python package 的调用体验；
- 将 symbol constraints、orders、bars、ticks 纳入模拟；
- 支持后续多品种、多周期、RL 环境和因子回测。

## 不应直接照搬

- 原始示例更多是教学框架；
- 没有完整交易成本模型；
- 没有完整 broker matching engine；
- 多线程和数据同步需要严格测试；
- RL 环境还需要 observation/action/reward/reset 标准接口。

## 推荐升级方向

```text
research/backtester/
│
├── data/
├── broker/
├── execution/
├── portfolio/
├── strategy/
├── metrics/
├── walkforward/
└── gym_env/
```
