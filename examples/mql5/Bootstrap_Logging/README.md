# Bootstrap Logging

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/20458>
- Title: Log Like a Pro in MQL5: Build a Python-Inspired Logging Library

Positioning:

```text
Bootstrap logging facade for MQL5 EA / Indicator / Script diagnostics.
```

## Files

- `Include/PyMQL5/logging.mqh` - `CLogger` implementation.
- `Scripts/Logging Test.mq5` - script usage example.
- `Experts/Logging Test.mq5` - EA usage example.

## Core Takeaways

- Wrap raw `Print()` and file writes behind one logger class.
- Use Python-like log levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.
- Support formatted messages with placeholders such as program name, function name, line number, program type, and message.
- Support log file rotation by max file size.
- Support optional cache mode and destructor-triggered cache flush.
- Support `FILE_COMMON` for shared logs across terminals and external tools.

## Reuse Notes

- The source files are UTF-16 encoded, matching MetaEditor-friendly output.
- `CLogger` is useful as a framework diagnostics layer, not as a trading strategy component.
- The implementation flushes on every non-cached write. That is safer but can be expensive on high-frequency logging.
- `MAX_FILE_SIZEMB`, `MAX_LOG_FILES`, and `MAX_CACHE_SIZE` are compile-time macros; production frameworks may want runtime configuration.
- The assignment operator copies configuration but not a live file handle. Treat logger objects as owned services rather than casually copied values.

Recommended framework location:

```text
Framework/Diagnostics/
├── Logger.mqh
├── LogFormatter.mqh
├── LogSinkFile.mqh
├── LogSinkConsole.mqh
└── LogRotation.mqh
```
