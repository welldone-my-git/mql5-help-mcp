# Weekend Gap Signal System：市场事件状态机与 EA Buffer 接口

## 来源

- 标题：Price Action Analysis Toolkit Development (Part 73): Building a Weekend Gap Trading Signal System in MQL5
- 来源：https://www.mql5.com/en/articles/22993
- 作者：Christian Benjamin
- 发布日期：2026-06-18
- 分类：MetaTrader 5 / Integration
- 处理日期：2026-06-23

## 用户评审结论

- 代码质量：7/10
- 工程结构：中上
- 策略实盘价值：低
- 适合学习：市场事件状态机、历史/实时一致性、Indicator → EA buffer 接口

总体判断：

```text
代码架构值得学，
交易策略不用太当真。
```

Weekend Gap 回补逻辑本身偏教学样例，不应直接拿去实盘。但文章把一个市场事件组织成状态对象、信号对象和 EA 可读 buffer 的方式值得沉淀。

## 核心架构

文章把 weekend gap 从“图表标注”扩展为一个可被 EA 消费的信号系统：

```text
Gap detection
→ GapInfo state
→ closed-bar confirmation
→ SignalRecord
→ indicator buffers
→ EA CopyBuffer()
```

重点不在 gap 策略本身，而在工程模式：

```text
市场事件
→ 状态机
→ 信号发布
→ 机器可读接口
```

## 值得学习的代码结构

### 1. `GapInfo`

`GapInfo` 保存一个 weekend gap 的完整生命周期状态。

它不是只存一个价格点，而是把 gap 作为一个持续事件：

- Monday open time
- gap upper / lower boundary
- gap direction
- gap filled state
- current week high / low
- last signal time
- signals array

这是一种好习惯：

```text
不要把事件状态散落在一堆 if 和全局变量里。
把事件封装成 state record。
```

可迁移到：

- liquidity vacuum event
- volume shock event
- breakout event
- absorption zone
- session gap
- news shock

### 2. `SignalRecord`

`SignalRecord` 把确认信号保存成结构化记录：

- signal time
- signal price
- take profit
- stop loss
- direction

这让后续渲染、buffer 回填和 EA 读取可以基于同一份记录，不需要到处重新推导。

可迁移模式：

```text
EventState
  -> SignalRecord[]
  -> Render / Publish / Export
```

### 3. `ProcessBarForGap()`

这是最值得看的函数之一。

历史扫描和实时处理都复用它：

```text
ScanHistoricalSignals()
CheckLiveSignals()
        ↓
ProcessBarForGap()
```

好处：

- 减少回测/实盘逻辑不一致。
- 统一信号确认规则。
- 减少重复代码。

这是 MQL5 指标/EA 开发里很重要的工程习惯。

### 4. `PublishSignal()`

它负责把一个确认后的交易机会发布成 `SignalRecord`，并计算 TP / SL。

这相当于信号系统里的 publishing layer：

```text
condition detected
→ publish signal object
→ later render to buffers / chart
```

建议迁移时保持这个分层，不要在检测逻辑里直接写 buffer。

### 5. `RenderSignalBuffers()`

文章把可视化和 EA 接口结合起来：

- arrow buffers：买卖信号位置
- TP / SL buffers：交易上下文
- EA 通过 `CopyBuffer()` 获取

这是非常实用的 Indicator → EA 架构：

```text
indicator computes signal
EA consumes buffer values
EA handles execution / risk / orders
```

## 非重绘意识

文章实时逻辑只处理：

```text
shift = 1
```

也就是最新已收盘 K 线，不基于正在形成的 bar[0] 生成确认信号。

这点值得保留：

```text
Signal confirmation should happen on closed bars.
```

对于实盘一致性，闭合 K 线确认比 bar[0] 内部闪烁信号更可靠。

## 主要问题

### 1. 策略逻辑偏玩具化

Weekend Gap 回补本身不是高级 alpha。它更像工程教学载体，不应因为代码完整就认为策略可交易。

需要进一步验证：

- 不同品种
- 不同 broker session
- 点差/滑点
- 交易成本
- 节假日
- OOS
- 样本外稳定性

