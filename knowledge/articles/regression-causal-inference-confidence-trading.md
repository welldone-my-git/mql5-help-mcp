# Regression + Causal Inference Trading Pipeline：收益回归与可信度过滤

## 来源

- 标题：Exploring Regression Models for Causal Inference and Trading
- 来源：https://www.mql5.com/en/articles/18603
- 作者：原文作者已删除账号，英文版由 MetaQuotes 翻译自俄文
- 发布日期：2026-06-10
- 分类：MetaTrader 5 / Integration
- 附件：`MQL5_files.zip`、`Python_files.zip`
- 处理日期：2026-06-25

## 用户评审结论

推荐指数：

```text
★★★★☆
```

收藏价值：

```text
Regression Label + Confidence Filter + 双模型架构
```

整体评分：

| 项目 | 评分 |
| --- | --- |
| Regression Label | ★★★★★ |
| Mean Label | ★★★★★ |
| Meta Learning 思路 | ★★★★☆ |
| Confidence Filter | ★★★★☆ |
| Threshold Trading | ★★★★★ |
| ONNX 导出 | ★★☆☆☆ |
| EA 实现 | ★★☆☆☆ |
| 整体收藏价值 | 8.5/10 |

最值得沉淀：

- Regression Label；
- Future Mean Label；
- Meta Regressor；
- Easy Sample Filtering；
- Prediction + Confidence 双模型架构；
- Threshold-Based Trading。

## 核心思想

把：

```text
分类：Buy / Sell
```

升级成：

```text
回归：预测未来收益大小
```

再用第二个模型估计预测误差，只交易：

```text
收益足够大
  +
可信度足够高
```

的信号。

整体流程：

```text
Feature
  ↓
Regression Label
  ↓
Main Regressor
  ↓
预测未来收益
  ↓
Meta Regressor
  ↓
预测误差 / Confidence
  ↓
Threshold Filter
  ↓
Trade
```

这是全文最值得学习的地方。

## 为什么回归优于单纯分类

分类模型只回答：

```text
上涨 or 下跌
```

但交易真正关心的是：

```text
上涨多少？
收益是否覆盖点差、滑点、手续费？
盈亏比是否值得交易？
```

高方向准确率不等于盈利。

例如：

- 30% 胜率也可能盈利；
- 70% 胜率也可能亏损。

关键不是方向对错，而是：

```text
winning trade magnitude
  vs
losing trade magnitude
```

所以 regression label 更符合量化交易。

## 设计一：Regression Label

传统分类：

```text
future close > current close
  ↓
BUY
else
  ↓
SELL
```

回归标签：

```text
label = future_price - current_price
```

例如：

```text
未来上涨 35 points
  ↓
label = +35
```

优点：

- 保留收益大小；
- 可以排序；
- 可以设置交易门槛；
- 可直接进入 expectancy / risk-reward 逻辑；
- 更接近因子研究中的 forward return。

推荐指数：

```text
★★★★★
```

## 设计二：Future Mean Label

基础版本用随机未来点：

```text
label = close[t + rand(min,max)] - close[t]
```

更稳定的版本：

```text
label = mean(close[t+min : t+max]) - close[t]
```

也就是：

```text
Mean Future Return
```

优点：

- 降低单点随机噪声；
- 更能反映未来窗口平均方向；
- 对趋势更稳定；
- 不容易被某一根极端 bar 污染。

这是文章第二个最值得收藏的设计。

## 设计三：Meta Regressor 估计预测误差

文章训练多个回归模型：

```text
Model 1
Model 2
Model 3
...
```

对每个样本计算：

```text
prediction_error = abs(real_label - predicted_label)
```

再平均得到：

```text
meta_label
```

意义：

```text
当前样本到底好不好预测？
```

如果：

```text
meta_label small
  ↓
容易预测 / high confidence

meta_label large
  ↓
噪声大 / low confidence
```

这本质是：

```text
Confidence Estimation
```

值得收藏。

## 设计四：Easy Sample Filtering

训练最终主模型时，只保留：

```text
meta_label < tol
```

即：

```text
只学习容易预测的数据
```

相关思想：

- Curriculum Learning；
- Easy Sample Mining；
- Self-paced Learning；
- 去除高噪声样本；
- 降低标签噪声。

在交易领域这点很有价值，因为金融数据中大量样本本来就不可预测。

## 设计五：Regression Threshold

分类模型通常只能：

```text
if prob > 0.5
  trade
```

回归模型可以：

```text
if predicted_return > buy_threshold
  buy

if predicted_return < sell_threshold
  sell
```

这允许过滤掉：

```text
预测收益不足以覆盖交易成本的信号
```

例如：

```text
预测 5 points
  ↓
忽略

预测 60 points
  ↓
允许交易
```

这是 regression trading 最大优势。

## 设计六：Confidence Threshold

第二模型输出：

```text
predicted_error
```

如果：

```text
main predicts +30 points
meta predicts error 80 points
```

说明预测可信度低，应过滤。

交易条件应变成：

```text
abs(meta_error) < meta_threshold
  AND
prediction passes buy/sell threshold
```

