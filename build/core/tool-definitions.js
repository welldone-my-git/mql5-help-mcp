/** Stable definitions for domain-neutral MCP tools. */
export const CORE_TOOL_DEFINITIONS = [
    {
        name: "smart_query",
        description: "🎯 智能查询工具（推荐）：输入错误信息、函数名或问题，自动搜索并返回精简答案。完全本地化，零API成本，节省80%+ token。适用于：错误诊断、函数查询、快速学习。",
        inputSchema: {
            type: "object",
            properties: {
                query: {
                    type: "string",
                    description: "查询内容：1) 错误信息如 'error 256: undeclared identifier ResultCode' 2) 函数名如 'OrderSend' 3) 类名如 'CTrade' 4) 问题如 'how to send order'",
                },
                mode: {
                    type: "string",
                    enum: ["quick", "detailed"],
                    description: "返回模式: quick=精简答案(~500 tokens,推荐), detailed=详细说明(~1500 tokens)",
                    default: "quick",
                },
            },
            required: ["query"],
        },
    },
    {
        name: "search",
        description: "搜索MQL5文档（函数名、类名、关键字）。返回文档列表，需再调用get获取内容。如需直接答案请用smart_query。",
        inputSchema: {
            type: "object",
            properties: {
                query: {
                    type: "string",
                    description: "搜索关键词或错误文本",
                },
                limit: {
                    type: "number",
                    description: "返回结果数量",
                    default: 10,
                },
            },
            required: ["query"],
        },
    },
    {
        name: "get",
        description: "获取指定文档的详细内容（完整HTML，~3000 tokens）。如需精简答案请用smart_query。",
        inputSchema: {
            type: "object",
            properties: {
                filename: {
                    type: "string",
                    description: "文档名（可不带扩展）",
                },
            },
            required: ["filename"],
        },
    },
    {
        name: "browse",
        description: "📂 浏览文档分类目录，包含 MQL5 API 分类与两本内置电子书（MQL5算法交易手册、神经网络手册）。",
        inputSchema: {
            type: "object",
            properties: {
                category: {
                    type: "string",
                    description: "分类名（可选）。API 分类: trading, indicators, math, array, string, datetime, files, chart, objects, onnx。电子书: algo_book, neural_book, algo_book/2（第2章详细列表）。留空显示所有分类。",
                },
            },
        },
    },
    {
        name: "log_error",
        description: "📝 记录MQL5编译错误到本地数据库。用于收集常见错误及解决方案，下次遇到相同错误时可快速查询。",
        inputSchema: {
            type: "object",
            properties: {
                error_code: {
                    type: "string",
                    description: "错误代码（如 E512, E308）",
                },
                error_message: {
                    type: "string",
                    description: "完整错误消息",
                },
                file_path: {
                    type: "string",
                    description: "发生错误的文件路径（可选，隐私考虑）",
                },
                solution: {
                    type: "string",
                    description: "解决方案描述（可选）",
                },
                related_docs: {
                    type: "string",
                    description: "相关文档列表，JSON数组格式（可选）",
                },
            },
            required: ["error_code", "error_message"],
        },
    },
    {
        name: "list_common_errors",
        description: "📊 列出最常见的MQL5编译错误（按出现频率排序）。帮助快速了解常见问题。",
        inputSchema: {
            type: "object",
            properties: {
                limit: {
                    type: "number",
                    description: "返回错误数量（默认10）",
                    default: 10,
                },
            },
        },
    },
    {
        name: "manage_error_db",
        description: "🔧 管理错误数据库：导出/导入错误记录，查看数据库统计信息。支持团队共享错误库。",
        inputSchema: {
            type: "object",
            properties: {
                action: {
                    type: "string",
                    enum: ["export", "import", "stats"],
                    description: "操作类型：export=导出为JSON, import=从JSON导入, stats=查看统计",
                },
                data: {
                    type: "string",
                    description: "导入时的JSON数据（action=import时必需）",
                },
                anonymize: {
                    type: "boolean",
                    description: "导出时是否移除文件路径（保护隐私，默认false）",
                    default: false,
                },
            },
            required: ["action"],
        },
    },
    {
        name: "build_semantic_index",
        description: "🔮 构建语义向量索引（一次性）。调用 Ollama 本地 embedding 模型对所有已索引文档向量化并存入本地 SQLite。完成后 search/smart_query 自动切换为混合模式（关键词 + 语义），支持中文查询命中英文文档。需先在 config.json 配置 embedding 字段并安装 Ollama。",
        inputSchema: {
            type: "object",
            properties: {
                force_reindex: {
                    type: "boolean",
                    description: "是否强制重建（忽略已有索引，默认 false）",
                    default: false,
                },
                limit: {
                    type: "number",
                    description: "限制最多处理的文档数量（调试用，默认不限制）",
                },
            },
        },
    },
    {
        name: "list_libraries",
        description: "📚 列出当前已加载的所有资料库（内置文档 + 用户配置的外部代码库），显示每个库的文件数量与路径。配置文件位于 ~/.knowledge-mcp/config.json。",
        inputSchema: {
            type: "object",
            properties: {},
        },
    },
    {
        name: "preprocess_library",
        description: "🤖 用 Claude Haiku 预处理指定外部库的 .mqh 文件，提取类/方法/用途等结构化知识并缓存到本地。只需运行一次；源文件更新后会自动重新处理。需要环境变量 ANTHROPIC_API_KEY。",
        inputSchema: {
            type: "object",
            properties: {
                library_key: {
                    type: "string",
                    description: "库的 key，与 config.json 中 extraLibraries[].key 一致。留空则处理所有已加载的外部库。",
                },
            },
        },
    },
    {
        name: "analyze_code",
        description: "🧠 智能代码分析：将你的 MQL5 代码与已预处理的外部库知识对比，返回结构化的 API 摘要和可优化点，供 Claude 给出具体改进建议。需先运行 preprocess_library。",
        inputSchema: {
            type: "object",
            properties: {
                code: {
                    type: "string",
                    description: "需要分析的 MQL5 代码片段（EA、指标或函数均可）",
                },
                library_key: {
                    type: "string",
                    description: "限定分析范围到指定库（可选，留空则跨所有已预处理库分析）",
                },
            },
            required: ["code"],
        },
    },
    {
        name: "record_fix",
        description: "💾 记录已验证的代码修复模式。当 analyze_code 或 analyze_structure 发现问题并由 Claude 给出修复建议后，调用此工具将 问题→修复 映射保存到本地。下次遇到相同问题时直接命中，无需再次分析。",
        inputSchema: {
            type: "object",
            properties: {
                pattern_description: {
                    type: "string",
                    description: "问题的简短描述，如 'OnTick 中未检查持仓数量就调用 CTrade::Buy'",
                },
                fix_description: {
                    type: "string",
                    description: "修复说明，如 '在 Buy 调用前添加 if(PositionsTotal()>0) return'",
                },
                original_snippet: {
                    type: "string",
                    description: "有问题的代码示例（可选）",
                },
                fixed_snippet: {
                    type: "string",
                    description: "修复后的代码示例（可选）",
                },
                library_key: {
                    type: "string",
                    description: "关联的库 key（可选）",
                },
                tags: {
                    type: "string",
                    description: "标签，JSON 数组格式，如 '[\"CTrade\",\"OnTick\",\"risk\"]'（可选）",
                },
            },
            required: ["pattern_description", "fix_description"],
        },
    },
    {
        name: "list_fixes",
        description: "📋 查看已记录的代码修复模式，按使用频率排序。也可按关键词搜索。",
        inputSchema: {
            type: "object",
            properties: {
                query: {
                    type: "string",
                    description: "搜索关键词（可选，留空则列出全部）",
                },
                limit: {
                    type: "number",
                    description: "返回数量（默认 20）",
                    default: 20,
                },
            },
        },
    },
    {
        name: "manage_knowledge",
        description: "🔄 管理预处理库知识：export（导出为磁盘 JSON 文件供分享）、import（从文件路径导入他人知识包，无需自己运行 Haiku）、stats（查看各库的知识统计）。",
        inputSchema: {
            type: "object",
            properties: {
                action: {
                    type: "string",
                    enum: ["export", "import", "stats"],
                    description: "操作类型",
                },
                library_key: {
                    type: "string",
                    description: "export 时必填，指定要导出的库 key",
                },
                file_path: {
                    type: "string",
                    description: "import 时必填，指向 .knowledge.json 文件的绝对路径",
                },
                import_as: {
                    type: "string",
                    description: "import 时可选，覆盖知识包中的库 key（用于重命名）",
                },
            },
            required: ["action"],
        },
    },
];
