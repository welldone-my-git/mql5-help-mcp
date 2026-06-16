/**
 * Domain plugin interface — lets any domain extend the core MCP server
 * without touching core engine code.
 */

import type { KnowledgeStore } from "../library-knowledge.js";
import type { FixPatternsDb } from "../fix-patterns.js";

// ── Shared doc index entry type ───────────────────────────────────────────────

export interface DocEntry {
  absPath: string;
  relPath: string;
  repo: string;
}

// ── Plugin result (subset of MCP CallToolResult) ──────────────────────────────

export interface PluginResult {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
}

// ── Tool definition (subset of MCP Tool) ──────────────────────────────────────

export interface ToolDefinition {
  name: string;
  description: string;
  inputSchema: {
    type: "object";
    properties: Record<string, unknown>;
    required?: string[];
  };
}

// ── Plugin context ─────────────────────────────────────────────────────────────

export interface PluginContext {
  /** filename (no ext) → DocEntry, for all indexed documents */
  docIndex: Map<string, DocEntry>;
  knowledgeStore: KnowledgeStore;
  fixPatternsDb: FixPatternsDb;
  loadedLibraries: Array<{ key: string; fileCount: number; rootPath: string }>;
}

// ── Optional query enrichment ──────────────────────────────────────────────────

export interface EnrichedQuery {
  original: string;
  expanded: string;
  hint?: string;
}

// ── The interface every domain plugin must implement ───────────────────────────

export interface DomainPlugin {
  readonly name: string;

  getToolDefinitions(): ToolDefinition[];

  handleToolCall(
    toolName: string,
    args: unknown,
    ctx: PluginContext
  ): Promise<PluginResult>;

  preprocessQuery?(query: string, ctx: PluginContext): EnrichedQuery;
}
