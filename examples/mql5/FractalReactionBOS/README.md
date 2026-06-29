# Fractal Reaction BOS / ChoCH

来源：

- 文章：https://www.mql5.com/en/articles/19365
- 标题：Price Action Analysis Toolkit Development (Part 39): Automating BOS and ChoCH Detection in MQL5
- 作者：Christian Benjamin（LynnChris）
- 源码：[Fractal_Reaction_System.mq5](./Fractal_Reaction_System.mq5)

## 定位

```text
Fractal Pivots → Structure Break → BOS / ChoCH Event
```

这份源码适合作为市场结构事件的基础样例。价值不是交易规则，而是把 fractal high / low 转成结构突破事件。

## 可收藏点

- closed-bar `OnTick()` 扫描；
- fractal high / low 检测；
- 保存 fractal history 并剪枝；
- 维护 `os_state` 判断当前结构方向；
- 上破前高 / 下破前低后标记 BOS 或 ChoCH；
- 使用对象 prefix 管理水平结构线和文本；
- 事件通过统一 logging / alert 函数输出。

## 平台映射

```text
FractalDetector
  ↓
StructureLevel
  ↓
BOS / ChoCH Event
  ↓
Regime / Signal / Feature
```

可迁移特征：

```text
last_bos_direction
last_choch_direction
bars_since_bos
bars_since_choch
distance_to_last_structure_level
structure_state
```

## 注意

源码包含标准库 include，部分环境可能需要删除或替换不可用 include。收录价值在结构事件逻辑，不在可直接编译即用。

