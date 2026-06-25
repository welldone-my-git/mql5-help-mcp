# Multi-Head Attention：MQL5 神经网络架构模板

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/8909>
- Title: Neural networks made easy (Part 10): Multi-Head Attention
- Author: Dmitriy Gizlyk
- Date: 2021-03-04
- Category: MetaTrader 5 / Examples

## 收藏定位

这篇不建议按“Transformer 算法实现”收藏。

更合理的归类是：

```text
架构设计
└── AI Framework
    └── Neural Network Architecture Template
```

真正有长期价值的不是 Multi-Head Attention 公式，而是它展示了如何在 MQL5 里组织一个复杂 AI 框架：

- 抽象 Layer 接口；
- 配置驱动网络；
- Factory 创建层；
- Pipeline 化执行；
- Buffer 管理；
- OpenCL 抽象；
- 生命周期管理；
- Residual 融合；
- 模块组合。

这些设计可以迁移到 MQL5 + Python 量化框架。

## 总体评价

| 项目 | 评分 | 是否收藏 |
|---|---:|---|
| Layer 抽象 | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| 配置驱动 Topology | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| Factory 思想 | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| Pipeline 设计 | ⭐⭐⭐⭐⭐ | ✅ 必收藏 |
| Buffer 管理 | ⭐⭐⭐⭐☆ | ✅ 收藏 |
| OpenCL 封装 | ⭐⭐⭐⭐⭐ | ✅ 收藏思想 |
| Attention 算法本身 | ⭐⭐⭐☆☆ | 可不重点保留 |
| Backprop / Kernel 细节 | ⭐⭐☆☆☆ | 不建议重点收藏 |

一句话总结：

> 这篇的价值不是“如何手写 Transformer”，而是“如何用 MQL5 组织一个复杂、配置驱动、可扩展的神经网络框架”。

## 1. Layer 抽象

这是全篇最值得学习的部分。

所有网络层统一生命周期和接口：

```text
Init()
FeedForward()
CalcInputGradients()
UpdateInputWeights()
Save()
Load()
Type()
```

不同层都服从同一套接口：

```text
CNeuronBaseOCL
    ├── CNeuronConvOCL
    ├── CNeuronAttentionOCL
    └── CNeuronMHAttentionOCL
```

这点可以直接迁移到 EA 框架。

例如：

```cpp
class IFeature
  {
public:
   virtual bool Calculate(void)=0;
  };

class ISignal
  {
public:
   virtual int Predict(void)=0;
  };

class IRisk
  {
public:
   virtual bool Check(void)=0;
  };
```

重点不是神经网络，而是统一接口。

## 2. LayerDescription：配置驱动网络

作者没有把网络结构写死，而是用 `LayerDescription` 描述每一层：

```text
desc.type
desc.count
desc.window
desc.step
desc.window_out
desc.activation
desc.optimization
```

然后：

```text
Topology.Add(desc)
Net = new CNet(Topology)
```

这就是配置驱动。

对 EA 框架的启发：

```text
Config
    ↓
Factory
    ↓
Pipeline
    ↓
Run
```

不要在 EA 主文件里到处写：

```text
new TrendFilter()
new ATRFilter()
new RiskGuard()
```

更合理的是：

```text
StrategyConfig
    ├── FeatureConfig
    ├── SignalConfig
    ├── RiskConfig
    └── ExecutionConfig
```

然后由 Factory 统一创建。

## 3. Factory 思想

网络构造流程本质是：

```text
Description
    ↓
switch(type)
    ↓
new Layer
    ↓
Init()
    ↓
Add()
```

这就是 Factory。

后续可以迁移成：

```text
FilterFactory
SignalFactory
RiskFactory
ExitFactory
MoneyFactory
```

示例：

```text
ENUM_FILTER_TYPE
    FILTER_TREND
    FILTER_VOLATILITY
    FILTER_SESSION
    FILTER_SPREAD

CreateFilter(type)
```

这种结构比在 `OnTick()` 里堆 `if/else` 可维护得多。

## 4. Attention 模块化

Multi-Head Attention 不是写成一个巨大函数，而是拆成多个模块：

```text
Query
Value
Score
AttentionOut
AttentionConcatenate
Weights0
FeedForward
Residual
```

每个模块只承担一件事。

EA 框架也应该类似：

```text
Feature
    ↓
Signal
    ↓
Filter
    ↓
Risk
    ↓
Execution
    ↓
Logger
```

不要把：

```text
指标计算
信号判断
风控
下单
日志
图形显示
```

全部塞进一个函数。

## 5. FeedForward Pipeline

文章里的 forward 流程可以抽象为：

```text
Input
    ↓
Normalize
    ↓
Attention Heads
    ↓
Concatenate
    ↓
Weights0
    ↓
Residual
    ↓
FeedForward Block
    ↓
Residual
    ↓
Output
```

这是标准 Pipeline。

对交易系统的迁移：

```text
Market Data
    ↓
Normalize
    ↓
Feature Engine
    ↓
Signal Engine
    ↓
Confidence / Filter
    ↓
Risk Engine
    ↓
Trade Executor
    ↓
Logger
```

重点是每一步可替换、可测试、可追踪。

## 6. OpenCL 抽象

作者把底层 GPU 调用封装成：

```text
OpenCL.SetArgument()
OpenCL.SetArgumentBuffer()
OpenCL.Execute()
OpenCL.BufferRead()
OpenCL.BufferWrite()
```

