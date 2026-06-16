/**
 * Centralised data-directory resolution.
 *
 * New installs use ~/.knowledge-mcp/.
 * Existing installs that still have ~/.mql5-help-mcp/ continue to work
 * automatically — no manual migration needed.
 */

import { homedir } from "os";
import * as path from "path";
import * as fsSync from "fs";

const NEW_DIR = ".knowledge-mcp";
const OLD_DIR = ".mql5-help-mcp";

function resolveDataDir(): string {
  const newDir = path.join(homedir(), NEW_DIR);
  const oldDir = path.join(homedir(), OLD_DIR);
  // backward compat: if old dir exists and new doesn't, keep using old
  if (!fsSync.existsSync(newDir) && fsSync.existsSync(oldDir)) return oldDir;
  return newDir;
}

export const DATA_DIR = resolveDataDir();
