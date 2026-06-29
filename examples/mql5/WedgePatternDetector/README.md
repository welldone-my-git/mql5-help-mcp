# Wedge Pattern Detector

来源：

- 文章：https://www.mql5.com/en/articles/21518
- 标题：Price Action Analysis Toolkit Development (Part 63): Automating Rising and Falling Wedge Detection in MQL5
- 作者：Christian Benjamin（LynnChris）
- 源码：[WedgePattern.mq5](./WedgePattern.mq5)

## 定位

```text
Pivot Stream → Wedge Entity → Breakout / Failure State
```

这份源码的价值是 OOP 形态实体和生命周期管理，而不是楔形策略本身。

## 可收藏点

- `Pivot : CObject` 把 pivot high / low 变成对象；
- `Wedge : CObject` 保存上下边界、方向、状态和图形对象名；
- `CArrayObj` 管理 pivot 和 wedge 生命周期；
- rising / falling wedge 走同一套类；
- `OverlapsWith()` 避免重复形态；
- `UpdateStatus()` 监控 breakout / failure；
- `PruneOldWedges()` 控制图表对象数量。

## 平台映射

```text
PivotDetector
  ↓
PatternEntity(Wedge)
  ↓
PatternState
  ↓
PatternEvent
```

可迁移字段：

```text
wedge_type
upper_slope
lower_slope
convergence
touch_count
pattern_age
breakout_state
failure_state
```

## 不建议直接复用的部分

- 当前版本偏视觉化指标，没有统一 signal buffer；
- pattern 规则需要统计验证；
- 图形对象和检测逻辑仍在同一文件；
- 生产框架应拆成 Detector / Entity / Renderer / EventAdapter。

