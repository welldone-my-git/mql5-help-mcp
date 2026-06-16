# 领域插件开发指南

本服务器的核心引擎（文件索引、关键词搜索、语义搜索、知识库、修复模式库）与具体领域完全解耦。**领域插件**负责注册该领域专有的 MCP 工具，并可选地对查询做领域感知的预处理。

---

## 目录

1. [插件是什么](#插件是什么)
2. [接口定义](#接口定义)
3. [新建插件：步骤](#新建插件步骤)
4. [完整示例：Java SDK 插件](#完整示例java-sdk-插件)
5. [PluginContext 可用资源](#plugincontext-可用资源)
6. [激活插件](#激活插件)
7. [无插件模式（纯通用知识库）](#无插件模式纯通用知识库)
8. [注意事项](#注意事项)

---

## 插件是什么

每次调用 MCP 工具时，服务器的处理流程如下：

```
Claude / AI 助手
    ↓  MCP tool call
服务器 (src/index.ts)
    ├── 核心工具（search, get_doc, smart_query, manage_knowledge …）→ 直接处理
    └── 未知工具名 → 路由给 activePlugin.handleToolCall()
```

插件做三件事：

| 方法 | 作用 | 是否必须 |
|---|---|---|
| `getToolDefinitions()` | 告诉服务器该插件提供哪些工具及其 JSON Schema | ✅ |
| `handleToolCall()` | 处理这些工具的调用 | ✅ |
| `preprocessQuery()` | 在 `search`/`smart_query` 之前，对查询做领域感知的扩展 | 可选 |

---

## 接口定义

```typescript
// src/core/plugin.ts

export interface DomainPlugin {
  readonly name: string;

  /** 返回该插件注册的所有 MCP 工具定义 */
  getToolDefinitions(): ToolDefinition[];

  /** 处理该插件工具的调用，返回 MCP 响应内容 */
  handleToolCall(
    toolName: string,
    args: unknown,
    ctx: PluginContext
  ): Promise<PluginResult>;

  /** 可选：对 search/smart_query 的查询做领域感知预处理 */
  preprocessQuery?(query: string, ctx: PluginContext): EnrichedQuery;
}

export interface PluginResult {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
}

export interface ToolDefinition {
  name: string;
  description: string;
  inputSchema: {
    type: "object";
    properties: Record<string, unknown>;
    required?: string[];
  };
}

export interface PluginContext {
  /** 文件名（无扩展）→ DocEntry（absPath / relPath / repo） */
  docIndex: Map<string, DocEntry>;
  knowledgeStore: KnowledgeStore;
  fixPatternsDb: FixPatternsDb;
  loadedLibraries: Array<{ key: string; fileCount: number; rootPath: string }>;
}

export interface EnrichedQuery {
  original: string;   // 原始查询（原样传回即可）
  expanded: string;   // 用于实际搜索的查询（可追加同义词、术语映射等）
  hint?: string;      // 显示给用户的额外提示（可选）
}
```

---

## 新建插件：步骤

### 1. 创建目录

```
src/plugins/<你的插件名>/
└── index.ts
```

插件名只能包含小写字母、数字和连字符，和 `config.json` 中 `domain_plugin` 的值保持一致。

### 2. 实现接口

```typescript
// src/plugins/<pluginName>/index.ts

import type { DomainPlugin, PluginContext, PluginResult, ToolDefinition, EnrichedQuery } from "../../core/plugin.js";

class MyPlugin implements DomainPlugin {
  readonly name = "<pluginName>";

  getToolDefinitions(): ToolDefinition[] {
    return [
      {
        name: "my_tool",
        description: "简短描述（供 AI 助手理解何时调用此工具）",
        inputSchema: {
          type: "object",
          properties: {
            param1: { type: "string", description: "参数说明" },
          },
          required: ["param1"],
        },
      },
    ];
  }

  async handleToolCall(toolName: string, args: unknown, ctx: PluginContext): Promise<PluginResult> {
    switch (toolName) {
      case "my_tool": {
        const { param1 } = args as { param1: string };
        // 使用 ctx.docIndex / ctx.fixPatternsDb / ctx.knowledgeStore 等
        return { content: [{ type: "text", text: `结果: ${param1}` }] };
      }
      default:
        return {
          content: [{ type: "text", text: `❌ 未知工具: ${toolName}` }],
          isError: true,
        };
    }
  }

  // 可选：query 预处理（不需要可以删掉整个方法）
  preprocessQuery(query: string, _ctx: PluginContext): EnrichedQuery {
    // 示例：把 Java 缩写扩展为全称
    const expansions: Record<string, string> = {
      jpa: "JPA Java Persistence API",
      orm: "ORM Hibernate JPA mapping",
    };
    const lower = query.toLowerCase().trim();
    const extra = expansions[lower] ?? "";
    return {
      original: query,
      expanded: extra ? `${extra} ${query}` : query,
      hint: extra ? `已扩展查询关键词：${extra}` : undefined,
    };
  }
}

// ⚠️ 导出名称必须是 `${pluginName}Plugin`（驼峰）或 `default`
export const myPlugin: DomainPlugin = new MyPlugin();
```

### 3. 导出命名约定

服务器按以下顺序查找导出：

```typescript
// src/index.ts（内部逻辑，无需修改）
const mod = await import(`./plugins/${pluginName}/index.js`);
const plugin = mod[`${pluginName}Plugin`] ?? mod.default;
```

- `domain_plugin: "java"` → 期望导出 `javaPlugin` 或 `default`
- `domain_plugin: "my-sdk"` → 期望导出 `my-sdkPlugin` 或 `default`（建议用 `default` 避免连字符问题）

### 4. 配置激活

在 `~/.knowledge-mcp/config.json` 中指定：

```json
{
  "domain_plugin": "java",
  "sources": [
    { "key": "java-sdk", "path": "/work/java/docs", "type": "html" },
    { "key": "spring-ref", "path": "/work/spring/reference", "type": "html" }
  ]
}
```

重启 MCP 服务器后生效。启动日志会打印：

```
🔌 已加载领域插件: java
```

---

## 完整示例：Java SDK 插件

以下是一个实际可用的插件骨架，展示了领域工具 + 查询预处理的完整结构。

```typescript
// src/plugins/java/index.ts

import type { DomainPlugin, PluginContext, PluginResult, ToolDefinition, EnrichedQuery } from "../../core/plugin.js";

// 术语映射表（Java 常见缩写/别名 → 标准查询关键词）
const TERM_MAP: Record<string, string> = {
  jpa:         "JPA Java Persistence API EntityManager",
  di:          "dependency injection Spring @Autowired",
  ioc:         "IoC inversion of control Spring container",
  dto:         "DTO data transfer object",
  dao:         "DAO repository pattern JPA",
  orm:         "ORM Hibernate JPA mapping",
  stream:      "Java Stream API filter map collect",
  optional:    "Optional orElse orElseThrow isPresent",
  lambda:      "lambda expression functional interface",
  completable: "CompletableFuture async thenApply",
};

class JavaPlugin implements DomainPlugin {
  readonly name = "java";

  getToolDefinitions(): ToolDefinition[] {
    return [
      {
        name: "explain_exception",
        description:
          "📋 Java 异常分析：粘贴 Java 异常堆栈（StackTrace），自动提取异常类型与根因行，搜索本地文档并匹配历史修复模式。",
        inputSchema: {
          type: "object",
          properties: {
            stacktrace: {
              type: "string",
              description: "Java 异常的完整堆栈输出",
            },
          },
          required: ["stacktrace"],
        },
      },
    ];
  }

  async handleToolCall(toolName: string, args: unknown, ctx: PluginContext): Promise<PluginResult> {
    switch (toolName) {
      case "explain_exception": {
        const { stacktrace } = args as { stacktrace: string };
        const lines = stacktrace.split("\n").map(l => l.trim()).filter(Boolean);

        // 提取异常类型（第一行，如 "java.lang.NullPointerException: ..."）
        const exceptionLine = lines.find(l => /^[\w.]+Exception|^[\w.]+Error/.test(l)) ?? lines[0];
        const exceptionClass = exceptionLine?.split(":")[0]?.trim() ?? "";

        // 查本地修复模式
        const fixes = exceptionClass
          ? ctx.fixPatternsDb.search(exceptionClass.substring(0, 100))
          : [];

        // 搜索文档（复用核心索引）
        const docMatches: string[] = [];
        if (exceptionClass) {
          const simpleClass = exceptionClass.split(".").pop() ?? exceptionClass;
          for (const [key] of ctx.docIndex.entries()) {
            if (key.includes(simpleClass.toLowerCase())) {
              docMatches.push(key);
              if (docMatches.length >= 3) break;
            }
          }
        }

        const out: string[] = [
          `## 异常分析：\`${exceptionClass || "未识别"}\``,
          "",
          `**堆栈摘要（前5行）:**`,
          "```",
          lines.slice(0, 5).join("\n"),
          "```",
        ];

        if (docMatches.length > 0) {
          out.push("", `**相关文档（使用 get_doc 查看）:** ${docMatches.join(", ")}`);
        }

        if (fixes.length > 0) {
          out.push("", "**本地已记录的修复模式:**");
          for (const fix of fixes.slice(0, 3)) {
            out.push(`- **${fix.pattern_description}**：${fix.fix_description}`);
            if (fix.fixed_snippet) {
              out.push("```java\n" + fix.fixed_snippet + "\n```");
            }
          }
        }

        return { content: [{ type: "text", text: out.join("\n") }] };
      }

      default:
        return {
          content: [{ type: "text", text: `❌ Java 插件未知工具: ${toolName}` }],
          isError: true,
        };
    }
  }

  preprocessQuery(query: string, _ctx: PluginContext): EnrichedQuery {
    const lower = query.toLowerCase().replace(/[^a-z0-9]/g, "");
    const expansion = TERM_MAP[lower];
    if (expansion) {
      return {
        original: query,
        expanded: `${expansion} ${query}`,
        hint: `Java 术语扩展：${expansion}`,
      };
    }
    return { original: query, expanded: query };
  }
}

export const javaPlugin: DomainPlugin = new JavaPlugin();
```

---

## PluginContext 可用资源

| 字段 | 类型 | 说明 |
|---|---|---|
| `docIndex` | `Map<string, DocEntry>` | 所有已索引文件（键：文件名无扩展名，值含 absPath/relPath/repo） |
| `knowledgeStore` | `KnowledgeStore` | 调用 `knowledgeStore.get(key)` 获取 Haiku 预处理过的结构化知识 |
| `fixPatternsDb` | `FixPatternsDb` | 调用 `fixPatternsDb.search(text)` 模糊匹配历史修复模式 |
| `loadedLibraries` | `Array<{key, fileCount, rootPath}>` | 当前已挂载的来源列表 |

**`KnowledgeStore.get(key)`** 返回：
```typescript
{
  summary: string;           // 模块/类的一句话摘要
  classes: ClassInfo[];      // 包含 methods[], fields[], description
  keyFunctions: FuncInfo[];  // 独立函数列表
  usagePatterns: string[];   // 典型使用场景
  relatedKeys: string[];     // 相关文件键名
}
```

**`FixPatternsDb.search(text)`** 返回：
```typescript
Array<{
  pattern_description: string;
  fix_description: string;
  fixed_snippet?: string;
  tags?: string;
}>
```

---

## 激活插件

`~/.knowledge-mcp/config.json`：

```json
{
  "domain_plugin": "java",
  "sources": [
    {
      "key": "JAVA_DOCS",
      "path": "/path/to/java-docs",
      "type": "html",
      "priority": 1
    }
  ],
  "embedding": {
    "provider": "ollama",
    "model": "nomic-embed-text",
    "url": "http://localhost:11434"
  }
}
```

`domain_plugin` 的值对应 `src/plugins/<值>/index.ts` 的目录名。

---

## 无插件模式（纯通用知识库）

将 `domain_plugin` 显式设为 `null`：

```json
{
  "domain_plugin": null,
  "sources": [
    { "key": "internal-wiki", "path": "/wiki/export", "type": "html" }
  ]
}
```

此时 MQL5 专有工具（`diagnose_error`、`analyze_structure`）不注册，服务器作为纯通用知识库运行。核心工具（`search`、`get_doc`、`smart_query`、`manage_knowledge` 等）全部正常工作。

---

## 注意事项

- **工具名唯一**：插件工具名不能与核心工具名冲突（核心工具见 `src/index.ts` 的 `ListToolsRequestSchema` 处理器）。
- **异步安全**：`handleToolCall` 是 async，可以安全地做文件 IO 或网络请求。
- **错误处理**：返回 `{ content: [...], isError: true }` 而不是 throw，这样 AI 助手能读到错误信息。
- **构建后生效**：修改 TypeScript 源码后需 `npm run build` 再重启 MCP 服务器。
- **导出约定**：优先使用 `export const ${pluginName}Plugin`；含连字符的插件名（如 `my-sdk`）建议改用 `export default`。
