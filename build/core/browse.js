import * as fsSync from "fs";
import * as path from "path";
// 浏览分类（仍以官方主题分类为主）
// ── Book browsing helpers ─────────────────────────────────────────────────────
function readHtmlTitle(absPath) {
    try {
        const raw = fsSync.readFileSync(absPath, "utf-8").slice(0, 3000);
        const m = raw.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
        return m ? m[1].replace(/<[^>]+>/g, "").trim() : path.basename(absPath, path.extname(absPath));
    }
    catch {
        return path.basename(absPath, path.extname(absPath));
    }
}
function numericFileCompare(a, b) {
    const parts = (s) => s.split(/[_.]/).map(p => (p !== "" && !isNaN(Number(p)) ? Number(p) : p));
    const ap = parts(a), bp = parts(b);
    for (let i = 0; i < Math.min(ap.length, bp.length); i++) {
        if (ap[i] < bp[i])
            return -1;
        if (ap[i] > bp[i])
            return 1;
    }
    return ap.length - bp.length;
}
async function browseBook(getIndex, repoKey, bookTitle, subChapter // e.g. "2" means show only chapter 2
) {
    const index = await getIndex();
    // collect all entries belonging to this book, sorted numerically
    const entries = [];
    for (const entry of index.values()) {
        if (entry.repo === repoKey)
            entries.push(entry);
    }
    const seen = new Set();
    const unique = entries.filter(e => {
        if (seen.has(e.absPath))
            return false;
        seen.add(e.absPath);
        return true;
    });
    unique.sort((a, b) => numericFileCompare(path.basename(a.relPath), path.basename(b.relPath)));
    // group by chapter (leading digit)
    const chapters = new Map();
    for (const e of unique) {
        const fname = path.basename(e.relPath);
        const m = fname.match(/^(\d+)_/);
        const ch = m ? m[1] : "0";
        if (!chapters.has(ch))
            chapters.set(ch, []);
        chapters.get(ch).push(e);
    }
    const SEP = "─".repeat(60);
    if (subChapter !== undefined) {
        // drill-down: show all files in one chapter
        const files = chapters.get(subChapter) ?? [];
        if (files.length === 0) {
            return `❌ 未找到第 ${subChapter} 章（可用: ${[...chapters.keys()].filter(k => k !== "0").join(", ")}）`;
        }
        const lines = [
            `📖 ${bookTitle} — 第 ${subChapter} 章（${files.length} 页）`,
            SEP, "",
        ];
        for (const e of files) {
            const fname = path.basename(e.relPath);
            const title = readHtmlTitle(e.absPath);
            lines.push(`  • ${fname}  —  ${title}`);
        }
        lines.push("", `💡 使用 get_doc <文件名> 查看内容，如: get_doc ${path.basename(files[0].relPath)}`);
        return lines.join("\n");
    }
    // top-level: chapter list
    const totalFiles = unique.length;
    const lines = [
        `📖 ${bookTitle}（共 ${totalFiles} 页）`,
        SEP, "",
    ];
    // misc files (no chapter prefix)
    const misc = chapters.get("0") ?? [];
    if (misc.length > 0) {
        const names = misc.map(e => path.basename(e.relPath, ".htm")).join(", ");
        lines.push(`  📄 序言/附录（${misc.length} 页）— ${names}`);
    }
    for (const [ch, files] of [...chapters.entries()].filter(([k]) => k !== "0").sort((a, b) => Number(a[0]) - Number(b[0]))) {
        // chapter title: first file numerically
        const firstTitle = readHtmlTitle(files[0].absPath);
        lines.push(`  📄 第 ${ch} 章（${files.length} 页）— ${firstTitle}`);
    }
    lines.push("");
    lines.push(`💡 使用 browse ${repoKey === "MQL5_Algo_Book" ? "algo_book" : "neural_book"}/<章号> 查看章节详细列表`);
    lines.push(`   使用 search <关键词> 直接搜索全书内容`);
    return lines.join("\n");
}
// ── Browse API categories ─────────────────────────────────────────────────────
export async function browseDocuments(category, getIndex) {
    const API_CATEGORIES = {
        trading: ["ordersend", "ordercheck", "ctrade", "positionselect"],
        indicators: ["icustom", "copybuffer", "indicatorcreate", "setindexbuffer"],
        math: ["mathabs", "mathsin", "mathcos", "mathrandom", "mathpow"],
        array: ["arrayresize", "arraycopy", "arraysort", "arrayinitialize"],
        string: ["stringfind", "stringsplit", "stringreplace", "stringformat"],
        datetime: ["timecurrent", "timelocal", "timetostruct", "timegmt"],
        files: ["fileopen", "fileclose", "filewrite", "fileread"],
        chart: ["chartopen", "chartredraw", "chartid", "chartsetinteger"],
        objects: ["objectcreate", "objectdelete", "objectsetinteger"],
        onnx: ["onnxcreate", "onnxrun", "onnxrelease", "MQL5_ONNX_Integration_Guide"],
    };
    if (!category) {
        const lines = ["📚 文档分类\n" + "=".repeat(60), "", "MQL5 API 分类："];
        for (const [cat, docs] of Object.entries(API_CATEGORIES)) {
            lines.push(`  📁 ${cat}（${docs.length} 个）`);
        }
        lines.push("", "📖 内置电子书：", "  📖 algo_book    — MQL5 算法交易手册（582 页，7 章）", "  📖 neural_book  — 神经网络与机器学习手册（112 页，7 章）", "", "💡 使用 browse <分类> 查看具体内容", "   电子书示例: browse algo_book  /  browse neural_book  /  browse algo_book/2");
        return lines.join("\n");
    }
    const lower = category.toLowerCase();
    // ebook: algo_book[/chapter]
    if (lower === "algo_book" || lower.startsWith("algo_book/")) {
        const ch = lower.startsWith("algo_book/") ? lower.split("/")[1] : undefined;
        return browseBook(getIndex, "MQL5_Algo_Book", "MQL5 算法交易手册", ch);
    }
    // ebook: neural_book[/chapter]
    if (lower === "neural_book" || lower.startsWith("neural_book/")) {
        const ch = lower.startsWith("neural_book/") ? lower.split("/")[1] : undefined;
        return browseBook(getIndex, "Neural_Networks_Book", "神经网络与机器学习手册", ch);
    }
    // MQL5 API category
    const docs = API_CATEGORIES[lower];
    if (!docs) {
        const allCats = [...Object.keys(API_CATEGORIES), "algo_book", "neural_book"].join(", ");
        return `❌ 未知分类: ${category}\n\n可用: ${allCats}`;
    }
    let result = `📁 ${lower.toUpperCase()}\n${"=".repeat(60)}\n\n`;
    docs.forEach(doc => { result += `  • ${doc}.htm\n`; });
    return result;
}
