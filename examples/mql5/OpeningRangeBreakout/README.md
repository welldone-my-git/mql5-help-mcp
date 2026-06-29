# Opening Range Breakout

来源：

- 文章：https://www.mql5.com/en/articles/18486
- 标题：Price Action Analysis Toolkit Development (Part 28): Opening Range Breakout Tool
- 作者：Christian Benjamin（LynnChris）
- 源码：[ORB.mq5](./ORB.mq5)

## 定位

```text
Session Open → Range Capture → Breakout / Retest Event
```

这份源码适合作为 Session Range Feature 的基础样例。

## 可收藏点

- `CRangeCapture` 封装 opening range；
- `CATRModule` 管理 ATR handle 和 ATR-based stop / target；
- `CRetestSignal` 管理突破后的 retest 逻辑；
- `CDashboard` 独立显示状态；
- range defined 后绘制 high / low / rectangle；
- session start / reset 逻辑。

## 平台映射

```text
SessionClock
  ↓
RangeCapture
  ↓
RangeEvent
  ↓
Breakout / Retest Event
```

可迁移特征：

```text
opening_range_high
opening_range_low
opening_range_size_atr
breakout_direction
breakout_delay
retest_flag
distance_to_range_high
distance_to_range_low
```

## 不建议直接复用的部分

- ORB 策略需要按品种、session、波动 regime 做统计验证；
- 当前实现偏 chart tool；
- 生产平台应接入统一 session calendar 和 event bus。

