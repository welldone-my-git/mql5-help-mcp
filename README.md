# knowledge-mcp

[![npm package](https://img.shields.io/npm/v/knowledge-mcp.svg)](https://npmjs.org/package/knowledge-mcp)

**通用知识库 MCP 服务器**，默认内置 MQL5 文档（4500+ 官方文档 + 两本电子书），同时支持通过 `domain_plugin` 加载任意领域插件（已内置 `mql5`、`java`），通过 `sources[]` 接入 HTML/Markdown/PDF 文档，以及通过 Ollama 实现本地语义搜索。让你的 AI 编程助手（Claude Code、Cursor、Copilot 等）直接访问私有知识库，数据不出内网。

## 有哪些资料被内置？

- 官方 MQL5 文档：`MQL5_HELP/`（4500+ .htm）
- MQL5 算法交易手册（HTML）：`MQL5_Algo_Book/`
- 神经网络与机器学习手册（HTML）：`Neural_Networks_Book/`

> 说明：两本电子书版权归原作者所有，仅作为学习参考随仓库分发；当前版本主要对 `MQL5_HELP/` 做了完整索引，电子书的统一索引与搜索将在后续版本补充（Roadmap 已列出）。

## 面向问题的能力（结合用户建议重构）

当前可用 + 规划中功能一览：

- 搜索文档（已提供）
  - 通过函数名、类名或关键词快速定位官方文档
  - 覆盖交易函数、指标、标准库、ONNX 等常用主题
- 智能匹配（已提供基础能力）
  - 支持精确/模糊匹配，兼容常见类名变体（如 CTrade/Trade）
- 常见错误解决方案库（进行中）
  - 错误 256/undeclared identifier 等典型问题的成因与对照表
  - MQL4→MQL5 迁移差异：Symbol()→_Symbol，Period()→_Period，ResultCode()→ResultRetcode()
- 智能错误匹配（规划中）
  - 直接用“编译器错误文本”搜索：如 `error 256: undeclared identifier ResultCode`
- 上下文感知搜索（规划中）
  - 术语映射与别名：如 MQL4 的 `iMA` → MQL5 的 `IndicatorCreate`
- 代码分析与诊断（规划中）
  - `analyze_code`：指出 API 更名与常见误用
  - `diagnose_error`：基于编译错误日志给出定位与替代建议
- 交互式帮助（规划中）
  - 支持“针对某一行代码/某一错误”的追问式问答
- 学习路径推荐（规划中）
  - 从“语法差异 → 标准库 → 指标/交易 → 性能优化”的循序内容
- 多维标签与版本标注（规划中）
  - 难度/用途/版本/主题等维度过滤；明确 MQL4 兼容信息

> 优先级：
> 
> - 高：智能错误匹配、错误解决方案库、代码示例
> - 中：上下文感知搜索、交互式帮助、学习路径
> - 低：代码分析、标签系统、版本标注（细化）

## 快速开始

### 前提条件

- Node.js 18.0 或更高版本
- npm 或 npx

### 🚀 Claude Code 用户快速安装（最简单）

如果你使用 Claude Code，可以直接在命令行运行：

```bash
claude mcp add mql5-help npx -- -y github:welldone-my-git/mql5-help-mcp
```

安装后验证：

```bash
claude mcp list
```

你应该看到 `mql5-help` 显示为 `✓ Connected`。

> **首次安装注意**：第一次运行时，npx 需要从 GitHub 下载源代码、安装依赖并编译 TypeScript，可能需要 10-30 秒。如果首次显示连接失败，请稍等片刻后再次运行 `claude mcp list` 检查状态。

---

### 方便管理 ：直接从 cc-switch 安装（手动配置）

**MCP 标题 (唯一)** 建议填写：`mql5-help` 或 `mql5-docs` *(这是给系统内部用的 ID，只要不和别的重复即可)*

**显示名称** 建议填写：`MQL5 Documentation Server` *(这是显示给你看的名称，方便你识别)*

**完整的 JSON 配置** 请将编辑器中原有的内容清空，并复制粘贴以下代码。

由于这是一个 Node.js 项目，官方推荐使用 `npx` 直接运行：

JSON

```
{
  "type": "stdio",
  "command": "npx",
  "args": [
    "-y",
    "github:welldone-my-git/mql5-help-mcp"
  ]
}
```

### 注意事项（重要）

1. **必须安装 Node.js**：
   因为配置中使用了 `npx` 命令，你的电脑上必须已经安装了 Node.js 环境。如果没有安装，这个 MCP 服务将无法启动。

2. **首次运行较慢**：
   第一次添加并启用时，`npx` 需要从 GitHub 下载该包，可能会有一定的延迟，请耐心等待连接变绿（状态正常）。

3. **Windows 用户**：
   通常直接写 `"command": "npx"` 是可以的。如果报错找不到命令，你可能需要填写 `npx` 的完整路径（例如：`C:\\Program Files\\nodejs\\npx.cmd`），但大多数情况下直接写 `npx` 即可。

### 测试你的配置

配置完成后，在 Claude Code 或其他 AI 助手中测试以下命令：

#### 示例 1：搜索函数文档

```
搜索 MQL5 的 OrderSend 函数用法
```

AI 助手会调用 `search` 工具，返回相关文档列表。

#### 示例 2：获取详细文档

```
获取 CTrade 类的完整文档
```

AI 助手会调用 `get` 工具，返回 CTrade 类的详细说明。

#### 示例 3：浏览分类

```
浏览 MQL5 的交易相关文档有哪些？
```

AI 助手会调用 `browse` 工具，显示 trading 分类下的所有文档。

#### 示例 4：错误诊断（Smart Query - 推荐）

```
我的代码报错：error 256: undeclared identifier ResultCode，怎么解决？
```

AI 助手会自动调用 `smart_query`，直接返回解决方案：

- 诊断: ResultCode → ResultRetcode (MQL5迁移)
- 语法: ulong CTrade::ResultRetcode() const
- 示例代码
- 只消耗 ~500 tokens (vs 传统方式 4000+)

#### 验证 MCP 工具可用性

你也可以直接要求 AI 列出可用的 MQL5 工具：

```
列出你可以使用的 MQL5 文档工具
```

AI 应该会显示 16 个工具，包括 `smart_query`、`search`、`diagnose_error`、`analyze_structure`、`build_semantic_index` 等。

## 工具列表

本 MCP 服务器当前提供 **16 个工具**：

### 核心查询工具

1) **`smart_query`** - 🎯 智能查询（推荐）
- 参数：
  - `query`（必填）：查询内容（错误信息、函数名、类名或问题）
  - `mode`（可选）：`quick`（精简，~500 tokens，默认）或 `detailed`（详细，~1500 tokens）
- 特点：
  - **优先从错误数据库查询历史解决方案**
  - 自动识别查询类型（错误/函数/类/概念）
  - 节省 80%+ token 消耗
  - 完全本地化，零 API 成本
- 示例：
  - “error E512: undeclared identifier ResultCode”（优先从数据库查询）
  - “OrderSend 函数用法”
  - “如何使用 CTrade 类下单”
2) `search` - 搜索文档与代码库
- 参数：`query`（必填，关键词），`limit`（可选，默认 10）
- 示例：
  - “搜索与订单发送相关的函数”
  - “查找 ONNX 模型相关的文档”
  - “搜索外部库文件：mylib_filename”
