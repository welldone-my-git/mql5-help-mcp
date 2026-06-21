/**
 * File ingestion helpers — type-aware text extraction.
 * Centralises "how do we read file X as plain text" so index, search,
 * and embedding code share one definition.
 */

import * as fsAsync from "fs/promises";

// ── PDF ───────────────────────────────────────────────────────────────────────

export const PDF_EXT = /\.pdf$/i;

/**
 * Extract plain text from a PDF buffer.
 * Uses pdf-parse v2 (pdfjs-dist underneath). Suppresses warnings.
 */
export async function extractPdfText(buffer: Buffer): Promise<string> {
  let mod: { PDFParse: new (opts: { data: Uint8Array; verbosity: number }) => { getText(): Promise<{ text: string }>; destroy(): Promise<void> }; VerbosityLevel: { ERRORS: number } };
  try {
    mod = await import("pdf-parse");
  } catch (e) {
    console.error(`[pdf] pdf-parse not available, install with: npm install pdf-parse@~2.4.5 (${e})`);
    return `[PDF extraction failed — pdf-parse module not available]`;
  }

  const { PDFParse, VerbosityLevel } = mod;
  const parser = new PDFParse({
    data: new Uint8Array(buffer),
    verbosity: VerbosityLevel.ERRORS,
  });
  try {
    const result = await parser.getText();
    return result.text;
  } finally {
    await parser.destroy();
  }
}

// ── Universal reader ──────────────────────────────────────────────────────────

/**
 * Read any indexed file as plain text.
 * - .pdf  → PDF text extraction
 * - other → UTF-8 read (HTML, MD, .mq5, .mqh, ...)
 */
export async function readFileText(absPath: string): Promise<string> {
  if (PDF_EXT.test(absPath)) {
    const buf = await fsAsync.readFile(absPath);
    return extractPdfText(buf);
  }
  return fsAsync.readFile(absPath, "utf-8");
}