业务层不直接关心 GPU 细节。

这点很关键。

以后接 Python / ONNX / Torch / TensorRT 时，也应保持同样抽象：

```text
InferenceEngine.Run(features, output)
```

策略层不应该知道：

- CUDA；
- Tensor memory；
- kernel launch；
- ONNX session；
- Python bridge；
- IPC 细节。

这些都应该隐藏在 Inference Adapter 里。

## 7. Buffer 抽象

文章中所有数据都通过 buffer 管理：

```text
Input
Output
Gradient
Score
AttentionOut
Concatenate
```

这比到处散落 `double[]` 更适合复杂框架。

对 EA 的启发：

```text
CFeatureBuffer
CPredictionBuffer
CSignalBuffer
CTradeStateBuffer
```

统一管理：

- 时间对齐；
- resize；
- series 方向；
- 缺失值；
- 缓存；
- 更新频率。

尤其是多品种、多周期、多因子 EA，必须避免数组到处乱传。

## 8. Kernel 职责划分

OpenCL kernel 被拆成：

```text
Normalize
AttentionScore
AttentionOut
ConcatenateBuffers
DeconcatenateBuffers
MatrixSum
Sum5Matrix
```

每个 kernel 只做一件事。

这对普通 EA 同样适用：

```text
CalculateATR()
CalculateTrend()
CalculateSignal()
CheckRisk()
ExecuteOrder()
WriteLog()
```

不要写：

```text
ProcessEverything()
```

## 9. Residual 融合思想

文章中多次使用类似：

```text
Output = Old + New
```

或平均融合：

```text
Output = 0.5 * Previous + 0.5 * NewBlock
```

这就是 Residual 的思想。

交易系统中也可以迁移为：

```text
FinalSignal =
    RuleSignal * w1
  + MLSignal   * w2
  + RegimeBias * w3
```

不要让一个新模块直接覆盖全部决策。

更稳健的方式是融合：

```text
Baseline Signal
    +
ML Adjustment
    +
Risk Penalty
```

## 10. 生命周期模板

所有 Layer 都有明确生命周期：

```text
Construct
Init
FeedForward
Backward
Update
Save / Load
Destroy
```

EA 模块也应统一生命周期：

```text
Init()
Update()
Reset()
Save()
Load()
Release()
```

这对大型 EA 很重要。

例如：

```text
FeatureEngine.Init()
SignalEngine.Init()
RiskEngine.Init()
TradeExecutor.Init()

OnTick()
    FeatureEngine.Update()
    SignalEngine.Update()
    RiskEngine.Update()
    TradeExecutor.Update()

OnDeinit()
    Release()
```

## 11. 组合优于大类

虽然 `CNeuronMHAttentionOCL` 继承自 `CNeuronAttentionOCL`，但真正有价值的是组合：

```text
MHAttention
    ├── Query Layers
    ├── Value Layers
    ├── Score Buffers
    ├── AttentionOut Layers
    ├── Concatenate Layer
    └── Weights0 Layer
```

一个复杂模块由多个小对象组合而成。

EA 也应该这样：

```text
Strategy
    ├── FeatureEngine
    ├── SignalEngine
    ├── FilterEngine
    ├── RiskEngine
    ├── PositionManager
    └── TradeExecutor
```

不要做一个几千行的超级 EA 类。

## 不建议重点收藏的内容

以下内容可以不作为长期知识资产重点保留：

- Attention 数学推导；
- Positional Encoding 公式；
- OpenCL kernel 具体代码；
- BackPropagation 实现；
- Adam 优化器实现；
- Softmax / Normalize 细节；
- 四个 Head 手写复制代码。

尤其是四个 Head 的复制实现是反例。

更现代的实现应该是：

```text
heads[]
for each head:
    RunHead(head)
```

而不是：

```text
Querys2
Querys3
Querys4
Values2
Values3
Values4
...
```

## 可迁移到个人量化框架的模板

建议长期保留以下模板思想：

```text
01 Layer 接口模板
02 Factory 工厂模板
03 配置驱动网络模板
04 Pipeline 流水线模板
05 Buffer 管理模板
06 生命周期模板
07 Residual 融合模板
08 模块化 Attention 模板
09 Inference 抽象模板
10 Neural Network Architecture 模板
```

对应到 MQL5 + Python：

```text
MQL5 EA
    ↓
Feature Buffer
    ↓
Inference Adapter
    ↓
Python / ONNX / Torch
    ↓
Prediction
    ↓
Risk Engine
    ↓
Trade Executor
```

## 最终结论

这篇文章不应该作为“Multi-Head Attention 数学实现”收藏。

它真正值得沉淀的是复杂系统架构：

```text
Interface
    ↓
Description
    ↓
Factory
    ↓
Layer / Module
    ↓
Pipeline
    ↓
Buffer
    ↓
Lifecycle
```

这套思想比 Attention 本身更适合长期复用。

如果目标是搭建自己的 MQL5 + Python 量化框架，这篇应归入：

```text
Architecture
└── AI Framework
    └── Config Driven Neural Network Pipeline
```

## 标签

```text
Multi-Head Attention
AI Framework
Layer Interface
Factory Pattern
Topology Config
Pipeline
Buffer Management
OpenCL Abstraction
Residual
Lifecycle
MQL5 Neural Network
```
