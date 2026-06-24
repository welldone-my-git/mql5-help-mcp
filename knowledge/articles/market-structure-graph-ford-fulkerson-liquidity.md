# Graph Theory / Ford-Fulkerson：把 ICT 市场结构转成图网络

## 来源

- 标题：Graph Theory: Network Flow of Commodities (Ford-Fulkerson Algorithm), Used as a Liquidity-Capacity Engine
- 作者：Hlomohang John Borotho
- 平台：MetaTrader 5 / Examples
- 发布日期：2026-06-17 19:16
- 处理日期：2026-06-25
- 来源状态：用户提供正文和代码片段，MQL5 页面 URL 待补充

## 用户评审结论

评分：

| 项目 | 评分 |
| --- | --- |
| 创新性 | ★★★★★ |
| 工程质量 | ★★★ |
| 实盘价值 | ★★ |
| 研究价值 | ★★★★★ |

总体判断：这篇比许多 MQL5 AI 文章更有意思，因为它不是简单套 LSTM / Transformer / Quantum NN，而是尝试把 ICT / SMC 市场结构量化成图网络。

但从严格数学角度看，文章使用 Ford-Fulkerson 的方式并不充分成立。真正值得学习的是：

```text
Structure → Graph
```

而不是最大流算法本身。

## 核心思想

传统 ICT / SMC 交易看：

- Fair Value Gap
- Order Block
- Liquidity Pool
- Swing High / Swing Low

这些结构通常用于判断方向，但很少量化：

```text
价格是否有足够结构动能到达目标流动性？
```

文章试图建立：

```text
Current Price
  ↓
FVG
  ↓
OB
  ↓
Swing
  ↓
Liquidity Pool
```

并把这些结构转换为图：

```text
Node:
  SOURCE
  FVG
  OB
  SWING
  LIQUIDITY
  SINK

Edge:
  capacity = f(volume, reaction, distance, structure_score)
```

最终跑 Ford-Fulkerson / Edmonds-Karp，得到一个最大流：

```text
max_flow = liquidity_capacity(current_price, target_liquidity)
```

方向仍由 ICT 条件决定，流量只作为过滤器：

```text
Structure sets direction.
Network decides capacity.
```

## 数学问题：Ford-Fulkerson 在这里退化了

Ford-Fulkerson 适用于：

```text
Source
  ↓
多条并行路径
  ↓
Sink
```

例如水管网络、道路网络、物流网络。

但文章的主要图结构更像：

```text
Source
  ↓
Node1
  ↓
Node2
  ↓
Node3
  ↓
Sink
```

这是链式路径。若只有一条路径：

```text
max_flow = min(edge_capacity)
```

例如：

```text
10 → 8 → 3 → 12
```

最大流就是：

```text
3
```

这时不需要 Ford-Fulkerson，直接计算瓶颈容量即可。

所以算法层面的结论：

```text
如果图没有真正的多路径结构，最大流算法只是复杂化的 bottleneck score。
```

## 真正值得学习的部分：市场结构图谱

文章的关键价值是把主观结构变成结构化数据。

从：

```text
FVG / OB / Liquidity / Swing 是图上画出来的东西
```

变成：

```text
GraphNode {
  type
  timestamp
  price
  priceHigh
  priceLow
}

GraphEdge {
  from
  to
  distance
  time_gap
  volume_score
  structure_score
  capacity
}
```

这一步很有价值，因为它把价格行为从“视觉分析”转成了可计算对象。

## 和 PAE / SMC 结构研究的关系

用户当前关注：

- BOS
- CHOCH
- FVG
- OB
- Liquidity
- PAE
- HMM
- Transformer State Representation

这篇提供一个重要启发：

```text
市场结构不一定只能表示成时间序列。
市场结构也可以表示成图。
```

传统序列输入：

```text
OHLCV_t-20
OHLCV_t-19
...
OHLCV_t
```

结构图输入：

```text
BOS
 ↓
FVG
 ↓
OB
 ↓
Liquidity
```

这对 SMC / ICT / 缠论 / PAE 这类结构化价格行为研究更自然。

## 可升级方向：Market Structure Graph

建议把文章思想升级为：

```text
Market Data
↓
Structure Detector
↓
Market Structure Graph
↓
Graph Features / GNN Encoder
↓
PAE / LightGBM / PPO
```

候选节点：

- BOS
- CHOCH
- FVG
- OB
- Liquidity Pool
- Swing High
- Swing Low
- Equal High / Equal Low
- Session High / Low
- Volume Shock
- Liquidity Vacuum

候选边：

- price distance
- time gap
- sequence order
- mitigation relationship
- containment relationship
- volume score
- reaction score
- liquidity score
- invalidation relation

