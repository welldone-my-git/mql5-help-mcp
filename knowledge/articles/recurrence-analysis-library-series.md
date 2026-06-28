# Recurrence Analysis 系列：RQA / CRQA / JRQA / RNA 非线性动力系统特征库

来源作者：

- 作者主页：https://www.mql5.com/en/users/homirana
- 作者：Hammad Dilber / Homirana

## 链接校正

用户给出的后 3 篇链接编号不匹配。按作者主页核验，真实系列链接为：

| 顺序 | 主题 | 链接 |
|---:|---|---|
| 1 | RQA | https://www.mql5.com/en/articles/22288 |
| 2 | CRQA | https://www.mql5.com/en/articles/22500 |
| 3 | JRQA | https://www.mql5.com/en/articles/22610 |
| 4 | RNA | https://www.mql5.com/en/articles/22652 |

错误编号说明：

- `22377` 是 Markov MLP 文章；
- `22452` 当前为 404；
- `22527` 是 ONNX Inference Engine。

## 总体定位

这四篇构成完整 Recurrence Analysis Library：

```text
Takens Embedding
      │
      ▼
Distance Matrix
      │
      ▼
Recurrence Matrix
      │
      ├── RQA
      ├── CRQA
      ├── JRQA
      └── RNA
```

它们与 TDA 系列互补：

```text
Recurrence Analysis → 非线性动力系统特征
TDA                → 拓扑形状特征
```

## 学习顺序

1. RQA：单序列 recurrence metrics；
2. CRQA：两个序列之间的 cross recurrence；
3. JRQA：两个系统是否同时 recurrence；
4. RNA：把 recurrence matrix 变成 graph / complex network。

## 已收录源码

- `examples/mql5/RQA_Library/`
- `examples/mql5/CRQA_Library/`
- `examples/mql5/JRQA_Library/`
- `examples/mql5/RNA_Library/`

## 推荐归档

```text
Research
│
├── Dynamical Systems
│   ├── Takens Embedding
│   ├── Recurrence Matrix
│   ├── RQA
│   ├── CRQA
│   ├── JRQA
│   └── RNA
│
├── Topological Data Analysis
│   ├── Vietoris-Rips
│   ├── Boundary Matrix
│   └── Persistent Homology
│
└── ML Feature Engineering
```

## 最终判断

这是高价值研究基础设施，不是交易策略。最终应输出为：

```text
RR / DET / LAM / ENTR / TREND
CRR / CDET / CLAM / CENTR
JRR / JDET / JLAM / JENTR
clustering / density / path length / assortativity
```

这些都可以进入 ML / regime detection / pair trading / intermarket feature matrix。
