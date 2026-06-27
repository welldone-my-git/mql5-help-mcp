# CarryCostEngine

来源：

- 文章：https://www.mql5.com/en/articles/22175
- 标题：Carry Trade Logic in MQL5: Building an EA That Factors Swap Rates Into Position Sizing and Holding Decisions
- 作者：Ushana Kevin Iorkumbul

定位：

```text
Risk / Holding Cost / Carry-Aware Position Management。
```

## 文件

- `SwapTools.mqh` — swap 读取、账户货币转换、预期 swap、是否值得持有、carry-adjusted lot。
- `SwapVerify.mq5` — swap 工具验证脚本。
- `CarryDemo.mq5` — 示例 EA。

## 核心价值

很多 EA 只看价格 PnL，不看隔夜 swap。对持仓多日的策略，swap 会改变真实期望收益。

应抽象为：

```text
CarryCostEngine
│
├── DailySwapInAccountCurrency()
├── ExpectedSwapForPosition()
├── IsWorthHolding()
├── CarryAdjustedLotSize()
└── SwapDiagnostics()
```

## 值得收藏

- `SYMBOL_SWAP_LONG` / `SYMBOL_SWAP_SHORT` 读取；
- `SYMBOL_SWAP_MODE` 分支处理；
- contract size / point / tick value / tick size 换算；
- Wednesday triple swap 估算；
- 已实现 swap + 未来 swap 覆盖 price PnL；
- 根据目标 carry 占 risk 的比例调整 lot。

## 使用边界

适合：

- 趋势跟随；
- multi-day breakout；
- carry basket；
- overnight position filter；
- 中长线策略仓位调整。

不适合：

- 高频/日内策略；
- broker swap 条件频繁变化且无监控的系统；
- 未校验真实账户货币换算的粗糙风险模型。

## 收藏结论

这是 Holding Cost / Risk Engine，不是普通 carry 策略。应纳入中长线 EA 的风险与仓位层。
