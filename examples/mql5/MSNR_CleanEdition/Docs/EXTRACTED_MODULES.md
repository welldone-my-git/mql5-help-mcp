# 抽取模块说明

## A级：强烈收藏

### 1. Signal Layer
把 Liquidity Sweep、Engulfing、Trendline、QML、CRT 等交易概念抽象为统一信号层。

核心思想：

```text
Detector -> SignalLayer -> Score -> Cluster -> Decision
```

### 2. Confluence Engine
不要写 `if(A && B && C)`，而是用 bit mask 记录哪些 Layer 出现，再计算信号置信度。

### 3. Price Cluster
同一区域出现多个信号时，合并成一个 Cluster，而不是重复开仓。

### 4. Risk Guard
保留风险百分比、最大点差、连续亏损暂停、最大回撤暂停。

## B级：值得收藏

- Session Filter
- CSV Logger
- Minimal Dashboard
- Trade Executor 骨架

## 删除部分

- 几十个 `WL_L1_L4_L7` 类型参数
- 大量 Momentum/Reaction 组合开关
- 过于具体的 XAUUSD M5 优化参数
- 大量 Chart Object 视觉绘制
- 策略版本号补丁式函数，例如 `xxx520/522/529/530/531`
