# 通用知识库改造计划

> 目标：将 mql5-help-mcp 从 MQL5 专用工具演进为**任意领域可配置的知识库 MCP 服务器**，支持企业私有化部署。

---

## 一、现状分析

### 已经是通用的（不动）

| 模块 | 文件 | 说明 |
|---|---|---|
| 知识预处理 | `library-knowledge.ts` | Haiku 分析任意 .mqh/.md，结构化缓存 |
| 修复模式库 | `fix-patterns.ts` | 通用问题→修复 SQLite |
| 错误数据库 | `error-db.ts` | 通用编译错误记录 |
| 知识共享 | `manage_knowledge` | 导出/导入已与域无关 |
| 文件索引 | `buildIndex()` 核心 | 遍历+哈希，不含 MQL5 语义 |

### MQL5 专有（需插件化）

| 代码位置 | 专有内容 | 影响范围 |
|---|---|---|
| `index.ts` `BUILTIN_ROOTS` | 硬编码 MQL5_HELP 等3个路径 | 启动时写死 |
| `utils.ts` `MIGRATION_HINTS` | 18 条 MQL4→MQL5 映射 | diagnose + smart_query |
| `smart-query.ts` `SmartQueryEngine` | MQL5 错误码/函数/类识别逻辑 | smart_query 工具 |
| `smart-query.ts` `DiagnoseEngine` | MetaEditor 编译日志格式 | diagnose_error 工具 |
| `code-analyzer.ts` | MQL5 6 条静态分析规则 | analyze_structure 工具 |

**结论：专有逻辑边界清晰，核心引擎已 ~70% 通用。**

---

## 二、目标架构

```
config.json（用户配置）
├── sources[]          ← 替代硬编码 BUILTIN_ROOTS
├── domain_plugin      ← "mql5" | "java" | null
└── embedding{}        ← Ollama / Voyage / OpenAI

src/
├── core/              ← 与域无关的引擎（Phase 1 拆分）
│   ├── server.ts      ← MCP server 启动、工具注册框架
│   ├── file-index.ts  ← 文件遍历、哈希、索引
│   ├── search.ts      ← 关键词搜索
│   ├── embedding.ts   ← 向量化 + 混合搜索（Phase 2 新增）
│   ├── knowledge-store.ts
│   ├── fix-patterns.ts
│   └── error-db.ts
├── plugins/           ← 领域插件（Phase 1 新增）
│   └── mql5/
│       ├── index.ts         ← 插件入口，注册专有工具
│       ├── smart-query.ts   ← 移入
│       ├── code-analyzer.ts ← 移入
│       ├── diagnose.ts      ← 移入
│       └── hints.ts         ← MIGRATION_HINTS 移入
└── index.ts           ← 入口，加载 core + plugin
```

---

## 三、Config Schema v2

```json
{
  "sources": [
    {
      "key": "MQL5_HELP",
      "path": "/absolute/path/to/MQL5_HELP",
      "type": "html",
      "priority": 1,
      "description": "MQL5 官方文档"
    },
    {
      "key": "my-java-sdk",
      "path": "/work/java-sdk/docs",
      "type": "html",
      "priority": 2
    }
  ],
  "domain_plugin": "mql5",
  "embedding": {
    "provider": "ollama",
    "model": "nomic-embed-text",
    "url": "http://localhost:11434",
    "index_path": "~/.knowledge-mcp/semantic.index"
  }
}
```

- `sources` 替代 `BUILTIN_ROOTS` + `extraLibraries`（合并为一个字段）
- `domain_plugin: null` 时，MQL5 专有工具（diagnose_error、analyze_structure）不注册
- `embedding` 缺省时，退化为纯关键词搜索（向后兼容）

---

## 四、插件接口设计

```typescript
// src/core/plugin.ts
export interface DomainPlugin {
  name: string;

  /** 注册该领域专有的 MCP 工具定义 */
  getToolDefinitions(): ToolDefinition[];

  /** 处理该领域专有工具的调用 */
  handleToolCall(name: string, args: unknown, ctx: PluginContext): Promise<ToolResult>;

  /** 可选：对查询做领域感知的预处理（如 MQL5 错误码识别） */
  preprocessQuery?(query: string): EnrichedQuery;
}

export interface PluginContext {
  docIndex: Map<string, string>;  // filename → absPath
  queryEngine: CoreQueryEngine;
  knowledgeStore: KnowledgeStore;
  fixPatternsDb: FixPatternsDb;
}
```

MQL5 插件只需实现这个接口，`core/server.ts` 不含任何 MQL5 知识。

---

## 五、Phase 2：语义搜索层

### 为什么选 Ollama + nomic-embed-text

| 方案 | 成本 | 隐私 | 离线 | 团队共用 |
|---|---|---|---|---|
| Voyage AI API | ~$0/月（免费额度大） | 数据出境 | ✗ | ✓ |
| OpenAI API | 极低但变动 | 数据出境 | ✗ | ✓ |
| **Ollama 本地** | 固定（服务器成本）| **数据不出内网** | ✓ | **一台服务多人用** |

