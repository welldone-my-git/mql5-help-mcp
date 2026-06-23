#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";

const fail = (message) => {
  console.error(`❌ ${message}`);
  process.exitCode = 1;
};

const readJson = (file) => JSON.parse(readFileSync(file, "utf8"));

const pkg = readJson("package.json");
const lock = readJson("package-lock.json");
const lockRoot = lock.packages?.[""];

if (pkg.name !== lock.name) {
  fail(`package-lock.json name mismatch: ${lock.name} !== ${pkg.name}`);
}

if (pkg.version !== lock.version) {
  fail(`package-lock.json version mismatch: ${lock.version} !== ${pkg.version}`);
}

if (!lockRoot) {
  fail("package-lock.json missing packages[\"\"] root metadata");
} else {
  if (pkg.name !== lockRoot.name) {
    fail(`package-lock root name mismatch: ${lockRoot.name} !== ${pkg.name}`);
  }
  if (pkg.version !== lockRoot.version) {
    fail(`package-lock root version mismatch: ${lockRoot.version} !== ${pkg.version}`);
  }
}

if (!pkg.repository?.url || /example|todo|your-org/i.test(pkg.repository.url)) {
  fail("package.json repository.url must point at the real repository");
}

if (!pkg.engines?.node) {
  fail("package.json must declare engines.node");
}

for (const required of ["build/", "README.md", "LICENSE"]) {
  if (!pkg.files?.includes(required)) {
    fail(`package.json files must include ${required}`);
  }
}

for (const [name, target] of Object.entries(pkg.bin ?? {})) {
  if (!target.startsWith("./build/")) {
    fail(`bin ${name} must point into ./build/`);
    continue;
  }
  if (!existsSync(target)) {
    fail(`bin ${name} target does not exist: ${target}. Run npm run build first.`);
  }
}

const ignoredDirs = new Set([".git", ".npm-cache", "build", "dist", "node_modules"]);
const forbiddenWorkspaceFiles = [];

const scanWorkspace = (dir) => {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!ignoredDirs.has(entry.name)) {
        scanWorkspace(path.join(dir, entry.name));
      }
      continue;
    }

    if (entry.isFile() && /(\.backup|\.tmp|~)$/.test(entry.name)) {
      forbiddenWorkspaceFiles.push(path.relative(".", path.join(dir, entry.name)));
    }
  }
};

scanWorkspace(".");

if (forbiddenWorkspaceFiles.length > 0) {
  fail(`backup/temp files are not releaseable: ${forbiddenWorkspaceFiles.join(", ")}`);
}

if (process.exitCode) {
  process.exit(process.exitCode);
}

console.log(`✅ Release metadata validated for ${pkg.name}@${pkg.version}`);
