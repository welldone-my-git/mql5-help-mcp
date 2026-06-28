# MQL5 Bootstrap：SQLite3 Inspired 本地结构化存储

来源：

- 文章：https://www.mql5.com/en/articles/18640
- 标题：Implementing Practical Modules from Other Languages in MQL5 (Part 01): Building the SQLite3 Library, Inspired by Python
- 作者：Omega J. Msigwa
- 本地源码：[Bootstrap_SQLite](../../examples/mql5/Bootstrap_SQLite/)

## 核心价值

这篇把 MQL5 database API 包装成类似 Python `sqlite3` 的 facade。对当前平台的价值是本地结构化状态：

```text
EA state cache
order snapshot
position snapshot
restart recovery
tester intermediate logs
```

## 与 DuckDB / Parquet 的关系

SQLite 不替代 DuckDB / Parquet。

更合理的分工：

```text
SQLite  -> EA 本地轻量状态 / 缓存
DuckDB  -> 研究查询 / 回测日志 / feature store
Parquet -> 长期归档 / 批量研究
```

## 对 quant_platform 的映射

```text
storage/state_store.py
storage/local_cache.py
MQL5 restart recovery
```

## 收藏建议

保留：

- connection / cursor facade；
- execute / fetch pattern；
- MQL5 database API 包装方式；
- script test。

注意：

- 不要把 SQLite 作为高频 tick 主存储；
- 不要与 DuckDB 职责混淆。

结论：应单独收录为 State Store / Local Cache 参考。