3) `get` - 获取文档或代码文件详情
- 参数：`filename`（必填，如 `ordersend.htm`、`ordersend`、`MyClass.mqh`）
- 支持类型：`.htm/.html`（HTML文档）、`.md`（Markdown）、`.mq5/.mqh`（代码，原始返回）
- 示例：
  - “获取 OrderSend 的完整文档”
  - “查看 CTrade 类的详细说明”
  - “读取 MyExpert.mq5 代码”
4) `browse` - 浏览分类目录
- 参数：`category`（可选，如 `trading`, `indicators`, `math` 等）
- 常见分类：`trading`, `indicators`, `math`, `array`, `string`, `datetime`, `files`, `chart`, `objects`, `onnx`

### 诊断工具（新增 v1.4.0）

5) **`diagnose_error`** - 🔬 编译日志批量诊断
- 参数：`compile_log`（必填）：MetaEditor 完整编译输出文本
- 功能：
  - 自动解析所有 `error/warning` 行，相同错误自动去重
  - 逐条匹配 18 条 MQL4→MQL5 迁移映射
  - 查询本地错误数据库中的历史解决方案
  - 推荐相关参考文档
- 示例：
  ```
  粘贴 MetaEditor 编译窗口的完整输出（可包含多个错误）
  ```
6) **`list_libraries`** - 📚 查看已加载资料库
- 无需参数
- 功能：列出所有内置库与用户配置的外部库，显示文件数量与路径
- 未配置外部库时，显示 `config.json` 配置示例

### 智能库分析工具（新增 v1.5.0）

> 这两个工具配合使用，实现"真正理解代码库"而非单纯检索。

7) **`preprocess_library`** - 🤖 预处理外部库知识（一次性）
- 参数：`library_key`（可选）：指定库的 key；留空则处理所有外部库
- 前提：需设置环境变量 `ANTHROPIC_API_KEY`
- 功能：
  - 调用 Claude Haiku 逐文件分析 `.mqh`，提取类/方法/用途/典型用法
  - 结果缓存到 `~/.knowledge-mcp/knowledge/<key>/`（本地 JSON）
  - 源文件更新后自动重新处理，未变更文件跳过
  - 显示实时进度与 API 成本估算（100 个文件约 $0.10）
- 示例：
  ```
  preprocess_library("EA31337")      # 处理指定库
  preprocess_library()               # 处理所有外部库
  ```

8) **`analyze_code`** - 🧠 智能代码分析（零 API 成本）
- 参数：
  - `code`（必填）：需要分析的 MQL5 代码片段（EA、指标或函数均可）
  - `library_key`（可选）：限定分析范围到指定库；留空则跨所有已预处理库
