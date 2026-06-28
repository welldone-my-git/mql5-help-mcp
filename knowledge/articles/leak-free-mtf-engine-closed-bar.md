# Leak-Free MTF Engine：Closed-Bar Multi-Timeframe Reads

来源：

- 文章：https://www.mql5.com/en/articles/22363
- 标题：Leak-Free Multi-Timeframe Engine with Closed-Bar Reads in MQL5
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-05-15
- 源码目录：[examples/mql5/MTFEngine](../../examples/mql5/MTFEngine/)

## 收藏结论

收藏价值：★★★★☆

这篇应归类为：

```text
Feature Engine / Multi-Timeframe Indicator Lifecycle / No-Repaint Guard
```

它不是策略，而是多周期特征工程的基础设施。

## 核心价值

### 1. Indicator Handle Registry

多周期 EA 很容易在多个位置创建指标 handle，最后变成：

```text
iMA()
iRSI()
iATR()
CopyBuffer()
IndicatorRelease()
```

散落在 OnInit / OnTick / OnDeinit。

这篇用 registry 集中管理 handle 生命周期，更适合平台化。

### 2. Closed-Bar Policy

最重要原则：

```text
默认读取 index 1，而不是 index 0。
```

`index 0` 是正在形成的 bar，会导致：

- 指标值盘中变化；
- 回测看起来更好；
- 实盘信号漂移；
- 多周期信号无法复现；
- ML 训练/回放存在 lookahead 风险。

### 3. `Index0MTF` vs `Index1MTF`

附件提供两个示例：

- `Index0MTF.mq5`：forming bar 反例；
- `Index1MTF.mq5`：closed bar 正例。

这对研究框架很重要：不能只说“禁止未来函数”，必须在代码层建立默认策略。

## 平台迁移建议

```text
FeatureEngine
├── IndicatorRegistry
├── TimeframeAligner
├── ClosedBarReader
├── SnapshotBuilder
├── NoLookaheadValidator
└── ReleaseLifecycle
```

事件流：

```text
BarEvent
  ↓
FeatureEngine.build_snapshot(closed_only=True)
  ↓
SignalEvent
```

## Python 研究侧规则

同样原则也适用于 Python：

```text
feature_timestamp <= signal_timestamp
HTF feature only available after HTF bar close
no forward-fill from unfinished higher timeframe bar
```

建议在 Feature Store 中记录：

```text
feature_time
source_bar_open
source_bar_close
available_at
timeframe
```

## 不建议保留的部分

- demo 中固定的指标组合；
- 直接在 strategy 里创建/释放 indicator handle；
- 默认读取 `index 0`；
- 训练端和实盘端使用不同的 bar close 语义。
