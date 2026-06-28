# Decorator Pattern：Indicator Pipeline Wrappers

来源：

- 文章：https://www.mql5.com/en/articles/22962
- 标题：Implementing the Decorator Pattern in MQL5: Adding Logging, Timing, and Filtering to Any Indicator Non-Invasively
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-19

## 定位

```text
Design Pattern / Indicator Wrapper / Feature Pipeline。
```

这份源码补齐了 Decorator Pattern 文章附件。真正价值是接口抽象、装饰器链和 deterministic cleanup，不是 RSI 阈值逻辑。

## 文件

| 文件 | 作用 |
|---|---|
| `IIndicator.mqh` | 统一指标接口：`GetValue(int shift)`、`GetName()` |
| `RSIIndicator.mqh` | concrete components：RSI 与 MA 指标封装，内部管理 indicator handle |
| `BaseDecorator.mqh` | 抽象 decorator，持有并拥有 wrapped `IIndicator*` |
| `LoggingDecorator.mqh` | 日志 wrapper |
| `TimingDecorator.mqh` | 耗时测量 wrapper |
| `ThresholdFilterDecorator.mqh` | 阈值过滤 wrapper |
| `CommentPanel.mqh` | chart comment panel，用于展示 raw / filtered values |
| `DecoratorPatternEA.mq5` | 示例 EA，构造多条 decorator chain 并在 `OnDeinit()` 释放 |

## 值得抽取的模块

### 1. Interface First

所有组件只暴露：

```text
GetValue(shift)
GetName()
```

EA 不需要知道当前对象是原始指标，还是被 log/timing/filter 包装后的指标。

### 2. Cross-Cutting Concerns

日志、计时、过滤不进入指标本体。

```text
Indicator Core
  ↓
Decorator Chain
  ↓
Strategy
```

这适合迁移到：

```text
Feature
  -> CacheDecorator
  -> NormalizeDecorator
  -> WinsorizeDecorator
  -> TimingDecorator
  -> LoggingDecorator
```

### 3. Ownership Chain

`CBaseDecorator` 析构时释放 wrapped object。EA 只删除最外层 decorator。

这在 MQL5 里非常关键：必须明确 owning pointer 与 observer pointer。

## 设计注意

`ThresholdFilterDecorator` 返回 `0.0` 作为 suppressed value。作为通用设计不够安全，因为 `0.0` 可能是有效值。

平台版建议返回：

```text
FeatureResult
├── value
├── valid
├── reason
└── metadata
```

## 相关知识条目

- [Decorator Pattern in MQL5：从指标包装到因子处理 Pipeline](../../../knowledge/articles/decorator-pattern-indicator-factor-pipeline.md)