- 前提：需先运行 `preprocess_library` 建立本地知识缓存
- 功能：
  - 从本地缓存加载结构化库知识（零 API 调用）
  - 检测用户代码中可用库替换的原始写法（按行定位）
  - 组装结构化上下文（API 摘要 + 检测结果）返回给 Claude
  - Claude 基于此上下文给出**具体到行号、可编译**的改进建议
- 示例：
  ```
  analyze_code(my_ea_code)           # 跨所有库分析
  analyze_code(my_ea_code, "EA31337")# 只对照 EA31337
  ```

**两步工作流：**

```
第一步（一次性，花几分钱）：
  设置 ANTHROPIC_API_KEY → preprocess_library("MyLib")
  → Haiku 分析 .mqh → 知识缓存到本地

第二步（日常，零成本）：
  贴入你的 EA 代码 → analyze_code(code)
  → 本地加载知识 → 返回上下文给 Claude
  → Claude 输出：第23行 OrderSend → 改用 CTrade::Buy()，示例代码...
```

### 代码质量闭环工具（新增 v1.6.0）

> 三个工具形成完整的"发现问题 → 修复 → 积累"闭环，完全本地，零 API 成本。

9) **`analyze_structure`** - 🏗️ MQL5 代码结构静态分析
- 参数：`code`（必填）：需要分析的 MQL5 代码（EA 或指标）
- 功能：
  - 检测 6 类常见问题：句柄泄漏（HIGH）、OnTick 无保护开仓（HIGH）、魔术数字（MEDIUM）、固定手数（MEDIUM）、缺少错误检查（MEDIUM）、忘记 SetAsSeries（LOW）
  - 输出带分数（0-100）的评分报告，按行号定位问题，给出修复建议
  - 若本地已有匹配的修复模式，直接附上已验证代码片段
  - 完全本地运行，零 API 成本
- 示例：
  ```
  analyze_structure(my_ea_code)
  ```

10) **`record_fix`** - 💾 记录已验证的修复模式
- 参数：
  - `pattern_description`（必填）：问题的简短描述
  - `fix_description`（必填）：修复说明
  - `original_snippet`（可选）：有问题的代码示例
  - `fixed_snippet`（可选）：修复后的代码示例
  - `library_key`（可选）：关联的库
  - `tags`（可选）：标签，JSON 数组格式
- 功能：将"问题→修复"映射存入本地 SQLite；相同描述自动更新使用次数
- 工作流：`analyze_code` 或 `analyze_structure` 发现问题 → Claude 给出修复 → 用此工具保存 → 下次直接命中
- 示例：
  ```
  record_fix("OnTick未检查持仓数量就调用CTrade::Buy", "添加 if(PositionsTotal()>0) return")
  ```

11) **`list_fixes`** - 📋 查看 / 搜索已记录的修复模式
- 参数：
  - `query`（可选）：搜索关键词；留空则列出全部
  - `limit`（可选，默认 20）：返回数量
- 功能：按使用频率排序展示已积累的修复模式，支持模糊关键词搜索
- 示例：
  ```
  list_fixes()               # 列出所有修复（按使用频率）
  list_fixes("CTrade handle")# 搜索含 CTrade/handle 的修复
  ```

12) **`manage_knowledge`** - 🔄 管理预处理库知识（导出/导入/统计）
- 参数：
  - `action`（必填）：`export`、`import`、`stats`
  - `library_key`（export 时必填）：要导出的库 key
  - `file_path`（import 时必填）：`.knowledge.json` 文件的绝对路径
  - `import_as`（可选）：导入时覆盖库名
- 功能：
  - `export`：将本地预处理知识写入磁盘（`~/.knowledge-mcp/exports/<key>.knowledge.json`），返回文件路径
  - `import`：从磁盘文件路径导入他人知识包，**无需自己运行 Haiku API**
  - `stats`：查看各库的知识缓存状态 + 修复模式数量
- 示例：
  ```
  manage_knowledge("export", library_key="EA31337")
  manage_knowledge("import", file_path="/tmp/EA31337.knowledge.json")
  manage_knowledge("stats")
  ```

**闭环工作流：**

```
1. analyze_structure(code)      → 发现问题（带行号）
2. analyze_code(code)           → 库级优化建议（附已知修复）
3. Claude 给出修复方案
4. record_fix(...)              → 保存到本地
5. manage_knowledge("export", library_key="MyLib")  → ~/.knowledge-mcp/exports/MyLib.knowledge.json
   manage_knowledge("import", file_path="...")       → 团队复用，节省 API 成本
```

### 语义搜索工具（新增 v1.7.0）

16) **`build_semantic_index`** - 🔮 构建语义向量索引（一次性）
- 参数：
  - `force_reindex`（可选，默认 false）：忽略已有索引强制重建
  - `limit`（可选）：限制处理文档数量（调试用）
- 前提：需先配置 Ollama（见下方"语义搜索配置"章节）
- 功能：
  - 调用本地 Ollama embedding 模型对所有文档向量化，存入 `~/.knowledge-mcp/semantic.db`
  - 增量运行：已索引的文档自动跳过，只处理新增文档
  - 完成后 `search` / `smart_query` **自动切换为混合模式**（无需任何额外操作）