即：

```text
Prediction + Confidence
```

双模型过滤。

## 完整 Pipeline

```text
Feature
  ↓
Regression Label
  ↓
Train Multiple Regressors
  ↓
Prediction Error
  ↓
meta_label
  ↓
Filter Easy Samples
  ↓
Train Final Main Model
  ↓
Train Final Meta Model
  ↓
Export ONNX
  ↓
MQL5:
  Main Prediction
  +
  Confidence Prediction
  ↓
Threshold Filter
  ↓
Trade
```

这是全文精华。

## 值得参考的代码模块

建议收藏：

- `future - current` regression label；
- `mean_future - current` mean future label；
- `abs(real - pred)` meta label；
- `meta_label < tol` easy sample filter；
- `if(sig > buy_threshold)` threshold trading；
- `if(abs(meta_sig) < meta_threshold)` confidence gating。

参考价值一般：

- ONNX 导出代码；
- RandomForest 训练细节；
- EA 交易逻辑；
- 无限 retry 风格的下单片段；
- 单一标准差 feature。

## 可以升级的地方

### 1. Label 标准化

原文：

```text
future_price - current_price
```

建议：

```text
future_return / ATR
```

或：

```text
future_return / volatility
```

这样跨品种、跨波动 regime 更可比。

### 2. Confidence 改成不确定性估计

原文：

```text
abs(real - pred)
```

可升级：

- ensemble prediction variance；
- quantile regression interval；
- conformal prediction interval；
- model disagreement；
- Bayesian uncertainty；
- residual volatility。

### 3. Threshold 动态化

原文：

```text
fixed buy_threshold
fixed sell_threshold
fixed meta_threshold
```

建议：

```text
threshold = ATR × k
```

或：

```text
threshold by regime
threshold by spread / cost
threshold by liquidity
```

### 4. 模型升级

原文实际使用：

```text
RandomForestRegressor
```

建议研究：

- LightGBM；
- CatBoost；
- XGBoost；
- linear / ridge baseline；
- quantile models；
- calibrated regression。

### 5. Feature 升级

原文特征较弱，主要是标准差类 feature。

可加入：

- ATR；
- ADX；
- RSI；
- volatility；
- volume；
- regime；
- market state；
- microstructure；
- liquidity；
- session；
- G Channel state；
- Kalman gain；
- Kyle / Amihud。

## 和本项目已有研究的关系

可接入：

```text
State → Feature → Return
```

这里的 regression label 就是：

```text
Forward Return
```

结合：

- Microstructure Features：提高 feature 质量；
- Market State Classification：按 regime 训练/过滤；
- G Channel：趋势结构 feature；
- DSU + DBN Signal：event cluster 后预测收益；
- Universal Breakout Study：对 breakout event 预测未来收益；
- CSV Export Pipeline：导出训练/测试结果；
- Fluent Order Builder：把 threshold signal 转成订单请求。

## 研究验证建议

不要只看 tester 曲线。

建议增加：

1. OOS / Walk-forward；
2. IC / RankIC；
3. prediction bin 分层收益；
4. predicted return vs realized return scatter；
5. residual distribution；
6. meta error 分组后的交易表现；
7. threshold sensitivity；
8. cost-adjusted return；
9. by regime performance；
10. by symbol / timeframe robustness。

核心问题：

```text
预测值越高，未来实际收益是否单调更高？
```

如果没有这个关系，threshold trading 只是过拟合。

## 风险和问题

### 1. `tol` 容易过拟合

`meta_label < tol` 会筛掉难预测样本。

这有助于稳健，但也可能只保留历史上碰巧容易的区域。

需要 walk-forward 验证。

### 2. Threshold 优化容易数据挖掘

`buy_threshold`、`sell_threshold`、`meta_threshold` 如果在同一数据上反复调，容易过拟合。

应分：

```text
train
validation
test
forward
```

### 3. ONNX 不是研究价值核心

ONNX 只是部署手段。

真正价值是：

```text
label design + confidence estimation + threshold decision
```

### 4. EA 下单逻辑一般

原文交易代码更像 demo。

若实盘化，应使用：

- TradeRequestBuilder；
- TradeValidator；
- RiskManager；
- TradeExecutor；
- TradeLogger；
- Repository / Journal。

## 最终结论

这篇文章值得收藏，但不是因为它的 RandomForest、ONNX 或 EA 代码。

真正价值是一个清晰的 regression trading framework：

```text
Regression Label
  ↓
Mean Future Label
  ↓
Meta Regressor
  ↓
Easy Sample Filtering
  ↓
Prediction + Confidence
  ↓
Threshold-Based Trading
```

一句话沉淀：

```text
18603 的价值是把交易信号从方向分类升级为“收益幅度预测 + 可信度过滤”，
这比单纯 Buy/Sell 分类更接近真实交易决策。
```

## 标签

- MQL5
- Python
- Regression
- Causal Inference
- Meta Model
- Confidence Filter
- ONNX
- Threshold Trading
- Forward Return
- Machine Learning
- Quant Research
