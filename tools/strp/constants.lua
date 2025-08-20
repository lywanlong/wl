--============================================================================
-- STRP 模板引擎 - 配置常量 v2.1
--
-- 统一管理所有配置参数，便于性能调优和功能扩展
-- 
-- 模块职责：
-- • 缓存配置：控制缓存行为和性能参数
-- • 语法配置：定义模板语法标记和分隔符
-- • 性能参数：设置各种性能相关的阈值
-- • 安全配置：控制安全相关的限制参数
-- • 默认值：提供合理的默认配置
--============================================================================

---@class StrpConstants 配置常量模块
---@field CACHE StrpCacheConfig 缓存相关配置
---@field SYNTAX StrpSyntaxConfig 语法相关配置  
---@field PERFORMANCE StrpPerformanceConfig 性能相关配置
---@field SECURITY StrpSecurityConfig 安全相关配置
---@field VERSION string 版本信息
local M = {}

--============================================================================
-- 版本信息
--============================================================================

M.VERSION = "2.1.0"

--============================================================================
-- 缓存配置
--============================================================================

---@class StrpCacheConfig
M.CACHE = {
    -- 最大缓存条目数 (LRU淘汰策略)
    MAX_ENTRIES = 1000,
    
    -- 自动清理周期 (单位：秒)
    CLEANUP_INTERVAL = 300,
    
    -- 缓存生存时间 (单位：秒，0表示永不过期)
    TTL = 0,
    
    -- 缓存键最大长度 (防止内存溢出)
    MAX_KEY_LENGTH = 256,
    
    -- 是否启用缓存统计
    ENABLE_STATS = true,
    
    -- 是否启用缓存压缩
    ENABLE_COMPRESSION = false
}

--============================================================================
-- 语法配置
--============================================================================

---@class StrpSyntaxConfig
M.SYNTAX = {
    -- 变量标记
    VARIABLE_START = "${",
    VARIABLE_END = "}",
    
    -- 控制结构标记
    BLOCK_START = "{%",
    BLOCK_END = "%}",
    
    -- 注释标记
    COMMENT_START = "{#",
    COMMENT_END = "#}",
    
    -- 过滤器分隔符
    FILTER_SEPARATOR = "|",
    FILTER_ARG_SEPARATOR = ":",
    
    -- 参数分隔符
    ARG_SEPARATOR = ",",
    
    -- 转义字符
    ESCAPE_CHAR = "\\",
    
    -- 字符串引号
    STRING_QUOTES = {"'", '"'},
    
    -- 关键字列表
    KEYWORDS = {
        -- 控制结构
        "if", "elif", "else", "endif",
        "for", "endfor", "in",
        "while", "endwhile",
        "with", "endwith",
        "macro", "endmacro",
        "try", "except", "finally", "endtry",
        "switch", "case", "default", "endswitch",
        "include", "extends", "block", "endblock",
        
        -- 逻辑操作符
        "and", "or", "not",
        "is", "in", "not_in",
        
        -- 内置常量
        "true", "false", "nil", "null"
    }
}

--- 开启新块的关键字映射表
---@type table<string, boolean>
M.BLOCK_KEYWORDS = {
    ["if"] = true,       -- 条件判断：{% if condition %}...{% endif %}
    ["unless"] = true,   -- 反向条件：{% unless condition %}...{% endunless %}
    ["for"] = true,      -- 遍历循环：{% for item in list %}...{% endfor %}
    ["while"] = true,    -- 条件循环：{% while condition %}...{% endwhile %}
    ["switch"] = true,   -- 多分支选择：{% switch value %}...{% endswitch %}
    ["with"] = true,     -- 局部作用域：{% with expr as var %}...{% endwith %}
    ["try"] = true,      -- 异常处理：{% try %}...{% catch %}...{% endtry %}
    ["macro"] = true,    -- 宏定义：{% macro name(args) %}...{% endmacro %}
}

--- 结束块的关键字映射表
---@type table<string, boolean>
M.END_KEYWORDS = {
    ["end"] = true,        -- 通用结束：可以结束任何块
    ["endif"] = true,      -- 结束 if 块
    ["endunless"] = true,  -- 结束 unless 块
    ["endfor"] = true,     -- 结束 for 块
    ["endwhile"] = true,   -- 结束 while 块
    ["endswitch"] = true,  -- 结束 switch 块
    ["endwith"] = true,    -- 结束 with 块
    ["endtry"] = true,     -- 结束 try 块
    ["endmacro"] = true,   -- 结束 macro 块
}

--============================================================================
-- 性能配置
--============================================================================

