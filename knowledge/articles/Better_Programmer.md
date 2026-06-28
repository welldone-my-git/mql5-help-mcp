# Better Programmer 系列：MQL5 工程习惯与可复用开发方法

来源：

- 作者主页：https://www.mql5.com/en/users/omegajoctan
- 作者：Omega J. Msigwa
- 核验日期：2026-06-28

## 系列定位

Better Programmer 不是交易策略系列，也不是算法系列。它更接近 MQL5 开发者的工程习惯清单：

```text
编码习惯
    ↓
开发效率
    ↓
可复用模块
    ↓
长期维护能力
```

对当前知识库的价值不在于提供可直接复用的交易代码，而在于补齐 Framework 开发中的“人和流程”层面：如何减少重复、如何建立代码片段库、如何把常用逻辑沉淀为 `.mqh` 模块、如何更快交付可维护代码。

## 已确认文章

| Part | 标题 | 链接 | 推荐 | 备注 |
|---:|---|---|---|---|
| 01 | Better Programmer (Part 01): You must stop doing these 5 things to become a successful MQL5 programmer | https://www.mql5.com/en/articles/9643 | ⭐⭐⭐⭐☆ | 系列开篇，讨论 MQL5 程序员常见坏习惯。 |
| 02 | Better Programmer (Part 02): Stop doing these 5 things to become a successful MQL5 programmer | https://www.mql5.com/en/articles/9711 | ⭐⭐⭐⭐☆ | 延续 Part 01，继续讨论开发习惯和反模式。 |
| 03 | Better Programmer (Part 03): Give Up doing these 5 things to become a successful MQL5 Programmer | https://www.mql5.com/en/articles/9746 | ⭐⭐⭐⭐☆ | 偏开发思维、职业习惯和长期成长。 |
| 04 | Better Programmer (Part 04): How to become a faster developer | https://www.mql5.com/en/articles/9752 | ⭐⭐⭐⭐☆ | 提高开发速度，适合大型 EA / Library 项目参考。 |
| 05 | Better Programmer (Part 05): How to become a faster developer | https://www.mql5.com/en/articles/9840 | ⭐⭐⭐⭐☆ | Part 04 延续，偏效率工具、流程和复用。 |
| 06 | Better Programmer (Part 06): 9 habits that lead to effective coding | https://www.mql5.com/en/articles/9923 | ⭐⭐⭐⭐⭐ | 系列最值得精读的一篇，强调可复用 `.mqh` 模块、代码片段库和工程化沉淀。 |
| 07 | Better Programmer (Part 07): Notes on becoming a successful freelance developer | https://www.mql5.com/en/articles/9995 | ⭐⭐⭐☆☆ | 偏自由职业经验，与量化框架开发关联较弱。 |

## 文章内容提炼

### Part 01：停止 5 个坏习惯

核心主题：

- 停止盲目复制粘贴；
- 不要用“hack”方式绕过问题；
- 放弃无意义的完美主义；
- 避免为了炫技写 smart code；
- 不追求最短代码，而追求清晰代码。

对框架开发的意义：

```text
短代码 != 好代码
能跑 != 可维护
复制粘贴 != 复用
```

这篇适合作为代码审查标准：凡是复制粘贴超过两次的逻辑，都应该考虑抽成函数、类或 include。

### Part 02：继续停止 5 个坏习惯

核心主题偏开发心态：

- 避免 fixed mindset；
- 不要认为自己必须永远正确；
- 放弃“一夜成功”的幻想；
- 用持续改进替代短期冲刺；
- 接受查文档、问问题和重构。

对当前项目的意义：

```text
Research Framework 是长期资产，不是一次性 EA。
```

对于 MQL5 + Python 混合平台，最容易出问题的是“能跑就不改”。这篇提醒：长期框架必须持续重构。

### Part 03：开发者协作习惯

核心主题：

- 不要执着于过去写法；
- 不要要求所有人都按自己的方式写代码；
- 不要只索取不贡献；
- 不要只信自己；
- 保持开放的学习和协作方式。

工程提炼：

- 框架规范应该写进文档，而不是靠个人习惯；
- 接口命名、目录结构、错误处理应统一；
- 允许旧模块逐步替换，不要求一次性推翻。

### Part 04：如何成为更快的开发者

核心内容：

- faster developer 不等于 faster coder；
- 避免 bug 和糟糕架构；
- 学会快速 debug；
- 正确使用标准库；
- 避免 convoluted code；
- 减少干扰；
- 阅读文档和学习；
- 用 spaced repetition 复习；
- 熟悉 MetaEditor 快捷键和环境；
- 学会高效搜索。

对 MQL5 Framework 的直接价值：

```text
开发速度主要来自：

清晰架构
    +
标准库熟练度
    +
调试流程
    +
可复用组件
```

其中“正确使用标准库”尤其重要。MQL5 标准库里的 `CTrade`、`CPositionInfo`、`CSymbolInfo`、`COrderInfo` 已经解决了大量底层问题，不应在 EA 中反复手写同类封装。

### Part 05：更快开发者的延续

核心主题：

- reflection；
- objective measurement；
- outside-of-work exploration；
- faster testing。

适合沉淀为流程：

```text
每次完成一个 EA / 模块：

1. 记录哪些函数可以复用
2. 记录哪些 bug 来源重复出现
3. 记录哪些测试步骤可以自动化
4. 把通用代码迁移到 examples 或 Include
```

这与当前知识库的 `TASKS.md` 和 `examples/` 目录定位一致。

### Part 06：9 个有效编码习惯

这是系列中最值得收藏的一篇。

