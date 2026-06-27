# Bootstrap Datetime

来源：

- 文章：https://www.mql5.com/en/articles/19035
- 标题：Implementing Practical Modules from Other Languages in MQL5 (Part 04): time, date, and datetime modules from Python
- 作者：Omega J. Msigwa

定位：

```text
MQL5 Bootstrap / Python-like DateTime Utilities。
```

## 文件

- `Include/PyMQL5/time.mqh`
- `Include/PyMQL5/datetime.mqh`
- `Include/PyMQL5/TZInfo.mqh`
- `Include/PyMQL5/SQLite3.mqh`
- `Scripts/Time testing.mq5`
- `Common/Files/timezonedb.sqlite`

## 收藏重点

- Python-like time/date/datetime facade；
- timezone database；
- session / calendar / schedule engine 的基础；
- 对 `CalendarEngine`、news filter、market session filter 有直接价值。

## 注意

`timezonedb.sqlite` 是数据文件，是否提交需按项目体积和许可再判断。当前作为原始附件保留在示例目录中。
