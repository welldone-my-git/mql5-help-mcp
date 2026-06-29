# Python + MetaTrader 5 ONNX Integration

来源：

- 文章：https://www.mql5.com/en/articles/22020
- 标题：Python + MetaTrader 5: Fast Research Framework for Data, Features, and Prototypes
- 作者：MetaQuotes
- 发布日期：2026-05-04

## 定位

```text
Research → Production Pipeline / Python Research + MQL5 ONNX Runtime。
```

这是目前 MQL5 官方文章里最接近完整 Research → Production 流程的样例：Python 负责数据、特征、模型训练、ONNX 导出，MetaTrader 5 负责 Strategy Tester、EA/Indicator 推理和执行。

## 文件结构

```text
MQL5/
├── Experts/Integration/Integration.mq5
├── Indicators/Integration/Integration.mq5
└── Scripts/Integration/
    ├── load_data.py
    ├── look_model_param_rf.py
    └── create_model_rf.py
```

## 文件说明

| 文件 | 作用 |
|---|---|
| `load_data.py` | 使用 Python `MetaTrader5` 包连接终端、读取历史 rates、做初步特征/相关性分析 |
| `look_model_param_rf.py` | 构造 MACD 特征矩阵，枚举 RandomForestRegressor 参数 |
| `create_model_rf.py` | 固定参数训练 RandomForestRegressor，计算阈值策略原型，导出 ONNX，并用 onnxruntime 对比 sklearn 输出 |
| `Experts/Integration/Integration.mq5` | EA：加载 ONNX resource，复刻特征生成，调用 `OnnxRun()`，按 threshold 执行交易 |
| `Indicators/Integration/Integration.mq5` | Indicator：加载同一 ONNX resource，把模型信号画到图表 |

## 核心流程

```text
Python MetaTrader5 API
        ↓
历史数据读取
        ↓
Feature Engineering
        ↓
Hypothesis / Correlation Check
        ↓
RandomForestRegressor
        ↓
Threshold / PnL Prototype
        ↓
skl2onnx Export
        ↓
onnxruntime parity check
        ↓
MQL5 OnnxCreateFromBuffer / OnnxRun
        ↓
Strategy Tester / EA / Indicator
```

## 值得抽取的模块

### 1. Python Research Loop

Python 脚本完成：

- MT5 terminal 初始化；
- UTC 时间范围；
- `copy_rates_range()` 拉取数据；
- pandas DataFrame 清洗；
- RSI / MACD / diff 特征；
- train / test 拆分；
- RandomForest 参数搜索；
- threshold-based 简单 PnL 原型。

这对应平台中的：

```text
data/mt5/
research/features/
research/models/
research/validation/
```

### 2. ONNX Export Contract

`create_model_rf.py` 使用：

```text
skl2onnx.convert_sklearn()
onnxruntime.InferenceSession()
```

并比较：

```text
sklearn predictions
ONNX predictions
correlation
max diff
```

这一步是 Research → Production 的关键质量门。

### 3. MQL5 Runtime Inference

EA/Indicator 使用：

```text
OnnxCreateFromBuffer()
OnnxSetInputShape()
OnnxSetOutputShape()
OnnxRun()
OnnxRelease()
```

这说明 MT5 端不需要 Python 进程常驻，也能在 Strategy Tester 中运行模型。

### 4. Feature Parity

MQL5 必须复刻 Python 侧特征工程。这里是生产化最大风险点。

平台版应把 feature schema 固化：

```text
feature_name
order
dtype
lookback
normalization
available_at
python_impl_hash
mql5_impl_version
```

## 当前源码限制

- 附件没有直接包含训练后的 `.onnx`；需要运行 `create_model_rf.py` 生成模型文件，再按 EA/Indicator resource 要求放置/命名。
- 示例 symbol 写死为 `EURUSD_i`，需要改成配置。
- 特征工程在 Python 与 MQL5 双写，存在 drift 风险。
- 阈值为常量 `threshold`，应由训练产物一并导出。
- 没有严谨 walk-forward / transaction cost / slippage 评估。

## 平台迁移建议

建议抽象成：

```text
ResearchPipeline
├── MT5DataLoader
├── FeatureBuilder
├── ModelTrainer
├── ThresholdSelector
├── ONNXExporter
├── ParityValidator
└── ModelPackage

MQL5 Runtime
├── FeatureRuntime
├── ONNXRuntimeAdapter
├── SignalThreshold
└── StrategyTesterHarness
```

## 结论

这篇不是最强模型文章，但它是很重要的工程闭环样例。它展示了从 Python 研究到 MQL5 Strategy Tester/EA/Indicator 的完整迁移路径，适合作为平台 `Research → Replay/Tester → Paper/Live` 的参考模板。
