# Local Stop Loss EA：用 HashMap 和对象管理构建 EA Framework

## 来源

- 标题：Local Stop Loss EA
- 来源状态：用户提供本地源码文件 `Local_Stop_Loss.mq5`
- 示例路径：[examples/mql5/Local_Stop_Loss/Local_Stop_Loss.mq5](/home/novo/quant/github/welldone-my-git/mql5-help-mcp/examples/mql5/Local_Stop_Loss/Local_Stop_Loss.mq5)
- 处理日期：2026-06-25

## 用户评审结论

总评：

```text
8.8/10，值得收藏。
它不是交易策略文章，而是 EA 架构文章。
```

评分：

| 项目 | 评分 | 是否收藏 |
| --- | --- | --- |
| 架构设计 | ★★★★★ | 必收藏 |
| MQL5 OOP 写法 | ★★★★★ | 必收藏 |
| 数据结构应用 | ★★★★★ | 必收藏 |
| 风控思路 | ★★★★☆ | 推荐 |
| 交易策略 | ★★☆☆☆ | 一般 |
| 数学算法 | ★☆☆☆☆ | 没有 |

真正值得学的不是 local stop，而是：

```text
大型 MQL5 EA 的工程组织方式。
```

## 核心架构

程序结构接近标准 EA 模板：

```text
OnInit()
  ↓
初始化参数、交易对象、图表状态

OnTick()
  ↓
调度 PositionsCheck()

PositionsCheck()
  ↓
遍历当前仓位
  ↓
ProcessPosition() / CheckProcessedPosition()
  ↓
CleanupPosition()
```

可以抽象成：

```text
Engine
  ↓
PositionManager
  ↓
RiskManager
  ↓
ObjectManager
  ↓
TradeManager
```

最值得收藏的是这套职责拆分，而不是本地止损逻辑本身。

## 最重要的设计：HashMap 管理仓位状态

源码使用：

```text
CHashMap<ulong, double> gblOpenPositions
```

保存：

```text
ticket → local stop price
```

核心操作：

- `ContainsKey()`
- `TryGetValue()`
- `TrySetValue()`
- `Remove()`
- `CopyTo()`

这比数组线性查找更适合仓位状态缓存。

复杂度：

```text
HashMap lookup: O(1)
ArraySearch:    O(n)
```

在几十仓、几百仓、复杂面板对象同步时，差距会变明显。

## 状态机思想

仓位被分为两种状态：

```text
New Position
  ↓
ProcessPosition()

Processed Position
  ↓
CheckProcessedPosition()
```

代码没有把所有逻辑塞进一个巨大的 if 链，而是用缓存判断状态：

```text
if(gblOpenPositions.ContainsKey(ticket))
  CheckProcessedPosition()
else
  ProcessPosition()
```

这是一个简单但有效的 position lifecycle state machine。

## 对象管理

对象命名统一：

```text
csl_<ticket>_open
csl_<ticket>_line
csl_<ticket>_spacer
```

封装函数：

- `GetOpenName(ticket)`
- `GetCslName(ticket)`
- `GetSpacerName(ticket)`
- `CleanupPositionObjects(ticket)`
- `CleanupPosition(ticket)`

优势：

- 不在业务逻辑里散落 `ObjectDelete()`；
- 删除一组对象只需传入 ticket；
- 对象和仓位生命周期保持一致；
- 以后可迁移到 dashboard、signal marker、grid、trailing stop 等场景。

## Helper 函数拆分

值得保留的 helper：

- `GetStopDistance()`
- `GetCslPrice()`
- `GetOpenName()`
- `GetCslName()`
- `GetSpacerName()`
- `GetOpenLabel()`
- `DrawSpacer()`
- `CleanupPosition()`

效果：

```text
ProcessPosition()
CheckProcessedPosition()
```

保持可读，不膨胀成几百行。

这是可维护 EA 的基本纪律。

## OnInit / OnTick 职责划分

`OnInit()`：

- input validation；
- magic number 设置；
- stop distance 计算；
- chart trade label 状态同步；
- 对已有仓位执行一次 `PositionsCheck()`。

`OnTick()`：

- 检查 chart show levels 状态变化；
- 调用 `PositionsCheck()`。

核心评价：

```text
OnTick() 只调度，不承载复杂业务逻辑。
```

这点非常值得收藏。

## CPositionInfo 的使用价值

源码使用：

```text
CPositionInfo posInfo;
posInfo.SelectByIndex(i)
posInfo.Symbol()
posInfo.Ticket()
posInfo.PriceOpen()
posInfo.PositionType()
```

