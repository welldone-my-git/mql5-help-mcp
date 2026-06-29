# Fibonacci Monitor

来源：

- 文章：https://www.mql5.com/en/articles/21890
- 标题：Price Action Analysis Toolkit Development (Part 65): Building an MQL5 System to Monitor and Analyze Manually Drawn Fibonacci Levels
- 作者：Christian Benjamin（LynnChris）
- 源码：[FibonacciMonitor.mq5](./FibonacciMonitor.mq5)

## 定位

```text
Manual OBJ_FIBO → Level Entities → Event Monitor
```

这份源码与 Manual Trendline / Support Resistance 属于同一条线：把人工图表对象转成可监控结构。

## 可收藏点

- 扫描手动 `OBJ_FIBO`；
- 读取 anchor time / price；
- 读取 `OBJPROP_LEVELS`、`OBJPROP_LEVELVALUE`、`OBJPROP_LEVELTEXT`；
- 将 Fibonacci levels 转为实际价格；
- 为每个 level 创建可监控水平线；
- panel 展示对象状态；
- 可作为 manual geometry adapter 的扩展模板。

## 平台映射

```text
OBJ_FIBO
  ↓
FibonacciObject
  ↓
LevelEntity[]
  ↓
Touch / Breakout / Reaction Event
```

可迁移特征：

```text
nearest_fib_level
distance_to_fib
fib_ratio
fib_anchor_direction
fib_cluster_count
reaction_after_touch
```

## 不建议直接复用的部分

- panel UI 与核心逻辑耦合；
- level 监控仍主要通过图表对象表达；
- 没有统一 event / buffer schema；
- 生产框架应抽出 `FibonacciAdapter` 和 `LevelMonitor`。

