# Carry Cost Engine：把 Swap 纳入持仓收益和仓位决策

来源：

- 文章：https://www.mql5.com/en/articles/22175
- 标题：Carry Trade Logic in MQL5: Building an EA That Factors Swap Rates Into Position Sizing and Holding Decisions
- 作者：Ushana Kevin Iorkumbul
- 发布时间：2026-06-09
- 附件：`SwapTools.mqh`、`SwapVerify.mq5`、`CarryDemo.mq5`

## 结论

这篇不是普通 carry strategy，而是 Holding Cost / Risk Engine 文章。

核心价值：

```text
价格 PnL + Swap PnL = 真实持仓收益
```

对日内策略价值有限；对隔夜、多日、趋势跟随、组合持仓策略很重要。

## 核心模块

```text
SwapTools.mqh
│
├── DailySwapInAccountCurrency()
├── ExpectedSwapForPosition()
├── IsWorthHolding()
├── CarryAdjustedLotSize()
└── SwapVerify()
```

## 值得收藏

- `SYMBOL_SWAP_LONG` / `SYMBOL_SWAP_SHORT`；
- `SYMBOL_SWAP_MODE`；
- contract size / point / tick value / tick size 换算；
- Wednesday triple swap；
- 已实现 swap + 未来 swap；
- 用 carry 覆盖 price PnL；
- 根据 expected carry 调整 lot。

## 使用场景

适合：

- trend following；
- swing trading；
- multi-day breakout；
- carry basket；
- overnight exposure filter；
- portfolio holding decision。

不适合：

- scalping；
- 完全日内策略；
- 未考虑 broker swap 变动的静态模型。

## 建议抽象

```text
CarryCostEngine
│
├── LongSwap(symbol)
├── ShortSwap(symbol)
├── EstimateHoldingCost(symbol,direction,lots,days)
├── NetExpectedCarry()
├── ShouldHold(ticket)
├── AdjustPositionSize()
└── Diagnostics()
```

应与：

- `RiskManager`
- `PositionManager`
- `OrderBuilder`
- `PortfolioManager`

组合，而不是单独成为交易信号。

## 示例源码

已收录：

- `examples/mql5/CarryCostEngine/SwapTools.mqh`
- `examples/mql5/CarryCostEngine/SwapVerify.mq5`
- `examples/mql5/CarryCostEngine/CarryDemo.mq5`

## 最终判断

这是中长线 EA 的底层风险模块。收藏价值高于示例策略本身。
