/**
 * Java Domain Plugin
 * Owns: explain_exception, review_java_code
 * Enhances: search / smart_query (via preprocessQuery)
 */

import type {
  DomainPlugin,
  PluginContext,
  PluginResult,
  ToolDefinition,
  EnrichedQuery,
} from "../../core/plugin.js";

// ── Term expansion table ───────────────────────────────────────────────────────

const TERM_MAP: Record<string, string> = {
  jpa:         "JPA Java Persistence API EntityManager Repository",
  di:          "dependency injection Spring @Autowired @Bean",
  ioc:         "IoC inversion of control Spring ApplicationContext",
  dto:         "DTO data transfer object mapping",
  dao:         "DAO repository pattern JPA persist",
  orm:         "ORM Hibernate JPA entity mapping",
  stream:      "Java Stream API filter map collect reduce",
  optional:    "Optional orElse orElseThrow isPresent flatMap",
  lambda:      "lambda expression functional interface Consumer Supplier",
  completable: "CompletableFuture thenApply thenCompose async",
  gc:          "garbage collection GC JVM heap tuning",
  npe:         "NullPointerException null check Optional",
  oome:        "OutOfMemoryError heap memory JVM -Xmx",
  cce:         "ClassCastException instanceof generics",
  iae:         "IllegalArgumentException validation precondition",
  ise:         "IllegalStateException lifecycle initialization",
};

// ── Static analysis rules ─────────────────────────────────────────────────────

interface CodeIssue {
  line: number;
  rule: string;
  detail: string;
  severity: "error" | "warning" | "info";
}

