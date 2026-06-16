#!/usr/bin/env node
/**
 * MQL5 Help MCP Server
 * 文档/电子书一体化检索，基础迁移/错误提示
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs/promises";
import * as path from "path";
import { fileURLToPath } from "url";
import { SmartQueryEngine, DiagnoseEngine } from "./smart-query.js";
import { getErrorDb, closeErrorDb } from "./error-db.js";
import { stripHtml, MIGRATION_HINTS } from "./utils.js";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// 内置文档根目录
const BUILTIN_ROOTS = [
    { key: "MQL5_HELP", abs: path.resolve(__dirname, "..", "MQL5_HELP") },
    { key: "MQL5_Algo_Book", abs: path.resolve(__dirname, "..", "MQL5_Algo_Book") },
    { key: "Neural_Networks_Book", abs: path.resolve(__dirname, "..", "Neural_Networks_Book") },
];
// 配置文件路径
import { homedir } from "os";
const CONFIG_PATH = path.join(homedir(), ".mql5-help-mcp", "config.json");
// 已加载的外部库清单（供 list_libraries 使用）
const loadedLibraries = [];
// 读取用户配置中的外部库
async function loadExtraLibraries() {
    try {
        const raw = await fs.readFile(CONFIG_PATH, "utf-8");
        const config = JSON.parse(raw);
        if (!Array.isArray(config.extraLibraries))
            return [];
        return config.extraLibraries
            .filter(l => l.key && l.path)
            .map(l => ({ key: l.key, abs: path.resolve(l.path), description: l.description || "" }));
    }
    catch {
        return []; // 文件不存在或格式错误时静默跳过
    }
}
let docIndex = null;
let nameIndex = null;
let queryEngine = null;
// 支持的文件扩展名
const DOC_EXTS = /\.(htm|html|md)$/i;
const CODE_EXTS = /\.(mq5|mqh)$/i;
const ALL_EXTS = /\.(htm|html|md|mq5|mqh)$/i;
// 递归读取目录下的文件
async function walkDir(rootAbs, repoKey, baseRel = "") {
    const entries = [];
    let dirents;
    try {
        dirents = await fs.readdir(path.join(rootAbs, baseRel), { withFileTypes: true });
    }
    catch {
        return entries;
    }
    for (const d of dirents) {
        const relPath = path.join(baseRel, d.name);
        const absPath = path.join(rootAbs, relPath);
        if (d.isDirectory()) {
            const sub = await walkDir(rootAbs, repoKey, relPath);
            entries.push(...sub);
        }
        else if (ALL_EXTS.test(d.name)) {
            entries.push({ absPath, relPath, repo: repoKey });
        }
    }
    return entries;
}
// 构建文档索引（内置目录 + 用户配置的外部库）
async function buildIndex() {
    if (docIndex)
        return docIndex;
    docIndex = new Map();
    nameIndex = new Map();
    // 内置根目录（MQL5_HELP 优先）
    const roots = [];
    for (const c of BUILTIN_ROOTS) {
        try {
            await fs.access(c.abs);
            roots.push(c);
        }
        catch { }
    }
    // 用户配置的外部库
    const extras = await loadExtraLibraries();
    for (const e of extras) {
        try {
            await fs.access(e.abs);
            roots.push({ key: e.key, abs: e.abs, external: true, description: e.description || "" });
        }
        catch {
            console.error(`⚠️  外部库路径不存在，已跳过: ${e.key} (${e.abs})`);
        }
    }
    // 遍历并索引
    loadedLibraries.length = 0;
    for (const r of roots) {
        const files = await walkDir(r.abs, r.key);
        for (const f of files) {
            const base = path.basename(f.relPath).toLowerCase();
            const noExt = base.replace(ALL_EXTS, "");
            // 主键：文件名（无扩展）— first-wins 保证内置库优先
            if (!docIndex.has(noExt))
                docIndex.set(noExt, f);
            if (!nameIndex.has(noExt))
                nameIndex.set(noExt, f);
            // 外部库专用命名空间前缀（避免冲突）
            if (r.external) {
                const nsKey = `${r.key.toLowerCase()}_${noExt}`;
                docIndex.set(nsKey, f);
            }
            // 类名变体（去掉开头 C）
            if (noExt.startsWith("c") && noExt.length > 2) {
                const shortKey = noExt.substring(1);
                if (!docIndex.has(shortKey))
                    docIndex.set(shortKey, f);
            }
            // ONNX 相关关键词
            if (noExt.includes("onnx")) {
                if (!docIndex.has("onnx"))
                    docIndex.set("onnx", f);
                if (!docIndex.has("onnx_guide"))
                    docIndex.set("onnx_guide", f);
                if (!docIndex.has("ml"))
                    docIndex.set("ml", f);
                if (!docIndex.has("ai"))
                    docIndex.set("ai", f);
            }
            // 电子书目录粗粒度前缀
            if (f.repo === "MQL5_Algo_Book")
                docIndex.set(`algo_${noExt}`, f);
            if (f.repo === "Neural_Networks_Book")
                docIndex.set(`nn_${noExt}`, f);
        }
        // 记录到已加载库列表
        loadedLibraries.push({
            key: r.key,
            absPath: r.abs,
            description: r.description || r.external ? "外部库" : "内置",
            fileCount: files.length,
        });
    }
    console.error(`📚 索引已建立: ${docIndex.size} 个键，${nameIndex.size} 个文件名索引`);
    queryEngine = new SmartQueryEngine(docIndex);
    return docIndex;
}
// 搜索文档（含错误文本与迁移提示）
async function searchDocs(query, limit = 10) {
    const index = await buildIndex();
    const queryLower = query.toLowerCase();
    // 智能错误识别（undeclared identifier ...）
    const smartHints = [];
    const undeclaredMatch = queryLower.match(/undeclared\s+identifier\s+'?"?([a-z_][a-z0-9_]*)'?"?/i) ||
        queryLower.match(/undeclared\s+identifier\s+([a-z_][a-z0-9_]*)/i);
    if (undeclaredMatch && undeclaredMatch[1]) {
        const missing = undeclaredMatch[1].toLowerCase();
        if (MIGRATION_HINTS[missing]) {
            const h = MIGRATION_HINTS[missing];
            smartHints.push(`🩺 诊断：未声明标识符 '${missing}' → 可能应改为 '${h.replacement}'（${h.hint}）`);
        }
    }
    // 迁移建议（直接包含左侧关键词时）
    for (const [k, v] of Object.entries(MIGRATION_HINTS)) {
        if (queryLower.includes(k))
            smartHints.push(`🔁 迁移建议：'${k}' → '${v.replacement}'（${v.hint}）`);
    }
    // 精确匹配
    const exact = index.get(queryLower);
    // 模糊匹配 + 迁移目标扩展
    const expansionKeys = new Set();
    for (const [k, v] of Object.entries(MIGRATION_HINTS)) {
        if (queryLower.includes(k))
            v.targetKeys.forEach((t) => expansionKeys.add(t));
    }
    if (undeclaredMatch && undeclaredMatch[1]) {
        const m = undeclaredMatch[1].toLowerCase();
        if (MIGRATION_HINTS[m])
            MIGRATION_HINTS[m].targetKeys.forEach((t) => expansionKeys.add(t));
    }
    const results = [];
    for (const [key, entry] of index.entries()) {
        let matched = false;
        let score = 0;
        if (key === queryLower) {
            matched = true;
            score = 1.0;
        }
        else if (key.includes(queryLower)) {
            matched = true;
            score = queryLower.length / Math.max(2, key.length);
        }
        else if (expansionKeys.has(key)) {
            matched = true;
            score = 0.95;
        }
        if (matched)
            results.push({ entry, key, score });
    }
    results.sort((a, b) => b.score - a.score);
    let out = `🔍 搜索: "${query}"\n\n`;
    if (smartHints.length)
        out += smartHints.map((s) => `• ${s}`).join("\n") + "\n\n";
    if (exact)
        out += `✅ 精确匹配: ${exact.relPath}  (来源: ${exact.repo})\n\n`;
    if (results.length > 0) {
        out += `📋 相关文档 (${Math.min(results.length, limit)} / ${results.length})：\n`;
        results.slice(0, limit).forEach((m, i) => {
            out += `  ${i + 1}. ${m.entry.relPath}  (${m.entry.repo})\n`;
        });
    }
    else if (!exact) {
        out += `❌ 未找到匹配文档\n`;
        out += `💡 提示: 使用英文关键字，如 OrderSend, CopyBuffer；或尝试更短关键词`;
    }
    return out;
}
// 读取文档内容（多目录，含代码文件）
async function getDoc(filename) {
    const index = await buildIndex();
    const raw = filename.trim();
    const lower = raw.toLowerCase();
    // 1) 按 key（无扩展）
    let entry = index.get(lower.replace(ALL_EXTS, ""));
    // 2) 按文件名（无扩展）
    if (!entry && nameIndex) {
        const nameKey = path.basename(lower).replace(ALL_EXTS, "");
        entry = nameIndex.get(nameKey) || undefined;
    }
    if (!entry) {
        const search = await searchDocs(filename, 5);
        return `❌ 未找到文件: ${filename}\n\n${search}`;
    }
    try {
        const content = await fs.readFile(entry.absPath, "utf-8");
        const header = `📄 ${entry.relPath} (${entry.repo})\n${"=".repeat(60)}\n\n`;
        const footer = `\n\n${"=".repeat(60)}`;
        if (CODE_EXTS.test(entry.absPath)) {
            // .mq5 / .mqh — 原始代码，保留格式
            const truncated = content.length > 12000
                ? content.substring(0, 12000) + "\n\n// ... (内容过长，已截断)"
                : content;
            return header + "```mql5\n" + truncated + "\n```" + footer;
        }
        if (/\.(md)$/i.test(entry.absPath)) {
            const truncated = content.length > 15000
                ? content.substring(0, 15000) + "\n\n... (内容过长，已截断)"
                : content;
            return header + truncated + footer;
        }
        // HTML 文档
        const text = stripHtml(content);
        const truncated = text.length > 10000 ? text.substring(0, 10000) + "..." : text;
        return header + truncated + footer;
    }
    catch (error) {
        return `❌ 读取失败: ${error}`;
    }
}
// 浏览分类（仍以官方主题分类为主）
function browseCategories(category) {
    const categories = {
        trading: ["ordersend", "ordercheck", "ctrade", "positionselect"],
        indicators: ["icustom", "copybuffer", "indicatorcreate", "setindexbuffer"],
        math: ["mathabs", "mathsin", "mathcos", "mathrandom", "mathpow"],
        array: ["arrayresize", "arraycopy", "arraysort", "arrayinitialize"],
        string: ["stringfind", "stringsplit", "stringreplace", "stringformat"],
        datetime: ["timecurrent", "timelocal", "timetostruct", "timegmt"],
        files: ["fileopen", "fileclose", "filewrite", "fileread"],
        chart: ["chartopen", "chartredraw", "chartid", "chartsetinteger"],
        objects: ["objectcreate", "objectdelete", "objectsetinteger"],
        onnx: ["onnxcreate", "onnxrun", "onnxrelease", "MQL5_ONNX_Integration_Guide"],
    };
    if (!category) {
        let result = "📚 MQL5 文档分类\n" + "=".repeat(60) + "\n\n";
        for (const [cat, docs] of Object.entries(categories)) {
            result += `📁 ${cat}: ${docs.length} 个文档\n`;
        }
        result += "\n💡 使用 category 参数查看具体分类";
        return result;
    }
    const docs = categories[category.toLowerCase()];
    if (!docs) {
        return `❌ 未知分类: ${category}\n\n可用: ${Object.keys(categories).join(", ")}`;
    }
    let result = `📁 ${category.toUpperCase()}\n${"=".repeat(60)}\n\n`;
    docs.forEach((doc) => {
        result += `  • ${doc}.htm\n`;
    });
    return result;
}
// 创建MCP服务器
const server = new Server({
    name: "mql5-help-mcp",
    version: "1.1.0",
}, {
    capabilities: {
        tools: {},
    },
});
// 注册工具列表
server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
        tools: [
            {
                name: "smart_query",
                description: "🎯 智能查询工具（推荐）：输入错误信息、函数名或问题，自动搜索并返回精简答案。完全本地化，零API成本，节省80%+ token。适用于：错误诊断、函数查询、快速学习。",
                inputSchema: {
                    type: "object",
                    properties: {
                        query: {
                            type: "string",
                            description: "查询内容：1) 错误信息如 'error 256: undeclared identifier ResultCode' 2) 函数名如 'OrderSend' 3) 类名如 'CTrade' 4) 问题如 'how to send order'",
                        },
                        mode: {
                            type: "string",
                            enum: ["quick", "detailed"],
                            description: "返回模式: quick=精简答案(~500 tokens,推荐), detailed=详细说明(~1500 tokens)",
                            default: "quick",
                        },
                    },
                    required: ["query"],
                },
            },
            {
                name: "search",
                description: "搜索MQL5文档（函数名、类名、关键字）。返回文档列表，需再调用get获取内容。如需直接答案请用smart_query。",
                inputSchema: {
                    type: "object",
                    properties: {
                        query: {
                            type: "string",
                            description: "搜索关键词或错误文本",
                        },
                        limit: {
                            type: "number",
                            description: "返回结果数量",
                            default: 10,
                        },
                    },
                    required: ["query"],
                },
            },
            {
                name: "get",
                description: "获取指定文档的详细内容（完整HTML，~3000 tokens）。如需精简答案请用smart_query。",
                inputSchema: {
                    type: "object",
                    properties: {
                        filename: {
                            type: "string",
                            description: "文档名（可不带扩展）",
                        },
                    },
                    required: ["filename"],
                },
            },
            {
                name: "browse",
                description: "浏览文档分类目录",
                inputSchema: {
                    type: "object",
                    properties: {
                        category: {
                            type: "string",
                            description: "分类名（可选）: trading, indicators, math, array, string, datetime, files, chart, objects, onnx",
                        },
                    },
                },
            },
            {
                name: "log_error",
                description: "📝 记录MQL5编译错误到本地数据库。用于收集常见错误及解决方案，下次遇到相同错误时可快速查询。",
                inputSchema: {
                    type: "object",
                    properties: {
                        error_code: {
                            type: "string",
                            description: "错误代码（如 E512, E308）",
                        },
                        error_message: {
                            type: "string",
                            description: "完整错误消息",
                        },
                        file_path: {
                            type: "string",
                            description: "发生错误的文件路径（可选，隐私考虑）",
                        },
                        solution: {
                            type: "string",
                            description: "解决方案描述（可选）",
                        },
                        related_docs: {
                            type: "string",
                            description: "相关文档列表，JSON数组格式（可选）",
                        },
                    },
                    required: ["error_code", "error_message"],
                },
            },
            {
                name: "list_common_errors",
                description: "📊 列出最常见的MQL5编译错误（按出现频率排序）。帮助快速了解常见问题。",
                inputSchema: {
                    type: "object",
                    properties: {
                        limit: {
                            type: "number",
                            description: "返回错误数量（默认10）",
                            default: 10,
                        },
                    },
                },
            },
            {
                name: "manage_error_db",
                description: "🔧 管理错误数据库：导出/导入错误记录，查看数据库统计信息。支持团队共享错误库。",
                inputSchema: {
                    type: "object",
                    properties: {
                        action: {
                            type: "string",
                            enum: ["export", "import", "stats"],
                            description: "操作类型：export=导出为JSON, import=从JSON导入, stats=查看统计",
                        },
                        data: {
                            type: "string",
                            description: "导入时的JSON数据（action=import时必需）",
                        },
                        anonymize: {
                            type: "boolean",
                            description: "导出时是否移除文件路径（保护隐私，默认false）",
                            default: false,
                        },
                    },
                    required: ["action"],
                },
            },
            {
                name: "diagnose_error",
                description: "🔬 编译日志诊断：粘贴 MetaEditor 完整编译输出，自动解析所有错误/警告行，匹配迁移映射与历史解决方案，返回结构化诊断报告。适用于一次性修复多个编译错误的场景。",
                inputSchema: {
                    type: "object",
                    properties: {
                        compile_log: {
                            type: "string",
                            description: "MetaEditor 编译窗口的完整输出文本，支持多行，如：\n  ma_cross.mq5(155,39) : error 256: undeclared identifier 'ResultCode'",
                        },
                    },
                    required: ["compile_log"],
                },
            },
            {
                name: "list_libraries",
                description: "📚 列出当前已加载的所有资料库（内置文档 + 用户配置的外部代码库），显示每个库的文件数量与路径。配置文件位于 ~/.mql5-help-mcp/config.json。",
                inputSchema: {
                    type: "object",
                    properties: {},
                },
            },
        ],
    };
});
// 处理工具调用
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    try {
        const { name, arguments: args } = request.params;
        switch (name) {
            case "smart_query": {
                const { query, mode = "quick" } = args;
                // 确保索引和引擎已初始化
                await buildIndex();
                const engine = queryEngine;
                // 执行智能查询
                const result = await engine.query(query, mode);
                // 格式化输出
                let output = `🔍 智能查询结果\n${"=".repeat(60)}\n\n`;
                output += `📝 查询: ${query}\n`;
                output += `⚙️ 模式: ${result.type === "quick" ? "精简" : "详细"}\n`;
                output += `📊 预计token: ~${result.estimatedTokens}\n\n`;
                output += `${"─".repeat(60)}\n\n`;
                output += `💡 答案:\n${result.answer}\n\n`;
                if (result.syntax) {
                    output += `📐 语法:\n${result.syntax}\n\n`;
                }
                if (result.parameters) {
                    output += `📋 参数:\n${result.parameters}\n\n`;
                }
                if (result.returns) {
                    output += `↩️ 返回值:\n${result.returns}\n\n`;
                }
                if (result.code || result.example) {
                    output += `💻 示例代码:\n${result.code || result.example}\n\n`;
                }
                if (result.notes && result.notes.length > 0) {
                    output += `⚠️ 注意事项:\n`;
                    result.notes.forEach((note, i) => {
                        output += `${i + 1}. ${note}\n`;
                    });
                    output += `\n`;
                }
                output += `📚 参考文档: ${result.reference}\n`;
                if (result.relatedDocs && result.relatedDocs.length > 0) {
                    output += `\n🔗 相关文档:\n`;
                    result.relatedDocs.forEach((doc) => {
                        output += `  • ${doc}\n`;
                    });
                }
                return { content: [{ type: "text", text: output }] };
            }
            case "search": {
                const { query, limit = 10 } = args;
                const result = await searchDocs(query, limit);
                return { content: [{ type: "text", text: result }] };
            }
            case "get": {
                const { filename } = args;
                const result = await getDoc(filename);
                return { content: [{ type: "text", text: result }] };
            }
            case "browse": {
                const { category } = args;
                const result = browseCategories(category);
                return { content: [{ type: "text", text: result }] };
            }
            case "log_error": {
                const { error_code, error_message, file_path, solution, related_docs } = args;
                const errorDb = getErrorDb();
                const record = errorDb.addError({
                    error_code,
                    error_message,
                    file_path,
                    solution,
                    related_docs,
                });
                let output = `✅ 错误已记录到数据库\n${"=".repeat(60)}\n\n`;
                output += `📋 错误代码: ${record.error_code}\n`;
                output += `📝 错误消息: ${record.error_message}\n`;
                output += `🔢 出现次数: ${record.occurrence_count}\n`;
                output += `📅 首次遇到: ${record.first_seen}\n`;
                output += `📅 最后遇到: ${record.last_seen}\n`;
                if (record.solution) {
                    output += `\n💡 解决方案:\n${record.solution}\n`;
                }
                if (record.related_docs) {
                    output += `\n📚 相关文档:\n${record.related_docs}\n`;
                }
                output += `\n💾 数据库位置: ${errorDb.getStats().dbPath}`;
                return { content: [{ type: "text", text: output }] };
            }
            case "list_common_errors": {
                const { limit = 10 } = args;
                const errorDb = getErrorDb();
                const commonErrors = errorDb.listCommonErrors(limit);
                if (commonErrors.length === 0) {
                    return {
                        content: [{
                                type: "text",
                                text: "📊 错误数据库为空\n\n💡 提示: 使用 log_error 工具记录遇到的编译错误"
                            }]
                    };
                }
                let output = `📊 最常见的MQL5编译错误 (TOP ${commonErrors.length})\n${"=".repeat(60)}\n\n`;
                commonErrors.forEach((error, index) => {
                    output += `${index + 1}. ${error.error_code} - ${error.error_message}\n`;
                    output += `   🔢 出现次数: ${error.occurrence_count}\n`;
                    output += `   📅 最后遇到: ${error.last_seen}\n`;
                    if (error.solution) {
                        const shortSolution = error.solution.length > 100
                            ? error.solution.substring(0, 100) + "..."
                            : error.solution;
                        output += `   💡 解决方案: ${shortSolution}\n`;
                    }
                    output += `\n`;
                });
                const stats = errorDb.getStats();
                output += `${"─".repeat(60)}\n`;
                output += `📈 统计信息:\n`;
                output += `  • 总错误类型: ${stats.totalErrors}\n`;
                output += `  • 总出现次数: ${stats.totalOccurrences}\n`;
                output += `  • 数据库位置: ${stats.dbPath}\n`;
                return { content: [{ type: "text", text: output }] };
            }
            case "manage_error_db": {
                const { action, data, anonymize = false } = args;
                const errorDb = getErrorDb();
                if (action === "export") {
                    const jsonData = errorDb.exportErrors(anonymize);
                    let output = `📤 错误数据库导出成功\n${"=".repeat(60)}\n\n`;
                    if (anonymize) {
                        output += `🔒 隐私模式: 已移除文件路径信息\n\n`;
                    }
                    output += `📊 导出数据:\n`;
                    output += `\`\`\`json\n${jsonData}\n\`\`\`\n\n`;
                    output += `💡 提示: 复制上述JSON数据，使用 manage_error_db(action="import") 导入到其他系统`;
                    return { content: [{ type: "text", text: output }] };
                }
                if (action === "import") {
                    if (!data) {
                        return {
                            content: [{ type: "text", text: "❌ 错误: 导入操作需要提供 data 参数（JSON格式）" }],
                            isError: true,
                        };
                    }
                    try {
                        const result = errorDb.importErrors(data);
                        let output = `📥 错误数据库导入完成\n${"=".repeat(60)}\n\n`;
                        output += `✅ 新导入: ${result.imported} 条\n`;
                        output += `🔄 已更新: ${result.updated} 条\n`;
                        if (result.errors > 0) {
                            output += `⚠️ 失败: ${result.errors} 条\n`;
                        }
                        const stats = errorDb.getStats();
                        output += `\n📈 当前数据库统计:\n`;
                        output += `  • 总错误类型: ${stats.totalErrors}\n`;
                        output += `  • 总出现次数: ${stats.totalOccurrences}\n`;
                        return { content: [{ type: "text", text: output }] };
                    }
                    catch (error) {
                        const message = error instanceof Error ? error.message : String(error);
                        return {
                            content: [{ type: "text", text: `❌ 导入失败: ${message}` }],
                            isError: true,
                        };
                    }
                }
                if (action === "stats") {
                    const stats = errorDb.getStats();
                    let output = `📈 错误数据库统计信息\n${"=".repeat(60)}\n\n`;
                    output += `📊 数据统计:\n`;
                    output += `  • 总错误类型: ${stats.totalErrors}\n`;
                    output += `  • 总出现次数: ${stats.totalOccurrences}\n`;
                    output += `  • 平均每错误: ${stats.totalErrors > 0 ? (stats.totalOccurrences / stats.totalErrors).toFixed(1) : 0} 次\n\n`;
                    output += `💾 数据库信息:\n`;
                    output += `  • 位置: ${stats.dbPath}\n\n`;
                    output += `💡 提示:\n`;
                    output += `  • 使用 list_common_errors 查看高频错误\n`;
                    output += `  • 使用 manage_error_db(action="export") 导出错误库\n`;
                    output += `  • 使用 smart_query 查询错误时会自动从数据库搜索`;
                    return { content: [{ type: "text", text: output }] };
                }
                throw new Error(`未知操作: ${action}`);
            }
            case "diagnose_error": {
                const { compile_log } = args;
                await buildIndex();
                const engine = new DiagnoseEngine(docIndex);
                const report = await engine.diagnose(compile_log);
                return { content: [{ type: "text", text: report }] };
            }
            case "list_libraries": {
                await buildIndex();
                let out = `📚 已加载资料库\n${"=".repeat(60)}\n\n`;
                out += `配置文件: ${CONFIG_PATH}\n\n`;
                const builtin = loadedLibraries.filter(l => BUILTIN_ROOTS.some(b => b.key === l.key));
                const external = loadedLibraries.filter(l => !BUILTIN_ROOTS.some(b => b.key === l.key));
                out += `📖 内置库 (${builtin.length}):\n`;
                for (const lib of builtin) {
                    out += `  • ${lib.key.padEnd(22)} ${lib.fileCount} 个文件\n`;
                }
                out += `\n🔌 外部库 (${external.length}):\n`;
                if (external.length === 0) {
                    out += `  （未配置）\n\n`;
                    out += `💡 在 ${CONFIG_PATH} 中添加：\n`;
                    out += `\`\`\`json\n`;
                    out += `{\n  "extraLibraries": [\n`;
                    out += `    { "key": "MyLib", "path": "/path/to/library", "description": "说明" }\n`;
                    out += `  ]\n}\n\`\`\`\n`;
                    out += `\n支持文件类型：.htm .html .md .mq5 .mqh\n`;
                    out += `搜索外部库文件使用前缀，如 search("mylib_filename")`;
                }
                else {
                    for (const lib of external) {
                        out += `  • ${lib.key.padEnd(22)} ${lib.fileCount} 个文件  ${lib.absPath}\n`;
                        if (lib.description && lib.description !== "外部库") {
                            out += `    ${lib.description}\n`;
                        }
                    }
                    out += `\n💡 搜索外部库文件可加前缀，如 search("${external[0].key.toLowerCase()}_filename")`;
                }
                return { content: [{ type: "text", text: out }] };
            }
            default:
                throw new Error(`未知工具: ${name}`);
        }
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
            content: [{ type: "text", text: `❌ 错误: ${message}` }],
            isError: true,
        };
    }
});
// 启动服务器
async function main() {
    console.error("🚀 MQL5 Help MCP Server 启动中...");
    // 预构建索引，同时输出库信息
    await buildIndex();
    for (const lib of loadedLibraries) {
        const tag = BUILTIN_ROOTS.some(b => b.key === lib.key) ? "内置" : "外部";
        console.error(`📂 [${tag}] ${lib.key}: ${lib.fileCount} 个文件`);
    }
    if (loadedLibraries.length === 0) {
        console.error("📂 (无可用文档目录)");
    }
    // 初始化错误数据库
    const errorDb = getErrorDb();
    const stats = errorDb.getStats();
    console.error(`💾 错误数据库: ${stats.totalErrors} 条记录 (${stats.dbPath})`);
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("✅ 服务器就绪，等待连接...");
    // 优雅退出时关闭数据库
    process.on('SIGINT', () => {
        console.error("🛑 正在关闭服务器...");
        closeErrorDb();
        process.exit(0);
    });
    process.on('SIGTERM', () => {
        console.error("🛑 正在关闭服务器...");
        closeErrorDb();
        process.exit(0);
    });
}
main().catch((error) => {
    console.error("❌ 启动失败:", error);
    closeErrorDb();
    process.exit(1);
});
