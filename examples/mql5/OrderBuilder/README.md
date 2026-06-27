# OrderBuilder

来源：

- 文章：https://www.mql5.com/en/articles/22936
- 标题：Implementing a Fluent Interface Builder Pattern for MQL5 Order Construction
- 作者：Ushana Kevin Iorkumbul

定位：

```text
Execution Layer / Fluent Order Request Builder。
```

## 文件

- `OrderBuilder.mqh` — `COrderBuilder`，封装 `MqlTradeRequest` 构造、校验、`OrderCheck()` 和 `OrderSend()`。
- `OrderBuilderDemo.mq5` — market / pending order 使用示例。

## 核心价值

原始 `MqlTradeRequest` 容易出现：

- 字段漏填；
- buy/sell 方向 SL/TP 错置；
- pending price 不合法；
- stop level 距离不足；
- 没有 `OrderCheck()` 前置；
- 交易代码散落在 EA 中。

`COrderBuilder` 将流程收敛为：

```text
Build fields
      │
Validate flags
      │
Validate cross-field consistency
      │
OrderCheck()
      │
OrderSend()
```

## 值得收藏

- pointer-based fluent chaining；
- `Symbol()` / `Volume()` / `Buy()` / `Sell()` / pending order helpers；
- `StopLoss()` / `TakeProfit()` 方向性校验；
- volume min/max/step 校验；
- broker stop-level 校验；
- `BuildRequest()` 与 `Send()` 分层。

## 推荐用法

```mql5
COrderBuilder builder;
MqlTradeResult result;

bool ok = builder.Symbol(_Symbol)
                 .Volume(0.10)
                 .Buy()
                 .StopLoss(sl)
                 .TakeProfit(tp)
                 .Magic(10001)
                 .Send(result);
```

## 收藏结论

这是 Execution Layer 的高质量模板。后续可与 `RiskManager`、`CalendarEngine`、`EventBus` 组合成完整下单管线。
