# ObjectPool

来源：

- 文章：https://www.mql5.com/en/articles/22947
- 标题：A Generic Object Pool in MQL5: Eliminating Heap Fragmentation in High-Frequency Indicators
- 作者：Ushana Kevin Iorkumbul

定位：

```text
Performance Infrastructure / Generic Object Pool。
```

## 文件

- `ObjectPool.mqh` — `CObjectPool<T>` 固定容量对象池。
- `SignalEvent.mqh` — 可池化 payload 对象示例。
- `PoolBenchmark.mq5` — pooled vs unpooled benchmark indicator。

## 核心结构

```text
Preallocate T[]
      │
Free-list index stack
      │
Acquire()
      │
Use object
      │
Release()
      │
Reset payload
```

## 值得收藏

- templated object pool；
- O(1) `Acquire()` / `Release()`；
- fixed-capacity free list；
- double-release protection；
- pool ownership flag；
- payload state 与 pool metadata 分离；
- `GetMicrosecondCount()` benchmark。

## 使用边界

适合：

- 高频 indicator；
- tick feature objects；
- event payload；
- chart object wrappers；
- transient signal records。

不适合：

- 低频 EA 的普通对象；
- 生命周期复杂且不容易 Reset 的对象；
- 需要动态容量无限扩展的场景。

## 收藏结论

这是性能基础设施，不是策略。核心价值是减少热路径 `new/delete`，提升 tick-level 稳定性。