---@class StrpPerformanceConfig
M.PERFORMANCE = {
    -- 最大递归深度 (防止栈溢出)
    MAX_RECURSION_DEPTH = 100,
    
    -- 最大模板大小 (单位：字节)
    MAX_TEMPLATE_SIZE = 1024 * 1024,  -- 1MB
    
    -- 最大输出大小 (单位：字节)
    MAX_OUTPUT_SIZE = 10 * 1024 * 1024,  -- 10MB
    
    -- 最大循环次数 (防止无限循环)
    MAX_LOOP_ITERATIONS = 10000,
    
    -- 表达式求值超时 (单位：毫秒)
    EVAL_TIMEOUT = 5000,
    
    -- 内存使用监控阈值 (单位：MB)
    MEMORY_WARNING_THRESHOLD = 100,
    
    -- 是否启用性能分析
    ENABLE_PROFILING = false,
    
    -- 批处理大小
    BATCH_SIZE = 100,
    
    -- 最大模板缓存大小
    MAX_CACHE_SIZE = 100
}

--============================================================================
-- 安全配置
--============================================================================

---@class StrpSecurityConfig
M.SECURITY = {
    -- 是否启用XSS防护
    ENABLE_XSS_PROTECTION = true,
    
    -- 是否启用表达式沙箱
    ENABLE_SANDBOX = true,
    
    -- 允许的函数白名单
    ALLOWED_FUNCTIONS = {
        -- 数学函数
        "math.abs", "math.ceil", "math.floor", "math.max", "math.min",
        "math.sqrt", "math.sin", "math.cos", "math.tan",
        
        -- 字符串函数
        "string.len", "string.sub", "string.upper", "string.lower",
        "string.gsub", "string.match", "string.find",
        
        -- 表格函数
        "table.insert", "table.remove", "table.sort", "table.concat",
        
        -- 类型检查
        "type", "tostring", "tonumber",
        
        -- 日期时间
        "os.date", "os.time"
    },
    
    -- 禁止的函数黑名单
    FORBIDDEN_FUNCTIONS = {
        -- 文件操作
        "io.open", "io.read", "io.write", "io.close",
        "io.input", "io.output", "io.flush",
        
        -- 系统操作
        "os.execute", "os.remove", "os.rename", "os.exit",
        "os.getenv", "os.setlocale",
        
        -- 模块加载
        "require", "dofile", "loadfile", "load", "loadstring",
        
        -- 调试接口
        "debug.getinfo", "debug.getlocal", "debug.setlocal",
        "debug.getupvalue", "debug.setupvalue",
        
        -- 垃圾收集
        "collectgarbage"
    },
    
    -- 最大变量名长度
    MAX_VARIABLE_NAME_LENGTH = 64,
    
    -- 最大字符串长度
    MAX_STRING_LENGTH = 65536,
    
    -- 是否允许动态代码执行
    ALLOW_DYNAMIC_EXECUTION = false
}

--============================================================================
-- 默认选项
--============================================================================

---@class StrpDefaultOptions
M.DEFAULT_OPTIONS = {
    -- 是否启用缓存
    cache = true,
    
    -- 是否启用调试模式
    debug = false,
    
    -- 是否启用严格模式
    strict = false,
    
    -- 是否自动转义
    autoescape = false,
    
    -- 默认编码
    encoding = "utf-8",
    
    -- 错误处理策略 ("strict", "ignore", "replace")
    error_handling = "strict",
    
    -- 输出格式 ("string", "table")
    output_format = "string",
    
    -- 是否保留空白字符
    preserve_whitespace = false,
    
    -- 变量未定义时的处理 ("error", "empty", "keep")
    undefined_behavior = "error"
}

--============================================================================
-- 工具函数
--============================================================================

--- 获取深拷贝的默认选项
---@return table options 默认选项的深拷贝
function M.get_default_options()
    local function deep_copy(obj)
        if type(obj) ~= "table" then
            return obj
        end
        local copy = {}
        for k, v in pairs(obj) do
            copy[k] = deep_copy(v)
        end
        return copy
    end
    return deep_copy(M.DEFAULT_OPTIONS)
end

--- 合并选项配置
---@param user_options table 用户提供的选项
---@param base_options? table 基础选项，默认为DEFAULT_OPTIONS
---@return table merged_options 合并后的选项
function M.merge_options(user_options, base_options)
    base_options = base_options or M.DEFAULT_OPTIONS
    local merged = M.get_default_options()
    
    if type(user_options) == "table" then
        for k, v in pairs(user_options) do
            merged[k] = v
        end
    end
    
    return merged
end

--- 验证配置参数
---@param config table 配置参数
---@return boolean valid 是否有效
---@return string? error_msg 错误信息
function M.validate_config(config)
    if type(config) ~= "table" then
        return false, "配置必须是一个表"
    end
    
    -- 验证缓存配置
    if config.cache and type(config.cache) ~= "boolean" then
        return false, "cache选项必须是布尔值"
    end
    
    -- 验证调试配置
    if config.debug and type(config.debug) ~= "boolean" then
        return false, "debug选项必须是布尔值"
    end
    
    -- 验证错误处理策略
    if config.error_handling then
        local valid_strategies = {strict = true, ignore = true, replace = true}
        if not valid_strategies[config.error_handling] then
            return false, "error_handling必须是'strict'、'ignore'或'replace'之一"
        end
    end
    
    return true
end

return M