const RULES: Array<{
  id: string;
  severity: CodeIssue["severity"];
  label: string;
  test(line: string, allLines: string[], idx: number): string | null;
}> = [
  {
    id: "BROAD_CATCH",
    severity: "warning",
    label: "过宽的 catch",
    test(line) {
      return /catch\s*\(\s*(Exception|Throwable)\s+/.test(line)
        ? `catch (Exception/Throwable) 会掩盖真实错误类型，建议细化异常类型`
        : null;
    },
  },
  {
    id: "EMPTY_CATCH",
    severity: "error",
    label: "空 catch 块",
    test(line, lines, idx) {
      if (!/catch\s*\(/.test(line)) return null;
      // look for "} catch (...) {" followed by "}" with nothing in between
      const body = lines.slice(idx + 1, idx + 4).join(" ").trim();
      return /^\}/.test(body) ? `catch 块为空，异常被静默吞掉` : null;
    },
  },
  {
    id: "SYSOUT",
    severity: "info",
    label: "System.out.println",
    test(line) {
      return /System\.out\.print/.test(line)
        ? `生产代码中应使用日志框架（SLF4J/Logback）而非 System.out.println`
        : null;
    },
  },
  {
    id: "RAW_TYPE",
    severity: "warning",
    label: "原始泛型类型",
    test(line) {
      return /\b(List|Map|Set|Collection|ArrayList|HashMap|HashSet)\s+\w+\s*=/.test(line) &&
        !/\b(List|Map|Set|Collection|ArrayList|HashMap|HashSet)</.test(line)
        ? `使用了原始类型，应加泛型参数（如 List<String>）`
        : null;
    },
  },
  {
    id: "STRING_CONCAT_LOOP",
    severity: "warning",
    label: "循环内字符串拼接",
    test(line, lines, idx) {
      if (!/\+\s*=|=.*\+.*String|String.*\+/.test(line)) return null;
      // check if inside a for/while (look back up to 5 lines)
      const prev = lines.slice(Math.max(0, idx - 5), idx).join(" ");
      return /\b(for|while)\b/.test(prev)
        ? `循环内用 + 拼接 String 性能差，改用 StringBuilder.append()`
        : null;
    },
  },
  {
    id: "MUTABLE_STATIC",
    severity: "warning",
    label: "可变静态字段",
    test(line) {
      return /\bstatic\b(?!.*\bfinal\b).*\b(List|Map|Set|ArrayList|HashMap)\b/.test(line)
        ? `非 final 的 static 集合字段在多线程环境下存在竞态风险`
        : null;
    },
  },
  {
    id: "NULLABLE_RETURN",
    severity: "info",
    label: "未注解的可空返回值",
    test(line) {
      return /\breturn null\b/.test(line) && !/\/\/.*return null/.test(line)
        ? `直接返回 null 容易导致 NPE，考虑返回 Optional<T> 或抛出异常`
        : null;
    },
  },
];

function analyzeJavaCode(code: string): CodeIssue[] {
  const lines = code.split("\n");
  const issues: CodeIssue[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*\/\//.test(line)) continue; // skip comment lines
    for (const rule of RULES) {
      const msg = rule.test(line, lines, i);
      if (msg) {
        issues.push({ line: i + 1, rule: rule.id, detail: msg, severity: rule.severity });
      }
    }
  }
  return issues;
}

// ── Plugin ────────────────────────────────────────────────────────────────────

class JavaPlugin implements DomainPlugin {
  readonly name = "java";

  getToolDefinitions(): ToolDefinition[] {
    return [
      {
        name: "explain_exception",
        description:
          "☕ Java 异常分析：粘贴完整的异常堆栈（StackTrace），自动提取异常类型与根因行，搜索本地文档并匹配历史修复模式，输出结构化诊断报告。",
        inputSchema: {
          type: "object",
          properties: {
            stacktrace: {
              type: "string",
              description: "Java 异常的完整堆栈输出（包含 Caused by 链）",
            },
          },
          required: ["stacktrace"],
        },
      },
      {
        name: "review_java_code",
        description:
          "🔍 Java 代码静态审查：检测空 catch、过宽异常捕获、System.out、原始泛型、循环字符串拼接、可变静态字段等7类常见问题，输出带行号的审查报告。完全本地，零 API 成本。",
        inputSchema: {
          type: "object",
          properties: {
            code: {
              type: "string",
              description: "需要审查的 Java 代码片段",
            },
          },
          required: ["code"],
        },
      },
    ];
  }

  async handleToolCall(toolName: string, args: unknown, ctx: PluginContext): Promise<PluginResult> {
    switch (toolName) {

      case "explain_exception": {
        const { stacktrace } = args as { stacktrace: string };
        return { content: [{ type: "text", text: this.diagnoseException(stacktrace, ctx) }] };
      }

      case "review_java_code": {
        const { code } = args as { code: string };
        return { content: [{ type: "text", text: this.reviewCode(code, ctx) }] };
      }

      default:
        return {
          content: [{ type: "text", text: `❌ Java 插件未知工具: ${toolName}` }],
          isError: true,
        };
    }
  }

  preprocessQuery(query: string, _ctx: PluginContext): EnrichedQuery {
    const key = query.toLowerCase().replace(/[^a-z0-9]/g, "");
    const expansion = TERM_MAP[key];
    if (expansion) {
      return {
        original: query,
        expanded: `${expansion} ${query}`,
        hint: `Java 术语扩展：${expansion}`,
      };
    }
    return { original: query, expanded: query };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  private diagnoseException(stacktrace: string, ctx: PluginContext): string {
    const lines = stacktrace.split("\n").map(l => l.trim()).filter(Boolean);

    // Walk the Caused-by chain, collect all exception types
    const exceptions: string[] = [];
    const atLines: string[] = [];
    for (const line of lines) {
      if (/^([\w$.]+Exception|[\w$.]+Error):/.test(line)) {
        exceptions.push(line);
      } else if (line.startsWith("at ") && atLines.length < 5) {
        atLines.push(line);
      }
    }

    const rootException = exceptions[exceptions.length - 1] ?? lines[0] ?? "";
    const exClass = rootException.split(":")[0].trim().split(".").pop() ?? "";
    const message = rootException.includes(":") ? rootException.split(":").slice(1).join(":").trim() : "";

    // Search fix patterns by exception class + message words
    const searchTerms = [exClass, ...message.split(/\s+/).slice(0, 3)].join(" ");
    const fixes = exClass ? ctx.fixPatternsDb.search(searchTerms.substring(0, 200)) : [];

    // Find docs matching the exception class name
    const docHits: string[] = [];
    const classLower = exClass.toLowerCase();
    if (classLower) {
      for (const key of ctx.docIndex.keys()) {
        if (key.includes(classLower)) {
          docHits.push(key);
          if (docHits.length >= 3) break;
        }
      }
    }

    const out: string[] = [
      `## ☕ Java 异常诊断`,
      "",
    ];

    if (exceptions.length > 1) {
      out.push("**异常链（Caused by 顺序）:**");
      exceptions.forEach((e, i) => out.push(`  ${i + 1}. \`${e.substring(0, 120)}\``));
      out.push("");
    }

    out.push(`**根因异常:** \`${exClass || "未识别"}\``);
    if (message) out.push(`**错误消息:** ${message}`);
    out.push("");

    if (atLines.length > 0) {
      out.push("**堆栈摘要（前5帧）:**");
      out.push("```");
      out.push(atLines.join("\n"));
      out.push("```");
      out.push("");
    }

    if (docHits.length > 0) {
      out.push(`**相关文档：** 使用 \`get_doc\` 查看 → ${docHits.join(", ")}`);
      out.push("");
    }

    if (fixes.length > 0) {
      out.push("**📚 本地已记录的修复模式:**");
      for (const fix of fixes.slice(0, 3)) {
        out.push(`\n**${fix.pattern_description}**`);
        out.push(`修复: ${fix.fix_description}`);
        if (fix.fixed_snippet) {
          out.push("```java\n" + fix.fixed_snippet + "\n```");
        }
      }
    } else {
      out.push("💡 暂无本地修复记录。修复后可用 `record_fix` 保存，下次自动命中。");
    }

    return out.join("\n");
  }

  private reviewCode(code: string, ctx: PluginContext): string {
    const issues = analyzeJavaCode(code);
    const totalLines = code.split("\n").length;

    const errors   = issues.filter(i => i.severity === "error");
    const warnings = issues.filter(i => i.severity === "warning");
    const infos    = issues.filter(i => i.severity === "info");

    const score = Math.max(0, 100 - errors.length * 20 - warnings.length * 8 - infos.length * 3);
    const grade = score >= 90 ? "A" : score >= 75 ? "B" : score >= 60 ? "C" : "D";

    const out: string[] = [
      `## 🔍 Java 代码审查报告`,
      `**代码行数:** ${totalLines}  |  **问题总数:** ${issues.length}  |  **评分:** ${score}/100 (${grade})`,
      `**严重:** ${errors.length}  **警告:** ${warnings.length}  **建议:** ${infos.length}`,
      "",
    ];

    if (issues.length === 0) {
      out.push("✅ 未发现已知问题。");
    } else {
      const icons: Record<CodeIssue["severity"], string> = {
        error: "🔴", warning: "🟡", info: "🔵",
      };
      for (const issue of issues) {
        out.push(`${icons[issue.severity]} **[${issue.rule}]** 第 ${issue.line} 行：${issue.detail}`);
      }
    }

    // Match any issues against fix patterns
    if (issues.length > 0) {
      const issueText = issues.map(i => i.rule + " " + i.detail).join(" ");
      const fixes = ctx.fixPatternsDb.search(issueText.substring(0, 300));
      if (fixes.length > 0) {
        out.push("");
        out.push("**📚 本地匹配的修复模式:**");
        for (const fix of fixes.slice(0, 2)) {
          out.push(`- **${fix.pattern_description}**：${fix.fix_description}`);
        }
      }
    }

    return out.join("\n");
  }
}

export const javaPlugin: DomainPlugin = new JavaPlugin();