## 代码层面问题

### 1. 容量公式主观

文章使用类似：

```text
Liquidity = 8
OB        = 5
FVG       = 4
Swing     = 3
```

这些结构分数完全是人工设定，没有统计验证。

更好的做法：

```text
capacity = learned_score(edge_features)
```

或至少用历史数据校准：

```text
edge_capacity ~ P(reach_target | edge_features)
```

### 2. Order Block 识别粗糙

文章代码里 Order Block 近似由 displacement candle 推导。

这和严格 ICT 定义仍有距离。缺少：

- mitigation
- invalidation
- liquidity sweep context
- BOS confirmation
- displacement quality
- return-to-OB behavior

### 3. FVG 识别简化

只检测三根 K 线缺口：

```text
candle1 high < candle3 low
or
candle1 low > candle3 high
```

缺少：

- partial fill
- full fill
- mitigation
- invalidation
- FVG age
- FVG width
- proximity to liquidity

### 4. MTF Flow 不是真正最大流

`ComputeMTFFlow()` 实际上是：

```text
volume ratio
+ structure count
+ distance bonus
```

拼出的启发式分数。

它没有构建多周期图，也没有跑 Ford-Fulkerson，因此不应命名为严格意义上的 multi-timeframe flow。

### 5. 图结构仍然偏链式

当前构图方式主要按 price 排序后连接相邻节点：

```text
ConnectConsecutiveNodes()
```

这会天然形成链式路径。要让图论真正有意义，需要允许：

- 多条候选路径
- 跨节点跳边
- 不同结构之间的并行 routes
- 不同 timeframe 节点融合
- 结构之间的依赖关系边

## 推荐研究改造

### Version 1：Bottleneck Score

先承认当前图是链式，直接做：

```text
path_capacity = min(edge_capacity)
```

并验证：

```text
path_capacity 是否预测 reach_liquidity？
```

### Version 2：Graph Feature Extractor

不急着做 GNN，先把图转成 tabular features：

```text
num_fvg_between_price_and_target
num_ob_between_price_and_target
nearest_liquidity_distance
min_edge_capacity
mean_edge_capacity
max_edge_capacity
structure_sequence_type
fvg_total_width
ob_reaction_score
liquidity_density
```

接：

```text
LightGBM / XGBoost
```

### Version 3：True Multi-path Graph

构建真正的多路径结构：

```text
source
 ├── FVG_A ── OB_A ── liquidity
 ├── FVG_B ── swing ─ liquidity
 └── direct_liquidity_path
```

这时 Ford-Fulkerson 才更合理。

### Version 4：GNN Encoder

最终可以考虑：

```text
Market Structure Graph
↓
GNN Encoder
↓
PAE / Return / Reach Target Prediction
```

任务定义：

```text
P(price reaches liquidity target within N bars)
P(FVG gets mitigated)
P(OB holds)
Expected MFE / MAE
PAE success probability
```

## 对用户项目的价值

如果目标是 EA，价值一般。

如果目标是：

- PAE
- HMM
- Transformer
- GNN
- BOS / CHOCH / FVG / OB / Liquidity 结构建模

价值很高。

它提供了一个重要方向：

```text
BOS / CHOCH / FVG / OB / Liquidity
↓
Graph
↓
Graph Features / GNN Encoder
↓
PAE
↓
LightGBM / PPO
```

这比文章里直接用 Ford-Fulkerson 更有研究价值。

## 和已有知识条目的关系

相关条目：

- `inside-bar-hypothesis-research-ea.md`
  - 把 Price Action pattern 视为可验证假设。
- `weekend-gap-state-machine-buffer-interface.md`
  - 把市场事件做成状态机和 EA buffer。
- `afml-microstructure-feature-pipeline-python.md`
  - 把市场信息系统化转成 feature matrix。
- `da-cg-lstm-dynamic-feature-attention.md`
  - 后续可用 attention 学习图特征权重。

这篇补上的维度：

```text
Price Action Feature
→ Event State
→ Market Structure Graph
```

## 结论

不要重点学习 Ford-Fulkerson 这个算法在文中的用法。当前构图方式下，它很可能退化为瓶颈容量分数。

真正值得学习的是：

```text
把 ICT / SMC 结构编码成图。
```

这对用户未来做 PAE、SMC 结构建模和 GNN 方向很有启发。

## 标签

- MQL5
- graph theory
- Ford-Fulkerson
- Edmonds-Karp
- ICT
- SMC
- FVG
- Order Block
- Liquidity Pool
- BOS
- CHOCH
- market structure graph
- graph features
- GNN
- PAE
- hypothesis testing