### 2. Gap 识别依赖时间差

文章使用类似：

```text
time[i] - time[i+1] >= 172800
```

来识别周末 gap。

风险：

- broker 服务器时区不同
- DST 夏令时
- 节假日
- 非外汇品种交易时段不同
- 加密货币几乎 7x24
- 指数/商品 session 差异

更稳健做法：

```text
use trading calendar / session metadata
or explicit Friday close + Monday open detection
or per-symbol session rules
```

### 3. 性能一般

`RenderSignalBuffers()` 每次新 K 线清空所有 buffer，再用 `iBarShift()` 回填信号。

历史较短时问题不大，但在：

- 长历史
- 多品种
- 多周期
- 频繁刷新

场景下会低效。

可改进：

- 只更新新 bar 相关范围。
- 使用 signal index cache。
- 避免重复 `iBarShift()`。
- 区分 full rebuild 和 incremental update。

### 4. 风控粗糙

文章中：

- SL 用本周 high / low
- TP 用 gap 边界

缺少实盘必需因素：

- spread
- slippage
- commission
- minimum stop distance
- freeze level
- session filter
- news filter
- symbol-specific contract rules

因此只能作为信号/接口样例，不应直接作为实盘策略。

## 可迁移到项目的模式

### 市场事件状态机

建议抽象：

```text
EventState
  id
  start_time
  end_time / expiry
  boundaries
  status
  signals[]
```

适用：

- weekend gap
- liquidity vacuum
- absorption zone
- volatility expansion
- compression breakout
- volume shock

### Indicator → EA Buffer Contract

标准接口设计：

```text
BufferSignalLong
BufferSignalShort
BufferLongTP
BufferLongSL
BufferShortTP
BufferShortSL
BufferStateId
BufferConfidence
```

EA 不读图表对象，只读 buffer：

```text
CopyBuffer(indicator_handle, buffer_id, ...)
```

这样可以减少对象解析、图表依赖和视觉逻辑污染。

### 历史/实时一致性

推荐模板：

```text
ProcessBar(context, shift)

HistoricalScan:
  for closed bars:
    ProcessBar(...)

LiveUpdate:
  if new closed bar:
    ProcessBar(..., shift=1)
```

避免历史逻辑和实时逻辑各写一套。

## 后续示例候选

1. `knowledge/patterns/event-state-machine-buffer-interface.md`

沉淀通用模式：

- EventState
- SignalRecord
- ProcessBar
- PublishSignal
- RenderBuffers
- EA CopyBuffer contract

2. `examples/mql5/indicators/event-state-buffer-template/`

自研模板，不复制原文：

- 事件检测
- 信号记录
- 6-buffer EA 接口
- 非重绘 closed-bar 更新

3. `examples/mql5/ea/copybuffer-signal-consumer/`

EA 示例：

- 读取 indicator buffers
- 检查 TP / SL
- 检查 spread / stop level
- 再决定是否下单

## 与已有知识条目的关系

这篇可以作为工程模板，服务于前面沉淀的研究条目：

- `kyles-lambda-market-impact-liquidity-factor.md`
  - liquidity vacuum event 可以用 EventState 记录。
- `adaptive-kalman-smoother-regime-factor.md`
  - regime change 可以发布状态 buffer。
- `da-cg-lstm-dynamic-feature-attention.md`
  - signal/state 结果可以用 buffer 暴露给 EA。
- `mql5-objects-iii-chart-event-gui.md`
  - chart objects 负责人类可视化，buffers 负责 EA 机器接口。

## 结论

不要重点学习 weekend gap 策略本身。

重点学习：

```text
GapInfo
SignalRecord
ProcessBarForGap()
PublishSignal()
RenderSignalBuffers()
```

这些组成了一个很好的 MQL5 工程模板：

```text
把市场事件做成状态机，
再通过 indicator buffers 暴露给 EA。
```

## 标签

- MQL5
- price action
- weekend gap
- event state machine
- SignalRecord
- GapInfo
- indicator buffers
- CopyBuffer
- non-repainting
- closed bar confirmation
- EA interface
- engineering pattern
