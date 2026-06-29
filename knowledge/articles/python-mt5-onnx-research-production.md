# Python + MetaTrader 5：Research → Production ONNX 流程

来源：

- 文章：https://www.mql5.com/en/articles/22020
- 标题：Python + MetaTrader 5: Fast Research Framework for Data, Features, and Prototypes
- 作者：MetaQuotes
- 发布日期：2026-05-04
- 源码目录：[examples/research/python-mt5-onnx-integration](../../examples/research/python-mt5-onnx-integration/)

## 收藏结论

收藏价值：★★★★★

这篇的价值不在 RandomForest，也不在 MACD/RSI 特征，而在完整工程链路：

```text
Python Research
  ↓
Model Training
  ↓
ONNX Export
  ↓
MQL5 Runtime Inference
  ↓
Strategy Tester / EA / Indicator
```

它是 MQL5 官方文章中非常接近 Research → Production 的完整示例。

## 文章真正解决的问题

很多 ML 交易文章只停留在 Python notebook：

```text
DataFrame
  ↓
Model
  ↓
Backtest plot
```

这篇继续往后走：

```text
trained model
  ↓
ONNX
  ↓
MQL5 OnnxRun
  ↓
Strategy Tester
```

这一步才是生产化关键。

## 关键模块

### 1. MT5 Data Loader

Python 通过 `MetaTrader5` 包读取终端数据。文章强调 UTC 时间处理，这是金融数据工程的基础要求。

对应平台模块：

```text
data/mt5/
```

### 2. Feature Engineering

脚本构造：

- price diff；
- RSI；
- MACD；
- derivative features；
- correlation map；
- feature selection。

这部分不是最佳特征体系，但结构上体现了：

```text
raw rates → feature matrix → target
```

### 3. Model Training + Threshold

模型使用 `RandomForestRegressor`，并用预测绝对值阈值过滤弱信号。

重点不是 RF，而是：

```text
Prediction
  ↓
Signal Strength Threshold
  ↓
Trade / Skip
```

这与 Meta Label / confidence sizing 的方向一致。

### 4. ONNX Export + Parity Check

训练后使用 `skl2onnx` 导出模型，再用 `onnxruntime` 与 sklearn 输出对比。

这是必须保留的生产门槛：

```text
correlation ≈ 1
max diff ≈ small
```

没有 parity check 的模型迁移不能信。

### 5. MQL5 ONNX Runtime

EA/Indicator 使用：

```text
OnnxCreateFromBuffer()
OnnxSetInputShape()
OnnxSetOutputShape()
OnnxRun()
OnnxRelease()
```

这意味着模型可以进入 Strategy Tester，不依赖外部 Python 进程。

## 对平台的直接启发

建议形成标准模型包：

```text
model_package/
├── model.onnx
├── feature_schema.json
├── threshold.json
├── training_config.json
├── validation_report.json
└── parity_report.json
```

MQL5 端只加载模型包，不重新猜测特征顺序和阈值。

## 最大风险：Feature Parity

这篇源码中 Python 与 MQL5 都各自实现特征工程。这里最容易出错。

必须约束：

- 特征名；
- 特征顺序；
- lookback；
- shift；
- dtype；
- 缺失值处理；
- 是否闭合 K 线；
- normalization；
- threshold。

否则模型在 Python 里有效，到了 MQL5 端就是另一个模型输入。

## 放入当前知识库的位置

```text
Research
├── Python MT5 Bridge
├── Feature Engineering
├── Model Training
├── ONNX Export
└── MQL5 Runtime Inference
```

它应作为 `quant_platform` 的 `research/models` 与 `brokers/mt5` 之间的桥梁样例。

## 不足

- 样例没有完整 walk-forward；
- 没有严肃交易成本和滑点建模；
- 没有模型版本管理；
- 没有 feature schema 文件；
- 没有把 threshold 和模型一起打包；
- MQL5 特征复刻容易漂移。

## 最终判断

这篇适合做平台级模板，不适合照搬策略。它给出的正确方向是：

```text
Python 负责研究和训练
ONNX 负责模型交付
MQL5 负责测试和执行
```

这与当前项目的 Python + MT5 + DuckDB + OpenAlgo-style 中台路线高度一致。
