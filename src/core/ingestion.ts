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
 * Uses pdf-parse (pdfjs-dist underneath). Suppresses warnings.
 */
export async function extractPdfText(buffer: Buffer): Promise<string> {
  // Dynamic import keeps this import out of the hot path for non-PDF repos
  const { PDFParse, VerbosityLevel } = await import("pdf-parse");
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
