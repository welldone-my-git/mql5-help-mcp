import * as fs from "fs/promises";
import * as path from "path";
import { fileURLToPath } from "url";
import type { DomainPlugin } from "./plugin.js";
import { DATA_DIR } from "./paths.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const CONFIG_PATH = path.join(DATA_DIR, "config.json");

export interface SourceConfig {
  key: string;
  path: string;
  type?: "html" | "md" | "code" | "auto";
  priority?: number;
  description?: string;
  builtin?: boolean;
}

export interface EmbeddingConfig {
  provider: "ollama";
  model: string;
  url: string;
}

export interface AppConfig {
  sources?: SourceConfig[];
  extraLibraries?: Array<{ key: string; path: string; description?: string }>;
  domain_plugin?: string | null;
  embedding?: EmbeddingConfig;
}

export const DEFAULT_BUILTIN: SourceConfig[] = [
  { key: "MQL5_HELP",            path: path.resolve(__dirname, "..", "..", "MQL5_HELP"),            builtin: true, priority: 1 },
  { key: "MQL5_Algo_Book",       path: path.resolve(__dirname, "..", "..", "MQL5_Algo_Book"),       builtin: true, priority: 2 },
  { key: "Neural_Networks_Book", path: path.resolve(__dirname, "..", "..", "Neural_Networks_Book"), builtin: true, priority: 3 },
];

export const BUILTIN_ROOTS = DEFAULT_BUILTIN;

export async function loadConfig(): Promise<AppConfig> {
  try {
    const raw = await fs.readFile(CONFIG_PATH, "utf-8");
    return JSON.parse(raw) as AppConfig;
  } catch {
    return {};
  }
}

export async function resolveSources(): Promise<SourceConfig[]> {
  const cfg = await loadConfig();
  const result: SourceConfig[] = [];

  for (const b of DEFAULT_BUILTIN) {
    const override = cfg.sources?.find(s => s.key === b.key);
    result.push(override ?? b);
  }

  if (cfg.sources) {
    for (const s of cfg.sources) {
      if (!DEFAULT_BUILTIN.some(b => b.key === s.key)) {
        result.push(s);
      }
    }
  }

  if (cfg.extraLibraries) {
    for (const e of cfg.extraLibraries) {
      if (!result.some(r => r.key === e.key)) {
        result.push({ key: e.key, path: e.path, description: e.description });
      }
    }
  }

  return result;
}

export async function loadPlugin(): Promise<DomainPlugin | null> {
  const cfg = await loadConfig();
  if (cfg.domain_plugin === null) return null;
  const pluginName = cfg.domain_plugin ?? "mql5";
  try {
    const mod = await import(`../plugins/${pluginName}/index.js`);
    const plugin: DomainPlugin = mod[`${pluginName}Plugin`] ?? mod.default;
    console.error(`🔌 已加载领域插件: ${plugin.name}`);
    return plugin;
  } catch (e) {
    console.error(`⚠️  插件 "${pluginName}" 加载失败: ${e}`);
    return null;
  }
}

export async function getEmbeddingConfig(): Promise<EmbeddingConfig | null> {
  const cfg = await loadConfig();
  return cfg.embedding ?? null;
}
