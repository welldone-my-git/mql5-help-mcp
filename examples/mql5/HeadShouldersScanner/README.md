# Head & Shoulders Scanner

来源：

- 文章：https://www.mql5.com/en/articles/22194
- 标题：Price Action Analysis Toolkit Development (Part 66): Developing a Structured Head and Shoulders Scanner in MQL5
- 作者：Christian Benjamin（LynnChris）
- 源码：[HS_Indicator.mq5](./HS_Indicator.mq5)

## 定位

```text
Swing Points → Pattern Candidate → Quality Score → Visual Pattern
```

这份源码适合作为复杂 pattern detector 的模板。它比简单形态检测更有结构化价值。

## 可收藏点

- `SwingPoint` 抽象；
- `Pattern` 保存 left shoulder、head、right shoulder、neckline、height、score；
- 支持标准 Head & Shoulders 和 inverse pattern；
- `ComputePatternScore()` 将对称性、时间间隔、neckline slope、ATR size 组合为评分；
- `GetNecklinePrice()` 把 neckline 变成可查询几何线；
- overlap / distance 过滤避免重复 pattern；
- visual layer 用 triangle + neckline 表达 pattern。

## 可迁移特征

```text
pattern_type
pattern_score
shoulder_symmetry
time_symmetry
neckline_slope
height_atr
distance_to_neckline
breakout_confirmed
```

## 不建议直接复用的部分

- `indicator_buffers 0`，没有机器执行接口；
- 规则仍需大样本验证；
- alert / visual / detector 混合；
- 应进一步接入 `PatternEvent` 和 `SignalBufferContract`。

