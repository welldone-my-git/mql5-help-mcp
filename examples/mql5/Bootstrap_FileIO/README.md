# Bootstrap File IO

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/20695>
- Title: Pythonic File Handling in MQL5

Positioning:

```text
Bootstrap File IO facade for MQL5, useful as a lower-level dependency for EA frameworks.
```

## Files

- `Include/PyMQL5/fileIO/fileIO.mqh` - `CFile` wrapper and `CFileIO::open()` facade.
- `Include/PyMQL5/fileIO/csv.mqh` - `CSVReader` and `CSVWriter`.
- `Scripts/Test file IO.mq5` - usage examples for text, CSV, binary arrays, append, and read.
- `Files/` - small sample text, csv, and binary files.

Non-core binary demo assets from the original attachment were not imported.

## Core Takeaways

- Wrap raw `FileOpen()` flags behind a Python-like mode string.
- Keep handle operations inside `CFile`: `readline`, `read`, `write`, `seek`, `tell`, `flush`, `close`.
- Convert mode strings like `r`, `w`, `a`, `+`, `b`, `t`, `x` into MQL5 file flags.
- Keep CSV parsing/writing separate from generic file operations.
- Support shared read/write flags and `FILE_COMMON` through one open facade.

## Reuse Notes

- The source files are UTF-16 encoded, matching MetaEditor-friendly output.
- `CFile` destructor has auto-close commented out; production code should restore RAII-style close or enforce explicit close in wrappers.
- `CSVWriter::writeRow()` prepends a newline before every row. Review this before using it for header-first CSV files.
- This is lower-level than `CSVExporter`: use it for general file abstraction, not only optimization logs.

Recommended framework location:

```text
Framework/IO/
├── File.mqh
├── FileIO.mqh
├── CsvReader.mqh
└── CsvWriter.mqh
```
