# MTFEngine：Leak-Free Closed-Bar Multi-Timeframe Engine

来源：

- 文章：https://www.mql5.com/en/articles/22363
- 标题：Leak-Free Multi-Timeframe Engine with Closed-Bar Reads in MQL5
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-05-15

## 定位

```text
Multi-Timeframe Feature Engine / No-Repaint Indicator Handle Registry。
```

这份源码的核心不是某个指标，而是多周期指标句柄的生命周期管理，以及默认读取闭合 K 线来避免 forming-bar repaint。

## 文件

| 文件 | 作用 |
|---|---|
| `MTFEngine.mqh` | 多周期 indicator handle registry，封装创建、ready 检查、读取和释放 |
| `MTFDemo.mq5` | 示例 EA，演示多周期 MA / RSI / ATR 等读取 |
| `Index0MTF.mq5` | 反例：读取 index 0 forming bar，容易产生回测/实盘不一致 |
| `Index1MTF.mq5` | 正例：读取 index 1 closed bar，避免 repaint 和 lookahead |

## 值得抽取的模块

### 1. Handle Registry

`MTFEngine.mqh` 把每个指标 handle 包装成 registry 记录，集中管理：

- symbol；
- timeframe；
- handle；
- indicator kind；
- buffer metadata；
- release lifecycle。

这比在 EA 里散落多个 `iMA()` / `iRSI()` handle 更可维护。

### 2. Closed-Bar Read

核心原则：

```text
默认读取 bar_shift = 1
```

含义：

- `index 0` 是正在形成的 K 线，会在当前 bar 内不断变化；
- `index 1` 是上一根已闭合 K 线，更适合策略信号和回测一致性；
- 多周期特征尤其需要避免用未来未确认信息。

### 3. ReadBuffer / ReadPrevBuffer

封装 `CopyBuffer()`，避免业务代码重复处理：

- handle 是否 ready；
- buffer index；
- shift；
- copied count；
- error handling。

### 4. ReleaseAll

集中调用 `IndicatorRelease()`，防止长期运行 EA 或频繁重新初始化造成 handle 泄漏。

## 可迁移到平台的设计

建议落地为：

```text
FeatureEngine
├── IndicatorRegistry
├── MultiTimeframeSnapshot
├── ClosedBarReadPolicy
├── NoRepaintGuard
└── ReleaseLifecycle
```

Python 侧可以对应：

```text
feature_store
├── bar_close_only = true
├── timeframe_alignment
├── no_lookahead_validation
└── feature_timestamp_policy
```

## 与 Research / Replay 的关系

这篇适合纳入平台的 Feature Layer：

```text
BarEvent
   ↓
MTF Feature Snapshot
   ↓
SignalEvent
   ↓
RiskEngine
```

原则：

```text
训练、回放、实盘必须使用同一套“闭合 K 线”语义。
```

否则模型会在研究端看到未来信息，在实盘端失效。

## 不建议保留的部分

- demo 中的具体指标组合；
- 直接在 OnTick 中散落读取多个周期指标；
- 在生产信号中默认使用 `index 0`。