文章列出的主要习惯：

- coding 前先规划；
- 建立 code snippets collection；
- 保持 routine；
- 安排 deep work；
- 写 single-purpose functions 并测试；
- 给未来的自己写注释；
- 练习 touch typing；
- 使用合适工具；
- 做 version control。

其中与本项目最相关的是：

```text
Make a collection of code snippets
    ↓
把常用函数抽成 .mqh
```

文章附件提供了 `gridmodule.mqh`，用于演示如何把 Grid EA 里常见的 position helper 抽成 include。

本仓库已收录：

- 源码目录：[examples/mql5/BetterProgrammer](../../examples/mql5/BetterProgrammer/)
- 附件源码：`gridmodule.mqh`

源码功能：

- `CGrid::InitializeModule(int magic)`：设置 Magic Number；
- `CGrid::CountPositions(ENUM_POSITION_TYPE type)`：统计当前 symbol + magic + type 的持仓数量；
- `CGrid::LastPositionOpenPrice(ENUM_POSITION_TYPE type)`：返回当前 symbol + magic + type 的最新持仓开仓价。

收藏判断：

```text
思想价值：高
源码质量：中
生产可用：低
```

它证明了“重复逻辑应该进入 include”，但 `CGrid` 本身还需要进一步泛化为 `PositionManager` / `PositionQuery` 才适合框架级复用。

### Part 07：自由职业开发者经验

核心主题：

- 不接自己不了解的工作；
- 先做 research；
- 不把过多技术负担转嫁给客户；
- 对客户少说术语，多说结果；
- 保持诚实；
- 从 clean code 开始；
- 开发者也是 problem solver；
- 选择少量长期客户。

对当前知识库价值较低，但有一个可保留观点：

```text
Clean Code 是交付质量的一部分，不是额外工作。
```

这对框架项目同样成立：代码结构、文档、示例和测试都属于交付物。

## 源码收录情况

| Part | 是否有附件源码 | 本仓库处理 |
|---:|---|---|
| 01 | 未发现附件源码 | 仅保留文章摘要 |
| 02 | 未发现附件源码 | 仅保留文章摘要 |
| 03 | 未发现附件源码 | 仅保留文章摘要 |
| 04 | 未发现附件源码 | 仅保留文章摘要，文章内代码仅作为规范讨论 |
| 05 | 未发现附件源码 | 仅保留文章摘要 |
| 06 | 有 `gridmodule.mqh` | 已收录到 `examples/mql5/BetterProgrammer/` |
| 07 | 未发现附件源码 | 仅保留文章摘要 |

## 优先级

### 必读：Part 06

Part 06 与当前 MQL5 Framework 建设最相关。重点不是具体技巧，而是开发资产化：

- 把重复代码沉淀为 `.mqh`；
- 建立可复制的代码片段库；
- 把常用模板标准化；
- 用小模块降低 EA 开发成本；
- 让未来项目复用历史项目的工程资产。

这与当前仓库目标一致：

```text
零散 EA 代码
    ↓
Reusable Include
    ↓
Framework Component
    ↓
Strategy / Research Platform
```

### 建议精读：Part 04-05

Part 04-05 主要价值在开发效率。适合提炼为项目规范：

- 常用结构模板化；
- 减少手动重复；
- 快速定位错误；
- 保持小步提交；
- 形成稳定的调试流程。

这类内容不会直接提高策略 Alpha，但会显著降低长期维护成本。

### 适合补充阅读：Part 01-03

Part 01-03 更偏反模式清单。建议作为开发习惯检查表保存：

- 不要把所有逻辑堆在一个 EA 文件；
- 不要复制粘贴后不抽象；
- 不要忽略错误处理；
- 不要只追求“能跑”，忽视可读性和可维护性；
- 不要把短期交付习惯带进长期框架。

### 可略读：Part 07

Part 07 偏 freelance developer 经验，对当前量化研究框架帮助较小。可作为职业经验材料，不作为源码收藏重点。

## 可迁移到当前框架的实践

建议从该系列提炼出以下工程规范：

```text
Framework Coding Standard
│
├── Include First
│   └── 可复用逻辑优先写成 .mqh
│
├── Snippet Library
│   └── 常用 MQL5 API / 订单 / 指标 / 文件 / 时间模板
│
├── Component Template
│   └── Init / Update / Reset / Release 生命周期
│
├── Error Handling Checklist
│   └── CopyBuffer / CopyRates / SymbolInfo / trade retcode 检查
│
├── Debugging Routine
│   └── PrintFormat / Log facade / minimal reproduction
│
└── Reuse Review
    └── 每次写新 EA 前先查已有 include 和 examples
```

## 在知识库中的分类

建议归入：

```text
Engineering Practices
    ├── MQL5 Coding Habits
    ├── Reusable Include Design
    ├── Developer Productivity
    └── Framework Maintenance
```

不要归入：

```text
Strategy
Machine Learning
Trading Signal
Risk Model
```

## 最终评价

| 维度 | 评分 |
|---|---|
| 交易策略价值 | ⭐☆☆☆☆ |
| 算法价值 | ⭐☆☆☆☆ |
| 工程习惯价值 | ⭐⭐⭐⭐☆ |
| Framework 建设价值 | ⭐⭐⭐⭐☆ |
| Part 06 收藏价值 | ⭐⭐⭐⭐⭐ |

结论：Better Programmer 系列适合作为 MQL5 Framework 开发规范的补充材料。真正值得重点沉淀的是 Part 06 中“可复用模块、代码片段库、开发资产化”的思想，而不是系列中的职业建议或泛化经验。
