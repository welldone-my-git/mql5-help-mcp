# Better Programmer

来源：

- 作者：Omega J. Msigwa
- 作者主页：https://www.mql5.com/en/users/omegajoctan
- 文章系列：Better Programmer
- 源码来源：Part 06 附件 `gridmodule.mqh`
- 文章链接：https://www.mql5.com/en/articles/9923

## 定位

这是 Better Programmer 系列中唯一明确提供附件源码的部分。源码不是交易策略，而是为了说明：

```text
重复代码
    ↓
抽成 include
    ↓
形成可复用模块
```

对当前项目的价值主要是工程习惯示例，而不是 Grid 策略本身。

## 文件

| 文件 | 说明 |
|---|---|
| `gridmodule.mqh` | Grid EA 常见辅助模块：按 Magic / Symbol / Position Type 统计仓位数量，并获取指定方向最新持仓开仓价。 |

## 可学习点

- 把多个 EA 都会用到的函数提取到 `.mqh`；
- 用类封装 Grid 相关 helper；
- 通过 `InitializeModule(magic)` 注入 Magic Number；
- 使用 `CPositionInfo` 和 `CSymbolInfo` 标准库；
- 把主 EA 从低层 position 扫描逻辑中解耦。

## 局限

该源码适合作为 include 抽取示例，但不建议直接作为生产模块：

- `m_symbol`、`m_position` 使用全局对象，不适合大型框架；
- `Symbol()` 被写死为当前图表品种，不适合多品种 EA；
- 只支持 `ENUM_POSITION_TYPE` 过滤，扩展性有限；
- 没有返回状态和错误处理；
- 不区分 netting / hedging 的更复杂场景；
- 没有缓存，每次调用都会扫描所有 positions。

## 建议升级方向

建议重构为更通用的 Position Query 组件：

```text
CPositionQuery
│
├── SetSymbol(symbol)
├── SetMagic(magic)
├── SetType(type)
├── Count()
├── Latest()
├── Oldest()
├── TotalVolume()
└── FloatingProfit()
```

或者纳入已有：

```text
Bootstrap_TradeHelpers / PositionManager
```

## 收藏结论

保留源码作为 Better Programmer Part 06 的工程化示例。长期价值在“可复用 include 思想”，不是 `CGrid` 的具体实现。
