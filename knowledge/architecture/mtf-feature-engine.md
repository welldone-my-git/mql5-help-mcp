# MTF Feature Engine：多周期闭合 K 线特征设计

## 目标

多周期特征必须满足：

```text
研究、回放、实盘使用同一套时间可用性规则。
```

参考来源：

- [Leak-Free MTF Engine](../articles/leak-free-mtf-engine-closed-bar.md)

## 核心规则

### 1. 默认只用闭合 K 线

```text
MQL5: CopyBuffer(handle, buffer, 1, ...)
Python: feature.available_at <= decision_time
```

### 2. 高周期特征需要 available_at

例如 H1 bar 在 10:00 开始，11:00 收盘，则它的特征最早只能在 11:00 后被 M5 策略使用。

### 3. Feature Snapshot

每次策略决策应记录：

```text
symbol
decision_time
features
feature_source_time
feature_available_at
timeframe
```

## 平台接口建议

```python
class FeatureEngine:
    def build_snapshot(self, bar_event, closed_only: bool = True) -> dict: ...
```

MQL5 侧对应：

```text
IndicatorRegistry
ReadBuffer(bar_shift=1)
ReleaseAll()
```

## 反模式

- 策略信号默认使用 forming bar；
- 回测用 closed bar，实盘用 current bar；
- 多周期特征不记录来源 bar 时间；
- feature store 只存值，不存可用时间。