- 示例：
  ```
  build_semantic_index()                    # 增量索引
  build_semantic_index(force_reindex=true)  # 全量重建（换模型后使用）
  ```

> **混合搜索效果：**
> - 关键词模式（未配置 Ollama）：`"止损"` → 无结果
> - 混合模式（配置后）：`"如何设置止损"` → 命中 `OrderModify`、`CTrade::PositionModify`、`StopLoss` 相关文档
> - 搜索结果会显示 `[混合（关键词 + 语义）]` 标记和匹配分数百分比

### 错误收集与管理工具（新增 v1.3.0）

13) **`log_error`** - 📝 记录编译错误
- 参数：
  
  - `error_code`（必填）：错误代码（如 `E512`、`E308`）
  - `error_message`（必填）：完整错误消息
  - `file_path`（可选）：发生错误的文件路径
  - `solution`（可选）：解决方案描述
  - `related_docs`（可选）：相关文档列表（JSON 数组格式）

- 功能：记录错误到本地 SQLite 数据库（存储在 `~/.knowledge-mcp/mql5_errors.db`）

- 自动去重：相同错误会增加计数而不是重复记录

- 示例：
  
  ```
  记录错误：E512，消息是"undeclared identifier ResultCode"，解决方案是"改用 ResultRetcode()"
  ```
14) **`list_common_errors`** - 📊 查看高频错误
- 参数：`limit`（可选，默认 10）：返回错误数量

- 功能：列出最常见的编译错误（按出现频率排序）

- 显示每个错误的出现次数、最后遇到时间、解决方案摘要

- 示例：
  
  ```
  显示最常见的 10 个 MQL5 编译错误
  ```
15) **`manage_error_db`** - 🔧 管理错误数据库
- 参数：
  
  - `action`（必填）：操作类型
    - `export`：导出错误数据库为 JSON
    - `import`：从 JSON 导入错误记录
    - `stats`：查看数据库统计信息
  - `data`（导入时必需）：JSON 格式的错误数据
  - `anonymize`（可选，默认 false）：导出时是否移除文件路径（保护隐私）

- 功能：支持错误库的导出/导入，方便团队共享错误解决方案

- 智能合并：导入时自动合并，保留更高的出现次数

- 示例：
  
  ```
  导出错误数据库（匿名模式）
  查看错误数据库统计信息
  从JSON文件导入团队共享的错误库
  ```

> **错误数据库位置**：`~/.knowledge-mcp/mql5_errors.db`（用户主目录，跨项目共享）
> 
> **工作流程**：
> 
> 1. 遇到编译错误 → 使用 `smart_query` 查询（自动从数据库搜索）
> 2. 解决后 → 使用 `log_error` 记录解决方案
> 3. 定期查看 → 使用 `list_common_errors` 了解常见问题
> 4. 团队协作 → 使用 `manage_error_db` 导出/导入错误库

> 关于两本电子书：当前版本优先索引 `MQL5_HELP/`；对 `MQL5_Algo_Book/` 与 `Neural_Networks_Book/` 的"统一搜索与浏览分类"将随 Roadmap 开启，届时可通过 `browse` 与 `search` 在一个入口里检索。

## 语义搜索配置（可选，v1.7.0）

语义搜索让你可以**用自然语言（包括中文）查询英文文档**，无需知道确切的 API 名称。未配置时服务器退化为纯关键词搜索，现有功能不受影响。

### 第一步：安装 Ollama

```bash
# Linux / macOS
curl -fsSL https://ollama.ai/install.sh | sh

# Windows：从 https://ollama.ai 下载安装包

# 下载 embedding 模型（274MB，仅首次需要）
ollama pull nomic-embed-text
```

> `nomic-embed-text` 仅需 ~500MB 内存，CPU 上单次 embedding 约 15ms，任何现代笔记本均可运行。

### 第二步：更新 config.json

在 `~/.knowledge-mcp/config.json` 中添加 `embedding` 字段：

```json
{
  "embedding": {
    "provider": "ollama",
    "model": "nomic-embed-text",
    "url": "http://localhost:11434"
  }
}
```

> **企业/团队部署**：将 Ollama 部署在内网服务器，所有人的 `url` 指向同一地址（如 `http://192.168.1.100:11434`），数据不出内网，边际成本为零。

### 第三步：构建索引（一次性）

重启 MCP 服务器后，调用：

```
build_semantic_index()
```

4500 个 MQL5 文档约需 3-5 分钟（全程本地，无 API 调用）。之后新增文档可增量运行，已有索引自动跳过。

### 效果对比

| 查询 | 关键词模式 | 混合模式 |
|---|---|---|
| `"OrderSend"` | ✅ 精确命中 | ✅ 精确命中 |
| `"如何下单"` | ❌ 无结果 | ✅ 命中 OrderSend、CTrade::Buy |
| `"设置止损"` | ❌ 无结果 | ✅ 命中 OrderModify、StopLoss |
| `"账户余额"` | ❌ 无结果 | ✅ 命中 AccountInfoDouble |
| `"how to trade"` | ❌ 无结果 | ✅ 命中 CTrade、OrderSend |

---

## 示例与最佳实践

### 1. MQL4 → MQL5 迁移常见差异

