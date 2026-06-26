# MQL5 Bootstrap：Python Requests / WebRequest Facade

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/18728>
- Title: Python Requests in MQL5
- Author: Omega Joctan
- Local source: [Bootstrap_Requests](../../examples/mql5/Bootstrap_Requests/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 策略思想 | ☆☆☆☆☆ |
| 数学算法 | ☆☆☆☆☆ |
| MQL5 技巧 | ⭐⭐⭐⭐☆ |
| Integration 价值 | ⭐⭐⭐⭐⭐ |
| Bootstrap 依赖价值 | ⭐⭐⭐⭐⭐ |
| 收藏价值 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 这篇不是交易文章，而是把 MQL5 `WebRequest()` 包装成 Python `requests` 风格的 HTTP 客户端。

## 与 Bootstrap 系列的关系

这篇补的是 Integration 层。

目前 Bootstrap 依赖链可以这样看：

```text
File IO        → 文件抽象
Logging        → 诊断日志
Requests       → HTTP / Web API 集成
Trade Helpers  → account state helpers
```

如果你的 EA 需要连接外部服务，这篇比普通策略文章更有长期价值。

典型用途：

- Python service signal bridge；
- FastAPI / Flask / Django API；
- Telegram / Discord / webhook；
- model server inference；
- remote config；
- trade journal upload；
- external risk server。

## 核心设计

源码围绕两个结构：

```text
CResponse
CSession
```

`CSession` 负责请求构造和发送。

`CResponse` 负责结构化返回结果。

这比直接调用 `WebRequest()` 更接近可复用框架。

## 1. CResponse

`CResponse` 保存：

- `status_code`;
- `text`;
- `json`;
- `content[]`;
- `headers`;
- `cookies`;
- `url`;
- `ok`;
- `elapsed`;
- `reason`.

这是非常值得收藏的模式。

EA 业务层不应该直接处理：

```text
char result[]
string result_headers
int status
```

而应该接收一个语义明确的 response object。

## 2. CSession

`CSession` 提供：

- `request()`;
- `get()`;
- `post()`;
- `put()`;
- `patch()`;
- `delete_()`;
- `SetCookie()`;
- `ClearCookies()`;
- `SetBasicAuth()`;
- `BuildUrlWithParams()`.

这基本就是 Python `requests.Session` 的 MQL5 简化版。

## 3. Header / Cookie 管理

源码提供 `UpdateHeader()`，可以新增或替换 header。

这点很实用。

长期框架中，header 不应该手工字符串拼接：

```text
"Content-Type: application/json\r\n"
```

而应该由 Header Builder 管理。

## 4. JSON Body

源码依赖 `jason.mqh`，在请求时支持 JSON 反序列化 / 序列化。

这适合：

```text
EA → HTTP API → Python service
```

例如：

```text
features
positions
risk state
account state
```

都可以通过 JSON 发送给 Python 服务。

## 5. Multipart File Upload

文章实现了 multipart/form-data。

这对普通 EA 不常用，但对框架有价值。

可用于：

- 上传 CSV；
- 上传日志；
- 上传回测结果；
- 上传图片或报表；
- 上传模型诊断文件。

源码还提供 `GuessContentType()`，根据扩展名生成 MIME type。

## 6. URL Encoding / Query Builder

`URLEncode()` 和 `BuildUrlWithParams()` 值得保留。

很多 MQL5 WebRequest 代码直接拼 URL：

```text
url + "?a=" + a + "&b=" + b
```

一旦参数包含空格、中文、特殊字符，就会出错。

这类工具应该进入 `Integration/Http` 基础层。

## 值得收藏的内容

一级收藏：

- `CResponse` result struct；
- `CSession` facade；
- `request()` 统一入口；
- `get/post/put/patch/delete_` helper；
- header update；
- cookie state；
- basic auth；
- URL encode；
- query builder；
- JSON response parsing；
- multipart body builder；
- MIME type guessing；
- elapsed time 统计；
- `ok` / `reason` 语义字段。

二级收藏：

- `errordescription.mqh`；
- `jason.mqh` 作为依赖；
- demo script。

不重点收藏：

- 示例请求地址；
- 演示打印；
- 当前固定 boundary 字符串；
- 当前静态 session state 设计。

## 不足与生产化建议

### 1. Static Session State 限制扩展

源码中：

```text
static string m_headers
static string m_cookies
```

这意味着全局共享一个 session。

如果一个 EA 同时访问：

```text
Telegram API
Python model API
Risk server
```

静态状态可能互相污染。

生产版建议改成实例字段：

```text
class CHttpSession
{
    string headers;
    string cookies;
}
```

每个 API 一个 session。

### 2. 需要显式 WebRequest Policy

MQL5 终端要求手动允许 URL。

框架应提供：

```text
WebRequestPolicy.CheckAllowed(url)
```

至少在失败时输出明确提示：

```text
Add URL to Tools → Options → Expert Advisors → Allow WebRequest
```

否则实盘排查成本很高。

### 3. Multipart Boundary 应动态生成

源码中 boundary 是固定字符串。

生产版建议：

```text
boundary = random / timestamp based
```

降低与 payload 内容冲突的概率。

### 4. 文件路径规则要明确

文件上传时根据 basename 读取文件。

MQL5 文件系统有 sandbox。

生产版需要明确：

- local files folder；
- common folder；
- binary / text mode；
- 最大文件大小；
- 失败策略。

### 5. Response Cookie 解析不完整

源码从 JSON 中取 cookies，并不等价于解析 HTTP `Set-Cookie` header。

生产版如果真要维护 session cookie，应解析 response headers。

## 推荐框架结构

建议归入：

```text
Framework/
├── Integration/
│   ├── HttpClient.mqh
│   ├── HttpSession.mqh
│   ├── HttpResponse.mqh
│   ├── HttpHeaders.mqh
│   ├── HttpMultipart.mqh
│   ├── UrlEncode.mqh
│   └── WebRequestPolicy.mqh
├── Diagnostics/
│   └── Logger.mqh
└── IO/
    └── FileIO.mqh
```

## 最终结论

这篇值得作为 Bootstrap / Integration 基础设施收录。

它真正有价值的不是某个 HTTP 方法，而是：

```text
WebRequest raw API
    ↓
Session facade
    ↓
Structured Response
    ↓
EA / Python / Web API bridge
```

对于 MQL5 + Python 混合量化框架，这类 HTTP facade 是核心基础组件。

## 标签

```text
MQL5 Bootstrap
WebRequest
HTTP Client
CSession
CResponse
Python Requests
Integration
JSON
Multipart
EA Framework
Python Bridge
```
