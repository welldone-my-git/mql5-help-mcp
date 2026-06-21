import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";

test("MCP server starts, lists tools, and handles representative calls", async (t) => {
  const home = await mkdtemp(path.join(tmpdir(), "knowledge-mcp-smoke-"));
  t.after(() => rm(home, { recursive: true, force: true }));

  process.env.HOME = home;
  const { server } = await import("../build/index.js");
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "knowledge-mcp-smoke", version: "1.0.0" });
  t.after(async () => {
    await client.close();
    await server.close();
  });
  await server.connect(serverTransport);
  await client.connect(clientTransport);

  const listed = await client.listTools();
  const names = new Set(listed.tools.map((tool) => tool.name));
  for (const required of ["search", "get", "browse", "list_libraries", "diagnose_error", "analyze_structure"]) {
    assert.ok(names.has(required), `missing MCP tool: ${required}`);
  }

  const browse = await client.callTool({ name: "browse", arguments: { category: "trading" } });
  assert.match(browse.content[0].text, /TRADING/);

  const search = await client.callTool({ name: "search", arguments: { query: "OrderSend", limit: 3 } });
  assert.match(search.content[0].text, /OrderSend/i);

  const analysis = await client.callTool({
    name: "analyze_structure",
    arguments: { code: "void OnTick() { trade.Buy(0.1, _Symbol); }" },
  });
  assert.match(analysis.content[0].text, /代码结构分析/);

  const unknown = await client.callTool({ name: "not_a_real_tool", arguments: {} });
  assert.equal(unknown.isError, true);
});