- 预定义变量：`Symbol()` → `_Symbol`，`Period()` → `_Period`
- CTrade 结果：`ResultCode()` → `ResultRetcode()`
- 指标创建：`iMA(...)`（MQL4 习惯）→ `IndicatorCreate(...)`（MQL5 推荐）

示例（买入操作）：

```mql5
CTrade trade;
trade.SetExpertMagicNumber(12345);
if (trade.Buy(0.1, _Symbol)) {
  Print("买入成功，retcode=", trade.ResultRetcode());
}
```

### 2. 以错误文本驱动的搜索（规划中）

输入：

```
error 256: undeclared identifier ResultCode
```

期望返回：

- 解释“ResultCode 已改名为 ResultRetcode（MQL5）”
- 指向 CTrade 类文档与迁移指南

### 3. 交互式诊断（规划中）

```
mcp__mql5-help__diagnose_error(`
ma_cross_ea.mq5(155,39) : error 256: undeclared identifier 'ResultCode'
`)
```

期望：定位第 155 行问题并给出替代 API。

## 项目结构（含电子书）

```
mql5-help-mcp/
├── src/                       # TypeScript 源码
│   └── index.ts               # MCP 服务器实现
├── build/                     # 编译输出
├── MQL5_HELP/                 # 官方 MQL5 文档（4500+ .htm）
├── MQL5_Algo_Book/            # 算法交易手册（HTML 电子书）
├── Neural_Networks_Book/      # 神经网络/机器学习手册（HTML 电子书）
├── scripts/
├── package.json
├── tsconfig.json
└── README.md
```

## 工作原理与架构

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    MQL5 Help MCP Server                     │
├─────────────────────────────────────────────────────────────┤
│  工具层 (index.ts)                                          │
│  ├── smart_query  → 智能查询，精简返回                       │
│  ├── search       → 搜索文档，返回列表                       │
│  ├── get          → 获取完整文档内容                         │
│  ├── browse       → 浏览分类目录                            │
│  ├── log_error    → 记录错误到本地数据库                     │
│  └── manage_error_db → 管理错误数据库                       │
├─────────────────────────────────────────────────────────────┤
│  查询引擎层 (smart-query.ts)                                │
│  ├── QueryAnalyzer    → 分析查询类型（错误/函数/类/问题）    │
│  ├── InfoExtractor    → 从HTML提取关键信息                   │
│  └── ResponseFormatter → 格式化精简/详细答案                 │
├─────────────────────────────────────────────────────────────┤
│  数据层                                                     │
│  ├── 文档索引 (内存Map)  → 4500+ htm/html/md 文件索引        │
│  └── 错误数据库 (SQLite) → 本地存储用户遇到的错误记录         │
├─────────────────────────────────────────────────────────────┤
│  资料库 (本地文件，约60MB)                                   │
│  ├── MQL5_HELP/          → 官方文档 4500+ 文件              │
│  ├── MQL5_Algo_Book/     → 算法交易电子书                   │
│  └── Neural_Networks_Book/ → 神经网络电子书                 │
└─────────────────────────────────────────────────────────────┘
```

### 查询流程

```
用户查询 "OrderSend"
         │
         ▼
┌─────────────────────┐
│ 1. 查询分析         │ ← QueryAnalyzer 判断类型(函数查询)
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│ 2. 内部搜索         │ ← 在内存 Map 中匹配 key
│    (不调用API)      │    docIndex.get("ordersend")
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│ 3. 读取本地文件     │ ← fs.readFile("MQL5_HELP/ordersend.htm")
│    (纯IO操作)       │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│ 4. 信息提取         │ ← InfoExtractor 用正则提取:
│    (正则匹配)       │    语法/参数/返回值/示例
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│ 5. 格式化输出       │ ← ResponseFormatter
│    quick: ~500 tokens│
│    detailed: ~1500 tokens
└─────────────────────┘
```

---

## 💰 Token 消耗分析

### 核心结论：查询本身不消耗 Token，返回给 AI 的内容才消耗 Token

| 操作       | Token 消耗 | 说明                  |
| -------- | -------- | ------------------- |
| **文档存储** | ❌ 0      | 电子书存在本地，不计入 Token   |
| **索引构建** | ❌ 0      | 启动时本地构建 Map，纯内存操作   |
| **搜索匹配** | ❌ 0      | 本地 Map 查找，O(1) 复杂度  |
| **文件读取** | ❌ 0      | `fs.readFile` 本地 IO |
| **信息提取** | ❌ 0      | 正则表达式匹配，本地计算        |

### 消耗 Token 的环节：MCP 工具返回的内容

| 工具                       | 返回内容    | 估计 Token        | 推荐场景       |
| ------------------------ | ------- | --------------- | ---------- |
| `smart_query` (quick)    | 提取的精华信息 | **~500**        | ✅ 日常查询（推荐） |
| `smart_query` (detailed) | 完整提取信息  | ~1500           | 需要详细说明     |
| `search`                 | 文件列表    | ~200-500        | 浏览/确认文件    |
| `get`                    | 完整文档内容  | **~3000-10000** | ❌ 高消耗，谨慎使用 |

### 传统方式 vs 本服务器

```
传统方式：
AI → "查 OrderSend" → 调用外部API → 返回完整文档 → 消耗大量 Token
                                    (~5000 tokens)