企业场景下数据不出内网是刚需，Ollama 是唯一满足的选项。

### 实现方案：混合搜索

```
用户 query
    ├── 关键词路径 → 现有 docIndex 匹配 → BM25 分数
    └── 语义路径  → embed(query) → FAISS 近邻 → 余弦相似度分数
              ↓
        合并排序（0.4 × BM25 + 0.6 × 余弦）
              ↓
        Top-K 结果
```

索引构建（一次性，离线）：
```
build_semantic_index 工具
  → 读取所有已索引文档
  → 批量 embed（Ollama，本地）
  → 写 ~/.knowledge-mcp/semantic.index（FAISS flat）
  → 完成后，search/smart_query 自动启用混合模式
```

### 向量存储选项

- **FAISS**（推荐）：精度高，支持 4500 文档绰绰有余，需要 Node.js binding（`faiss-node`）
- **sqlite-vec**：SQLite 扩展，零额外依赖，性能略低但够用
- 推荐先用 `sqlite-vec`，它和现有 `better-sqlite3` 无缝集成，不引入新依赖

---

## 六、Phase 3：多源文档接入

| 文档类型 | 现状 | 改造 |
|---|---|---|
| HTML | ✅ 支持 | 通用化 stripHtml |
| Markdown | ✅ 支持 | 已可用 |
| MQL5 代码 .mq5/.mqh | ✅ 支持 | 移入 mql5 插件 |
| PDF | ✅ | `pdf-parse`，动态导入，提取纯文本 |
| Confluence export | ✅ | HTML 导出，现有引擎直接处理 |
| Notion export | ✅ | Markdown 导出，现有引擎直接处理 |

PDF 支持是企业知识库最高频的需求，优先级高。

---

## 七、企业部署拓扑

```
内网
┌─────────────────────────────────────────────────┐
│                                                 │
│  开发者 A                  开发者 B              │
│  Claude Code               Claude Code          │
│     ↓ MCP                     ↓ MCP             │
│  MCP Server                MCP Server           │
│  (本地进程)                (本地进程)             │
│     │                         │                 │
│     └──────────┬──────────────┘                 │
│                ↓                                │
│        Ollama Server（共享）                     │
│        http://192.168.1.100:11434               │
│        nomic-embed-text 274MB                   │
│                ↓                                │
│        FAISS 索引（NFS/共享存储）                │
│                                                 │
│  知识包通过 manage_knowledge export/import 同步  │
└─────────────────────────────────────────────────┘
```

---

## 八、实施计划

### Phase 1 — 插件化（当前开始）
**目标：核心引擎与 MQL5 解耦，config v2 落地**

- [ ] 新建 `src/core/` 和 `src/plugins/mql5/`
- [ ] 定义 `DomainPlugin` 接口
- [ ] 将 MQL5 专有代码移入 `plugins/mql5/`
- [ ] `BUILTIN_ROOTS` 改由 `config.json sources[]` 驱动
- [ ] `extraLibraries` 合并进 `sources[]`（向后兼容旧 config）
- [ ] 更新 README，新增 `PLUGIN_GUIDE.md`

**验收：`domain_plugin: null` 时启动，所有通用工具正常，MQL5 专有工具不出现。**

### Phase 2 — 语义搜索（✅ 完成）
**目标：Ollama + SQLite BLOB 混合搜索**

- [x] `src/core/embedding.ts`：Ollama REST API + 纯 JS cosine + VectorStore（better-sqlite3 BLOB）
- [x] 零新依赖：Float32Array 序列化为 BLOB 存入现有 SQLite，内存缓存加速查询
- [x] 新增 `build_semantic_index` 工具（一次性建索引，支持增量 + force_reindex）
- [x] `search` 支持混合模式（0.4×关键词 + 0.6×语义），config 无 embedding 时零感知降级
- [x] 结果显示搜索模式 + 匹配分数百分比

**验收：** 配置 Ollama + `nomic-embed-text` 后，中文 query "如何设置止损" 可命中 OrderModify 相关文档。

**验收：中文 query "如何设置止损" 能命中 OrderModify 相关文档。**

### Phase 3 — 多源接入（✅ 完成）
- [x] PDF ingestion（`pdf-parse`，动态导入，零冷启动开销）
- [x] Confluence HTML export 适配（复用现有 HTML 引擎，无需改造）
- [x] Notion / 内部 Wiki Markdown 导出（复用现有 MD 引擎，无需改造）
- [x] 重命名项目为 `knowledge-mcp`（npm 包名 + 二进制命令，`~/.mql5-help-mcp` 向后兼容自动回退）

---

## 九、向后兼容承诺

- 旧 `config.json`（含 `extraLibraries`）自动迁移，不报错
- 所有现有 15 个工具接口不变
- Phase 1 完成后，现有 MQL5 用户零感知

