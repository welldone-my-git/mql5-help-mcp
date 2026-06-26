# Bootstrap Requests

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/18728>
- Title: Python Requests in MQL5

Positioning:

```text
Bootstrap WebRequest / HTTP client facade for MQL5 integration workflows.
```

## Files

- `Include/requests.mqh` - `CSession` and `CResponse` HTTP facade.
- `Include/jason.mqh` - JSON parser dependency.
- `Include/errordescription.mqh` - error text helper dependency.
- `Scripts/Requests test.mq5` - simple GET usage example.

## Core Takeaways

- Wrap raw `WebRequest()` behind Python-like helpers: `get`, `post`, `put`, `patch`, `delete_`.
- Return a structured `CResponse` object with status, text, JSON, headers, content, URL, elapsed time, and `ok`.
- Keep request state in `CSession`: default headers, cookies, and basic auth.
- Provide URL encoding and query-string builder.
- Support JSON body and multipart file upload.
- Guess content type from file extension.

## Reuse Notes

- Source files are UTF-16 encoded, matching MetaEditor-friendly output.
- MQL5 requires WebRequest URLs to be explicitly allowed in terminal settings.
- The implementation uses static session state; this is convenient but not ideal for multiple independent API clients in the same EA.
- File upload reads files by basename from the MQL5 sandbox. Production wrappers should make path rules explicit.
- This is an integration component, not a trading strategy component.

Recommended framework location:

```text
Framework/Integration/
├── HttpClient.mqh
├── HttpResponse.mqh
├── HttpHeaders.mqh
├── Json.mqh
└── WebRequestPolicy.mqh
```
