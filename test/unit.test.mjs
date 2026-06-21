import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { CodeStructureAnalyzer } from "../build/code-analyzer.js";
import { stripHtml } from "../build/utils.js";

test("stripHtml removes executable markup and normalizes whitespace", () => {
  const html = "<style>.x{color:red}</style><h1>Hello</h1>  <script>alert(1)</script><p>MQL5</p>";
  assert.equal(stripHtml(html), "Hello MQL5");
});

test("code analyzer reports unsafe trading patterns", () => {
  const analyzer = new CodeStructureAnalyzer();
  const result = analyzer.analyze(`
#include <Trade/Trade.mqh>
CTrade trade;
int ma = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
int OnInit() { return INIT_SUCCEEDED; }
void OnTick() { trade.Buy(0.1, _Symbol); }
`);

  const ids = new Set(result.issues.map((issue) => issue.id));
  assert.ok(ids.has("handle_leak"));
  assert.ok(ids.has("unguarded_open"));
  assert.ok(ids.has("no_magic_number"));
  assert.ok(ids.has("fixed_lot"));
  assert.ok(ids.has("no_trade_error_check"));
  assert.ok(result.score < 50);
});

test("embedding math, hybrid ranking, and SQLite storage work", async (t) => {
  const home = await mkdtemp(path.join(tmpdir(), "knowledge-mcp-unit-"));
  t.after(() => rm(home, { recursive: true, force: true }));
  process.env.HOME = home;

  const { cosineSimilarity, hybridMerge, VectorStore } = await import("../build/core/embedding.js");
  assert.equal(cosineSimilarity(new Float32Array([1, 0]), new Float32Array([1, 0])), 1);
  assert.equal(cosineSimilarity(new Float32Array([1, 0]), new Float32Array([0, 1])), 0);

  const ranked = hybridMerge(
    [{ key: "keyword", score: 1 }],
    [{ docKey: "semantic", absPath: "/semantic", score: 1 }],
    2,
  );
  assert.deepEqual(ranked.map((hit) => hit.key), ["semantic", "keyword"]);

  const store = new VectorStore(path.join(home, "vectors.db"));
  t.after(() => store.close());
  store.upsert("doc", "/doc.htm", new Float32Array([0.25, 0.75]), { model: "test" });
  assert.equal(store.count(), 1);
  assert.equal(store.hasKey("doc"), true);
  assert.deepEqual(Array.from(store.loadAll().get("doc").embedding), [0.25, 0.75]);
});
