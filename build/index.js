#!/usr/bin/env node
/**
 * Knowledge Base MCP Server
 * 通用文档/代码库检索引擎，可通过 domain_plugin 加载领域专有能力
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as path from "path";
import { fileURLToPath } from "url";
import { getErrorDb, closeErrorDb } from "./error-db.js";
import { BUILTIN_ROOTS, buildIndex, loadedLibraries, } from "./core/document-service.js";
import { registerToolHandlers } from "./core/tool-handlers.js";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// 创建MCP服务器
export const server = new Server({
    name: "knowledge-mcp",
    version: "2.0.0",
}, {
    capabilities: {
        tools: {},
    },
});
registerToolHandlers(server);
// 启动服务器
async function main() {
    console.error("🚀 MQL5 Help MCP Server 启动中...");
    // Attach stdio before any startup I/O so an eager client can initialize
    // while the document index is being prepared.
    const transport = new StdioServerTransport();
    await server.connect(transport);
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
    // A piped stdin does not reliably keep Node's event loop alive on every
    // supported runtime. The client transport terminates us with SIGTERM when it
    // disconnects, so retain one event-loop handle for the server lifetime.
    setInterval(() => { }, 24 * 60 * 60 * 1000);
}
if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
    main().catch((error) => {
        console.error("❌ 启动失败:", error);
        closeErrorDb();
        process.exit(1);
    });
}