本服务器：
AI → smart_query("OrderSend") 
   → 本地搜索 + 本地读取 + 本地提取 (0 Token)
   → 返回精华内容 (~500 tokens)

节省: 5000 - 500 = 4500 tokens (节省 90%)
```

### 总结

| 问题            | 答案                                                          |
| ------------- | ----------------------------------------------------------- |
| 电子书存储在哪？      | 本地 `MQL5_HELP/`, `MQL5_Algo_Book/`, `Neural_Networks_Book/` |
| 内置资料占用空间？     | ~60MB (纯本地存储)                                               |
| 查询过程是否调用 API？ | ❌ 不调用，纯本地操作                                                 |
| 返回结果消耗 Token？ | ✅ 是，但已优化到 ~500 tokens                                       |
| 如何最省 Token？   | 用 `smart_query` 的 `quick` 模式                                |
| 最耗 Token 的操作？ | `get` 工具（返回完整文档，~3000-10000 tokens）                         |

> **一句话总结**：电子书和索引存储在本地，搜索和提取完全在本地进行（零 API 调用）。唯一消耗 Token 的是 MCP 工具**返回给 AI 的内容**，而 `smart_query` 工具通过提取精华信息，将消耗从 ~5000 tokens 压缩到 ~500 tokens，**节省约 90% 的 Token**。

---

## 故障排除

### 1. 首次安装显示 "Failed to connect"

**症状**：运行 `claude mcp list` 显示 `mql5-help - ✗ Failed to connect`

**原因**：首次从 GitHub 安装时，npx 需要下载、安装依赖并编译 TypeScript，这个过程需要时间。

**解决方法**：

1. 等待 10-30 秒

2. 再次运行 `claude mcp list` 检查状态

3. 如果仍然失败，手动测试服务器：
   
   ```bash
   npx -y github:welldone-my-git/mql5-help-mcp
   ```
   
   你应该看到：
   
   ```
   🚀 MQL5 Help MCP Server 启动中...
   📂 文档目录: MQL5_HELP:... | MQL5_Algo_Book:... | Neural_Networks_Book:...
   ✅ 服务器就绪，等待连接...
   ```

### 2. Claude Code 命令行工具相关

**使用 Claude Code CLI 管理 MCP**：

```bash
# 查看所有 MCP 服务器
claude mcp list

# 查看特定 MCP 详情
claude mcp get mql5-help

# 删除 MCP 服务器
claude mcp remove mql5-help
```

### 3. 手动配置 MCP（不使用 CLI）

如果你想手动编辑配置文件，配置文件位置：

- **Windows**: `%USERPROFILE%\.claude\claude_desktop_config.json`（Claude Desktop）或 `%USERPROFILE%\.claude.json`（Claude Code）
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**: `~/.config/claude/claude_desktop_config.json`

添加如下配置：

```json
{
  "mcpServers": {
    "mql5-help": {
      "command": "npx",
      "args": ["-y", "github:welldone-my-git/mql5-help-mcp"]
    }
  }
}
```

### 4. 本地开发模式问题

**模块未找到/未编译**：

```bash
cd /path/to/mql5-help-mcp
npm install
npm run build
```

确保 `build/index.js` 存在。

### 5. 搜索不到文档

- 优先使用英文函数名（如 `OrderSend`、`CopyBuffer`、`OnTick`）
- 确认拼写正确，或试试更短的关键词
- 类名支持变体：`CTrade` 和 `Trade` 都可以搜索到

### 6. Windows 路径问题

在 JSON 配置文件中，路径需要正确转义：

```json
// ✅ 正确 - 使用正斜杠
"args": ["D:/my-program/mql5-help-mcp/build/index.js"]

// ✅ 正确 - 使用双反斜杠
"args": ["D:\\my-program\\mql5-help-mcp\\build\\index.js"]

