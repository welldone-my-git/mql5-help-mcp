# Omega Python-like Modules：Datetime 与 SQLite 基础设施

来源：

- Datetime：https://www.mql5.com/en/articles/19035
- SQLite：https://www.mql5.com/en/articles/18640
- 作者：Omega J. Msigwa

## 结论

这两篇属于 MQL5 Bootstrap 基础设施，不是策略。

## Datetime

价值：

- Python-like time / date / datetime；
- timezone；
- session filter；
- CalendarEngine；
- schedule engine。

已收录源码：

- `examples/mql5/Bootstrap_Datetime/`

## SQLite

价值：

- Python sqlite3-style facade；
- MQL5 local structured storage；
- state cache；
- local analytics；
- tester output storage。

已收录源码：

- `examples/mql5/Bootstrap_SQLite/`

## 与现有方向关系

Python 侧长期建议：

```text
DuckDB / Polars / Parquet
```

MQL5 侧可使用 SQLite facade 作为：

```text
local cache / state / lightweight storage
```
