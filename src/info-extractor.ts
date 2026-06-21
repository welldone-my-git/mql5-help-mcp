import * as fs from "fs/promises";
import { stripHtml, htmlToMarkdown, decodeEntities } from "./utils.js";

export interface ExtractedInfo {
  syntax?: string;
  parameters?: string;
  returns?: string;
  example?: string;
  notes?: string[];
  description?: string;
  seeAlso?: string[];
}

export class InfoExtractor {
  static extractSyntax(text: string): string | undefined {
    const patterns = [
      /((?:bool|int|long|double|string|void|ulong|uint|ushort|datetime|color)\s+[A-Z][a-zA-Z0-9_]*\s*\([^)]*\))/i,
      /((?:virtual\s+)?(?:bool|int|double|string|void)\s+[A-Z][a-zA-Z0-9_]*\s*\([^)]*\))/i,
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        return match[1].replace(/\s+/g, " ").trim().substring(0, 200);
      }
    }
    return undefined;
  }

  static extractParameters(text: string): string | undefined {
    const patterns = [
      /Parameters?[:\s]*\n([^\n]+(?:\n(?!\n)[^\n]+)*)/i,
      /参数[:\s]*\n([^\n]+(?:\n(?!\n)[^\n]+)*)/i,
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        return match[1].trim().substring(0, 400);
      }
    }
    return undefined;
  }

  static extractReturns(text: string): string | undefined {
    const patterns = [
      /Return(?:s|ed)?\s+value[:\s]*\n?([^\n]+)/i,
      /Returns?[:\s]*\n?([^\n]+)/i,
      /返回值?[:\s]*\n?([^\n]+)/i,
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        return match[1].trim().substring(0, 200);
      }
    }
    return undefined;
  }

  static extractExample(html: string): string | undefined {
    const preMatch = /<pre[^>]*>([\s\S]*?)<\/pre>/i.exec(html);
    if (preMatch) {
      const code = decodeEntities(preMatch[1].replace(/<[^>]+>/g, "")).trim();
      return code.length > 500 ? code.substring(0, 500) + "\n// ..." : code;
    }
    const codeMatch = /<code[^>]*>([\s\S]*?)<\/code>/i.exec(html);
    if (codeMatch) {
      const code = decodeEntities(codeMatch[1].replace(/<[^>]+>/g, "")).trim();
      return code.length > 500 ? code.substring(0, 500) + "\n// ..." : code;
    }
    return undefined;
  }

  static extractNotes(text: string): string[] {
    const patterns = [
      /Note[:\s]+([^\n]+)/gi,
      /注意[:\s]+([^\n]+)/gi,
      /Important[:\s]+([^\n]+)/gi,
      /Warning[:\s]+([^\n]+)/gi,
    ];

    const notes: string[] = [];
    for (const pattern of patterns) {
      const matches = text.matchAll(pattern);
      for (const match of matches) {
        const note = match[1].trim();
        if (note && note.length > 10) {
          notes.push(note.substring(0, 150));
        }
      }
    }
    return notes.slice(0, 3);
  }

  static extractDescription(text: string): string | undefined {
    const paragraphs = text.split(/\n\n+/);
    if (paragraphs.length > 0) {
      const desc = paragraphs.slice(0, 2).join(" ");
      return desc.substring(0, 300);
    }
    return undefined;
  }

  static async extract(docPath: string): Promise<ExtractedInfo> {
    try {
      const html = await fs.readFile(docPath, "utf-8");
      const text = stripHtml(html);
      const md = htmlToMarkdown(html);

      return {
        syntax: this.extractSyntax(text),
        parameters: this.extractParameters(text),
        returns: this.extractReturns(text),
        example: this.extractExample(html),
        notes: this.extractNotes(text),
        description: this.extractDescription(md),
      };
    } catch (error) {
      return {};
    }
  }
}