// ❌ 错误 - 单反斜杠会被解析为转义字符
"args": ["D:\my-program\mql5-help-mcp\build\index.js"]
```

## 版本历史

### v1.8.0 (2026-06-16) - PDF 接入 + 多源文档支持

**🆕 新功能:**

- 📄 **PDF 文档索引** — 将 `.pdf` 文件放入 `sources[]` 路径即可自动索引，`search`/`smart_query`/`build_semantic_index` 全部支持
- 🏗️ 无需额外配置：Confluence HTML 导出、Notion Markdown 导出均已被现有引擎直接处理

**💡 设计亮点：**

- `pdf-parse`（基于 pdfjs-dist）动态导入，只有实际索引到 PDF 时才加载，对纯 HTML/MD 场景零冷启动影响
- PDF 提取文本后与其他格式走完全相同的混合搜索路径

---

### v1.7.0 (2026-06-16) - 语义搜索（Ollama + 混合排序）

**🎉 新功能:**

- 🔮 `build_semantic_index` 工具 — 调用本地 Ollama embedding 模型（`nomic-embed-text`，274MB）对所有文档向量化，增量运行，已有索引自动跳过
- 🔀 混合搜索模式 — 配置 embedding 后 `search` 自动启用（0.4×关键词 + 0.6×语义），支持中文/自然语言查询命中英文 API 文档
- 🏗️ 领域插件系统（Phase 1）— 核心引擎与 MQL5 专有逻辑解耦，`domain_plugin: null` 可作为纯通用知识库使用（→ [插件开发指南](PLUGIN_GUIDE.md)）
- ⚙️ Config v2 `sources[]` — 统一来源配置，向后兼容旧 `extraLibraries`

**💡 设计亮点：**

- **零新依赖**：向量以 `Float32Array → BLOB` 形式存入已有的 `better-sqlite3`，cosine 相似度纯 JS 实现
- **隐私优先**：Ollama 完全本地运行，文档内容不出内网
- **优雅降级**：未配置 Ollama 或服务不可达时，自动退化为纯关键词搜索，现有工具零感知
- **团队复用**：企业内一台服务器运行 Ollama，全团队共享同一 embedding 服务，边际成本为零

**📋 配置方式（~/.knowledge-mcp/config.json）：**

```json
{
  "embedding": {
    "provider": "ollama",
    "model": "nomic-embed-text",
    "url": "http://localhost:11434"
  }
}
```

### v1.6.0 (2026-06-16) - 代码质量闭环（analyze_structure + suggest_fix + 知识共享）

**🎉 新功能:**

- 🏗️ `analyze_structure` 工具 — 完全本地的 MQL5 代码静态分析，检测 6 类问题（句柄泄漏、OnTick 无保护开仓、无魔术数字、固定手数、缺少错误检查、SetAsSeries 遗漏），输出 0-100 评分 + 行号定位 + 修复建议，零 API 成本
- 💾 `record_fix` 工具 — 将 Claude 给出的修复方案存入本地 SQLite，下次遇到相同问题直接命中，无需重新分析
- 📋 `list_fixes` 工具 — 查看/搜索已积累的修复模式库，按使用频率排序
- 🔄 `manage_knowledge` 工具 — 导出/导入预处理库知识包，团队可共享 Haiku 分析结果（节省 API 成本）

**💡 闭环设计：**

```
analyze_structure → 发现问题 → Claude 修复 → record_fix → 积累
analyze_code → 查 fix patterns → 命中则直接返回修复（跳过 API）
manage_knowledge export → 分享给团队 → import → 他人零成本获取知识
```

**🔗 整合优化：**

- `analyze_code` 现在自动查询本地 `fix_patterns.db`，若有匹配则在库知识摘要中附上已验证修复
- `analyze_structure` 同样整合 fix patterns，检测到已知问题时直接提供代码片段

### v1.5.0 (2026-06-16) - 智能库分析（B+C 架构）

**🎉 新功能:**

- 🤖 `preprocess_library` 工具 — 调用 Claude Haiku 分析外部库的 `.mqh` 文件，提取类/方法/用途/典型用法，结果缓存到本地 JSON，后续零成本复用。100 个文件约 $0.10
- 🧠 `analyze_code` 工具 — 接收用户 MQL5 代码，从本地缓存加载库知识，检测代码中可优化的原始写法，组装结构化上下文返回给 Claude，由 Claude 给出具体到行号、可编译的改进建议

**💡 设计理念：**

- **B（预处理）**：Haiku 只在建库知识时调用一次，理解库的语义
- **C（上下文组装）**：MCP 不做推理，只组装最相关的知识摘要
- **Claude 做推理**：拿到结构化上下文后，给出精准可用的代码建议

### v1.4.0 (2026-06-16) - 诊断增强 + 外部代码库支持

**🎉 新功能:**

- 🔬 `diagnose_error` 工具 — 粘贴 MetaEditor 完整编译日志，自动解析所有 error/warning 行，去重后逐条匹配迁移映射与历史方案，输出结构化诊断报告
- 📚 `list_libraries` 工具 — 列出所有已加载资料库（内置 + 外部），显示文件数量与配置路径
- 🔌 外部代码库支持 — 通过 `~/.knowledge-mcp/config.json` 挂载任意本地 MQL5 开源库（`.mq5/.mqh`），无需修改源码
- 🗺️ MQL4→MQL5 迁移映射从 4 条扩展至 18 条，新增 `MarketInfo`、`RefreshRates`、指标句柄、账户信息等

**🔧 Bug 修复:**

- `searchSimilarErrors` 改用 `OR` 逻辑，避免多词查询因 `AND` 过严漏匹配历史错误
- 文档索引改为 first-wins，确保 `MQL5_HELP` 官方文档优先级不被同名电子书文件覆盖
- `SmartQueryEngine` 改为模块级单例，不再每次请求重新实例化
- `stripHtml` 提取为公共 `utils.ts`，消除 `index.ts` / `smart-query.ts` 重复代码

**💡 使用外部库：**

在 `~/.knowledge-mcp/config.json` 中添加：
```json
{
  "extraLibraries": [
    { "key": "EA31337", "path": "/path/to/EA31337", "description": "EA31337 framework" }
  ]
}
```
重启服务后，`search`、`get`、`smart_query` 均可命中外部库中的文件。

### v1.3.0 (2024-11-25) - 错误收集系统

**🎉 新功能:**

- 🗄️ 本地错误数据库（SQLite）- 无需网络服务器
- 📝 `log_error` 工具 - 记录编译错误及解决方案
- 📊 `list_common_errors` 工具 - 查看高频错误 TOP N
- 🔧 `manage_error_db` 工具 - 导出/导入/统计错误库
- 🔍 `smart_query` 增强 - 优先从错误数据库查询历史解决方案

**💡 核心特性:**

- 完全本地化存储（`~/.knowledge-mcp/mql5_errors.db`）
- 智能去重：相同错误自动合并并计数
- 隐私保护：导出时可选移除文件路径
- 团队协作：支持导出/导入 JSON 格式错误库
- 相似度搜索：模糊匹配历史错误关键词

**🎯 使用场景:**

1. 遇到错误 → `smart_query` 自动查询数据库
2. 解决后 → `log_error` 记录方案供下次使用
3. 学习 → `list_common_errors` 了解常见问题
4. 协作 → `manage_error_db` 分享团队知识库

**📊 性能优化:**

- 数据库索引优化：错误代码、出现次数、时间戳
- WAL 模式提升并发性能
- 增量更新减少重复写入

### v1.2.0 (2024-11-24) - Smart Query重大更新

**🎉 新功能:**

- ✨ 新增 `smart_query` 智能查询工具
- 🎯 支持错误诊断、函数查询、类查询、概念查询
- 📉 节省80%+ token消耗 (4000 → 500 tokens)
- ⚡ 响应速度提升60%
- 🆓 完全本地化，零API成本，无需外部服务

**💡 核心特性:**

- 智能识别5种查询类型 (error/function/class/howto/concept)
- 基于正则表达式精准提取关键信息 (语法/参数/示例/注意事项)
- 两种模式: quick(~500 tokens) 和 detailed(~1500 tokens)
- 内置MQL4→MQL5迁移提示

**📚 新增文档:**

- `QUICK_START_SMART_QUERY.md` - 3分钟快速上手
- `SMART_QUERY_GUIDE.md` - 完整使用指南  
- `AI_USAGE_GUIDE.md` - 针对编译错误修复场景

### v1.0.0 (2024-11-01) - 首次发布

- 基础搜索、获取、浏览功能
- 支持4500+ MQL5官方文档
- 包含2本电子书资源

---

## 路线图（Roadmap）

- ✅ [高] 智能错误匹配 - **v1.2.0已实现**

- ✅ [高] 常见错误解决方案库 - **v1.2.0已实现**

- ✅ [高] 错误收集与持久化 - **v1.3.0已实现**

- ✅ [高] 团队错误库共享 - **v1.3.0已实现**

- ✅ [高] 错误自动诊断：分析编译输出并提供解决方案 - **v1.4.0已实现**

- ✅ [中] 上下文感知搜索增强：MQL4→MQL5 迁移映射扩展至18条 - **v1.4.0已实现**

- ✅ [新] 外部开源代码库支持：通过 config.json 挂载 .mq5/.mqh 库 - **v1.4.0已实现**

- ✅ [新] 智能库分析：Haiku 预处理 + 上下文组装，analyze_code 给出精准建议 - **v1.5.0已实现**

- ✅ [新] 代码结构静态分析：analyze_structure 检测6类问题，零API成本 - **v1.6.0已实现**

- ✅ [新] suggest_fix 闭环：record_fix/list_fixes 积累修复模式，analyze_code 自动命中 - **v1.6.0已实现**

- ✅ [新] 知识库共享：manage_knowledge 导出/导入预处理知识，团队复用 - **v1.6.0已实现**

- ✅ [新] 语义搜索：Ollama + 混合排序，中文/自然语言查询命中英文文档 - **v1.7.0已实现**

- ✅ [新] 领域插件系统：核心引擎通用化，MQL5 专有逻辑插件化 - **v1.7.0已实现**

- ✅ [新] PDF 文档索引支持：`.pdf` 自动解析为纯文本，参与搜索与语义索引 - **v1.8.0已实现**

- [ ] [高] 代码示例库扩展：更多EA模板与策略示例

- [ ] [中] 交互式帮助：多轮对话支持

- [ ] [中] 学习路径推荐：结构化教程

- [ ] [中] 错误预测：基于代码模式预警潜在问题

- [ ] [低] 统一索引两本电子书（browse 分类支持）

- [ ] [低] 标签系统与版本标注

---

## 许可证与鸣谢

- 许可证：MIT（详见 [LICENSE](LICENSE)）
- MQL5文档版权归 MetaQuotes Ltd. 所有，本工具仅供开发辅助使用
- 文档版权：MQL5 官方文档归 MetaQuotes Ltd. 所有；两本电子书版权归原作者所有
- 致谢：Model Context Protocol、MQL5 社区与贡献者

---

专为量化开发者打造的“问题驱动”MQL5 知识助手：不仅能查文档，更帮你定位与解决真实问题。
