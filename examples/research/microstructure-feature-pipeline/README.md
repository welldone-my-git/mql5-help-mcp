# Microstructure Feature Pipeline

来源：

- MQL5 Article 22733：Feature Engineering for ML (Part 5): Microstructural Features in Python
- 源码文件：`microstructure.py`

定位：

```text
AFML Chapter 19 微观结构特征工程 Python 原型。
```

收藏重点：

- `compute_all_microfeatures()` 统一入口；
- OHLCV Layer + Tick Layer 两层 Feature Pipeline；
- `bar_microstructure_features()` tick → bar 聚合；
- `searchsorted()` 一次性建立 tick-to-bar mapping；
- Numba `@njit` / `prange` kernel；
- Roll / Corwin-Schultz / Kyle / Amihud / Hasbrouck / VPIN；
- tick imbalance / volume imbalance / dollar imbalance / buy fraction；
- 输出统一 Feature Matrix，供 ML / IC / backtest 使用。

参考文献路线：

- AFML Chapter 19：总体框架；
- Roll / Parkinson / Beckers / Corwin-Schultz：OHLC spread 与 volatility estimator；
- Kyle / Amihud / Hasbrouck：price impact 与 illiquidity；
- Easley / López de Prado / O'Hara：PIN、VPIN、flow toxicity；
- Eisler / Tóth：order book events 与 signed order flow persistence；
- Muravyev / Cremers：options price discovery；
- O'Hara / Hasbrouck：microstructure 基础教材。

注意：

- 这是研究原型，不是可直接实盘的 EA。
- 若迁移到 MQL5，应优先保留架构：统一入口、依赖缓存、bar/tick 两层、增量更新。
- 若用于真实研究，应补充测试、数据对齐检查、IC/RankIC、OOS 和 transaction cost 分析。
