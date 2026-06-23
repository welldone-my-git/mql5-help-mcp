# Adaptive Kalman Smoother：把 Kalman Gain 当作市场状态因子

## 来源

- 标题：A Practical Kalman Filter Price Smoother in MQL5: Adaptive Noise Estimation Without External Libraries
- 来源：https://www.mql5.com/en/articles/23016
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-22
- 分类：MetaTrader 5 / Indicators
- 处理日期：2026-06-23

## 用户评审结论

- 代码质量：7/10
- 研究思路：8/10
- 直接交易价值：4/10
- 迁移到因子研究价值：8/10

总体判断：这篇文章最值得沉淀的不是“平滑线买卖信号”，而是把自适应 Kalman Gain `Kt` 视为市场状态强度或 regime filter。

## 核心思想

传统 SMA / EMA 的权重固定，无法随市场状态调整。文章实现了一个 MQL5 原生 scalar Kalman smoother：

- 观测值：收盘价
- 隐含状态：真实价格状态
- 过程噪声 `Q_t`：由滚动收益差分方差估计
- 测量噪声 `R_t`：由滚动价格方差估计
- 自适应权重：Kalman Gain `K_t`

可迁移框架：

```text
固定参数指标
→ 自适应参数指标
→ 参数本身作为市场状态
```

这里最有用的输出不是平滑价格，而是 `K_t`：

- `K_t` 高：价格变化更像真实状态变化，趋势/突破环境更强。
- `K_t` 低：价格变化更像噪声，震荡/均值回复环境更强。

## MQL5 实现值得保留的实践

1. 指标生命周期完整

- `OnInit()` 做参数校验。
- `OnCalculate()` 区分完整重算和增量计算。
- warmup bars 明确处理。
- buffer 用途区分清楚。

2. Data Window 诊断设计

文章把 Kalman Gain 注册为 `INDICATOR_DATA`，但不在图上绘制，只在 Data Window 中显示。这是一个可复用模式：

```text
指标主线用于视觉展示
诊断/状态 buffer 用于 Data Window
```

适合迁移到：

- regime score
- signal confidence
- volatility state
- liquidity state
- risk throttle

3. 实盘指标的增量计算细节

`prev_calculated > 0` 时从 `prev_calculated - 1` 开始重算，用于覆盖当前未收盘 bar 的变化。这是实盘指标中重要的细节，避免当前 bar 不刷新。

4. 数值保护

- 参数下限检查。
- warmup 期间输出 `EMPTY_VALUE`。
- `Q_t` / `R_t` 设置最小 floor，避免除零。
- 方差计算出现微小负值时 clamp 到 0。

## 主要缺点和改进方向

1. 滚动方差复杂度

当前每根 bar 重新循环窗口，复杂度为 `O(window)`。窗口 10–50 时可以接受，但不是最优。

可改进：

- 维护 rolling sum / rolling sum of squares。
- 或使用增量方差算法。
- 对较大窗口、批量优化或多品种扫描时应优化。

2. 方差公式存在数值抵消风险

文章使用 `E[x²] - E[x]²`。这会在低波动区间产生数值抵消，作者用负值 clamp 修正，但这只是保护，不是最稳方案。

可改进：

- Welford online variance。
- two-pass variance。
- compensated summation。

3. 缺少严格交易验证

文章主要评估平滑误差、滞后、抖动等指标，没有证明其直接收益预测价值。

结论：不应直接当买卖指标使用。

## 推荐用法：作为 regime filter / 因子输入

不要把 Kalman smoother 线直接作为买卖信号。更有价值的用法是把 `K_t` 作为状态因子。

### 方向一：动量 / 反转切换

```text
if Kt 高:
  动量因子权重提高
  突破信号允许交易

if Kt 低:
  动量因子降权
  反转/均值回复因子允许交易
```

### 方向二：结合异常成交额相关性

用户已有研究方向：“异常时刻成交额相关性”。可组合为：

```text
regime_score =
  Kalman Gain Kt
  × 成交额异常相关性
  × 流动性状态
```

解释：

- `Kt`：价格变动是否更像真实状态变化。
- 成交额异常相关性：变化是否有资金行为支持。
- 流动性状态：是否有足够成交质量支撑执行。

### 方向三：信号置信度调节

```text
signal_weight = base_signal * regime_confidence(Kt)
position_size = base_size * risk_throttle(Kt, liquidity_state)
```

`Kt` 不直接决定方向，只调节已有信号是否生效、权重多大。

## 适合沉淀成项目能力的内容

### 最佳实践条目

- 指标诊断 buffer：`INDICATOR_DATA + DRAW_NONE / clrNONE`
- `prev_calculated - 1` 重算当前 bar
- warmup 期间输出 `EMPTY_VALUE`
- 自适应参数不要直接等同交易信号

### 后续示例候选

1. `examples/indicators/adaptive-kalman-regime/`

自研版本，不复制原文代码：

- 输出 Kalman smoother
- 输出 Kalman Gain
- 输出 regime label：trend-like / noise-like
- 使用更稳的方差计算

2. `examples/strategies/regime-filtered-momentum/`

策略模板：

- 动量信号作为 base signal
- `Kt` 高时允许动量
- `Kt` 低时空仓或切换反转逻辑
- 明确标注为研究模板，不宣称盈利

3. `knowledge/patterns/indicator-diagnostics.md`

沉淀 MQL5 指标工程最佳实践：

- buffer 注册
- Data Window 输出
- warmup
- 增量计算
- 数值 floor

## 标签

- MQL5
- indicator
- Kalman filter
- adaptive parameter
- regime filter
- market state
- Data Window
- buffer
- OnCalculate
- factor research
