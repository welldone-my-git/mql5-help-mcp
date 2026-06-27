# Bootstrap SQLite

来源：

- 文章：https://www.mql5.com/en/articles/18640
- 标题：Implementing Practical Modules from Other Languages in MQL5 (Part 01): Building the SQLite3 Library, Inspired by Python
- 作者：Omega J. Msigwa

定位：

```text
MQL5 Bootstrap / SQLite3-inspired Database Facade。
```

## 文件

- `Include/sqlite3.mqh`
- `Include/errordescription.mqh`
- `Scripts/sqlite3 test.mq5`

## 收藏重点

- Python sqlite3 风格接口；
- 对 MQL5 内置 database API 做 facade；
- 可作为 state cache、local analytics、tester output storage 的基础。

## 与 DuckDB 的关系

这不是 DuckDB 替代品。

推荐定位：

```text
MQL5 local structured storage / cache / state
```

Python 侧长期仍建议：

```text
DuckDB / Polars / Parquet
```