比裸写：

```text
PositionSelect()
PositionGetInteger()
PositionGetDouble()
```

可读性更好，也更适合拆成 PositionManager。

## Chart Object 同步机制

源码保持三类状态同步：

```text
MT5 positions
  ↔
HashMap cache
  ↔
Chart objects
```

主要流程：

1. 扫描当前仓位，加入 `curPositions`；
2. 如果 ticket 不在 cache，创建对象并加入 cache；
3. 如果 ticket 在 cache，检查对象是否存在、stop 是否触发；
4. 已平仓但仍在 cache 的 ticket，执行 cleanup；
5. 用户拖动 local stop line 后，同步 HashMap 中的 stop price。

这套机制可以迁移到：

- trailing stop line；
- manual risk line；
- grid level；
- signal marker；
- dashboard row；
- replay annotation。

## 不值得重点收藏的部分

### 1. Spacer

`DrawSpacer()` 只是视觉辅助线。

可学对象封装方式，但实战模板里可以删除。

### 2. Local Stop 策略本身

Local Stop 的问题：

- 依赖终端在线；
- EA 停止则保护失效；
- 网络断开则不能执行；
- VPS / terminal 崩溃时无法替代 server SL。

如果是真实账户，至少应考虑：

```text
server stop as fail-safe
local stop as hidden / visual / override layer
```

### 3. UI 标签和颜色

`Label`、`Description`、颜色、spacer 等不是核心，可在精简模板中删除。

## 需要改进的地方

### 1. Magic Number 过滤

源码设置了：

```text
Trade.SetExpertMagicNumber(InpMagicNumber)
```

但 `PositionsCheck()` 只过滤了 symbol：

```text
if(posInfo.Symbol() != Symbol())
  continue;
```

建议补充：

```text
if(posInfo.Magic() != InpMagicNumber)
  continue;
```

否则可能管理同品种下其他 EA 或手工仓位。

### 2. Trade result 检查不足

触发本地止损时：

```text
Trade.PositionClose(ticket)
CleanupPosition(ticket)
```

应检查 close 是否成功。

更安全：

```text
if(Trade.PositionClose(ticket))
  CleanupPosition(ticket)
else
  log retcode / keep state
```

否则下单失败但对象和 cache 被清理，状态会失真。

### 3. Tick 获取失败未处理

`SymbolInfoTick()` 应检查返回值。

否则异常行情或符号状态异常时可能读取无效 tick。

### 4. Stop distance 对不同品种不够通用

当前：

```text
pips = 0.0001
yen pips = 0.01
points = raw
```

这对 Forex 可以，但对指数、黄金、加密、期货不通用。

建议改成：

```text
point / tick_size based conversion
```

或要求统一用 points。

## 精简后最值得保留的模块

建议抽成：

```text
LocalStopFramework
├── EA Framework
├── PositionManager
├── HashMapPositionCache
├── PositionStateMachine
├── ChartObjectManager
├── CleanupManager
├── HelperFunctions
├── InputValidation
└── TradeWrapper
```

删除：

- spacer；
- UI 颜色；
- label description；
- 演示型 chart object 细节。

最后可以变成约 220–300 行的 EA 工程模板。

## 与本项目已有知识的关系

适合归类到：

```text
EA Framework
```

可和以下条目组合：

- Fluent Order Builder：下单请求构造；
- Repository Pattern：历史交易数据访问；
- Object Pool：热路径对象管理；
- Universal Breakout Study：策略研究框架；
- MSNR Clean Edition：Signal/Cluster/Risk/Logger 框架；
- Decorator Pattern：日志、计时、过滤横切能力；
- G Channel / DSU Signal：信号层模块。

组合后的长期 EA 架构：

```text
SignalEngine
  ↓
PositionManager
  ↓
RiskManager
  ↓
TradeExecutor
  ↓
ObjectManager
  ↓
Repository / Logger / Dashboard
```

## 最终结论

`Local_Stop_Loss.mq5` 不是因为 local stop 策略值得收藏，而是因为它展示了：

- 清晰的 EA 生命周期；
- position state machine；
- HashMap 状态缓存；
- chart object 生命周期管理；
- helper function 拆分；
- cleanup discipline。

一句话沉淀：

```text
Local Stop Loss 的交易思想一般，
但它是一份很好的 MQL5 EA Framework 教材。
```

## 标签

- MQL5
- Expert Advisor
- EA Framework
- Local Stop Loss
- HashMap
- Position Manager
- Object Manager
- Cleanup Manager
- State Machine
- Chart Object
