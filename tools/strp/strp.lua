---@class StrpModule
---@field render fun(template: string, env: table, options?: table): string
---@field compile fun(template: string): fun(env: table): string
---@field clear_cache fun(): nil
local M = {}

-- 导入过滤器模块
local filter_mod = require 'wl.tools.strp.filters'

--============================================================================
-- 缓存系统
--============================================================================

--- 模板缓存
---@type table<string, fun(env: table): string>
local template_cache = {}

--- 缓存统计
local cache_stats = {
    hits = 0,
    misses = 0,
    size = 0
}

--- 最大缓存大小
local MAX_CACHE_SIZE = 100

--============================================================================
-- 常量定义
--============================================================================

--- 开启新块的关键字
---@type table<string, boolean>
local BLOCK_KEYWORDS = {
    ["if"] = true,     -- 条件判断
    ["for"] = true,    -- 循环
    ["while"] = true,  -- 循环
    ["unless"] = true, -- 反向条件
    ["case"] = true,   -- 分支
    ["with"] = true,   -- 作用域
    ["macro"] = true,  -- 宏定义
}

--- 结束块的关键字
---@type table<string, boolean>
local END_KEYWORDS = {
    ["end"] = true,      -- 通用结束
    ["endif"] = true,    -- 条件结束
    ["endfor"] = true,   -- 循环结束
    ["endwhile"] = true, -- 循环结束
    ["endunless"] = true,-- 反向条件结束
    ["endcase"] = true,  -- 分支结束
    ["endwith"] = true,  -- 作用域结束
    ["endmacro"] = true, -- 宏定义结束
}

--============================================================================
-- 核心工具函数
--============================================================================

--- 安全执行 Lua 表达式
---@param expr string 要执行的表达式
---@param env table 环境变量表
---@return any|nil result 执行结果，失败时返回 nil
---@return string? error 错误信息，成功时返回 nil
local function eval(expr, env)
    local f, err = load("return " .. expr, nil, "t", env)
    if not f then return nil, err end
    local ok, res = pcall(f)
    return ok and res or nil, not ok and res or err
end

--- 报错并提供上下文信息
---@param msg string 错误消息
---@param template string 模板字符串
---@param pos number 错误位置
local function error_with_context(msg, template, pos)
    local context = template:sub(math.max(1, pos - 20), math.min(#template, pos + 20))
    error(string.format("%s\n附近: ...%s...", msg, context))
end

--- 获取嵌套对象的值（支持 obj.prop.subprop 语法）
---@param env table 环境变量表
---@param key string 属性键（支持点分隔）
---@return any|nil 属性值，不存在时返回 nil
local function get_env_value(env, key)
    local cur = env
    for part in key:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end

--============================================================================
-- 模板解析工具函数
--============================================================================

--- 查找匹配的块结束位置（支持嵌套）
---@param template string 模板字符串
---@param start_pos integer 开始搜索的位置
---@return integer|nil end_start 结束标签的开始位置
---@return integer|nil end_finish 结束标签的结束位置
local function find_block_end(template, start_pos)
    local depth = 1  -- 嵌套深度
    local pos = start_pos
    
    while depth > 0 and pos <= #template do
        -- 查找下一个模板标签
        local tag_s, tag_e = template:find("{%%[^}]*%%}", pos)
        if not tag_s or not tag_e then break end
        
        -- 类型保护：确保是整数
        tag_s = math.floor(tag_s)
        tag_e = math.floor(tag_e)
        
        -- 提取标签内容并获取标签名
        local content = template:sub(tag_s + 2, tag_e - 2):match("^%s*(.-)%s*$")
        local tag_name = content:match("^(%w+)")
        
        if END_KEYWORDS[tag_name] then
            depth = depth - 1
            if depth == 0 then return tag_s, tag_e end
        elseif BLOCK_KEYWORDS[tag_name] then
            depth = depth + 1
        end
        
        pos = tag_e + 1
    end
    return nil  -- 未找到匹配的结束标签
end

--- 解析过滤器字符串（如 "name|upper|format('Hello %s')"）
---@param text string 包含过滤器的文本
---@return string key 变量名
---@return table filters 过滤器列表
local function parse_filters(text)
    local parts = {}
    -- 按 | 分割文本
    for part in text:gmatch("[^|]+") do
        table.insert(parts, part:match("^%s*(.-)%s*$"))  -- 去除首尾空格
    end
    
    local key = parts[1]  -- 第一部分是变量名
    local filters = {}
    
    -- 解析过滤器（从第二部分开始）
    for i = 2, #parts do
        local name, args_str = parts[i]:match("([%w_]+)%((.-)%)")
        if name then
            -- 带参数的过滤器（括号格式）
            local args = {}
            if args_str then
                for arg in args_str:gmatch("[^,]+") do
                    table.insert(args, arg:match("^%s*(.-)%s*$"))
                end
            end
            table.insert(filters, {name = name, args = args})
        else
            -- 检查冒号分隔的参数格式 name:arg1:arg2
            local filter_parts = {}
            for part in parts[i]:gmatch("[^:]+") do
                table.insert(filter_parts, part:match("^%s*(.-)%s*$"))
            end
            
            if #filter_parts > 1 then
                -- 带参数的过滤器（冒号格式）
                local name = filter_parts[1]
                local args = {}
                for j = 2, #filter_parts do
                    table.insert(args, filter_parts[j])
                end
                table.insert(filters, {name = name, args = args})
            else
                -- 无参数的过滤器
                local name = parts[i]:match("([%w_]+)")
                if name then
                    table.insert(filters, {name = name, args = {}})
                end
            end
        end
    end
    
    return key, filters
end

--- 替换模板中的变量（${variable|filter} 语法）
---@param text string 要处理的文本
---@param env table 环境变量
---@return string, integer 处理后的文本
local function replace_variables(text, env)
    if type(text) ~= "string" then
        return "", 0  -- 非字符串输入返回空字符串
    end
    
    -- 使用正则表达式替换所有 ${...} 变量
    return text:gsub("%${([^}]+)}", function(content)
        local key, filters = parse_filters(content)
        local value = get_env_value(env, key)
        
        -- 应用所有过滤器
        for _, filter in ipairs(filters) do
            local filter_func = filter_mod.get_filter(filter.name)
            if filter_func then
                value = filter_func(value, table.unpack(filter.args))
            end
        end
        
        -- 返回格式化后的值，如果值为 nil 则保持原样
        return value ~= nil and tostring(value) or "${" .. content .. "}"
    end)
end

--============================================================================
-- 块处理器
--============================================================================

-- 前向声明主解析函数
local parse_template

--- 处理 include 指令（包含其他模板文件）
---@param template string 当前模板（用于错误报告）
---@param env table 环境变量
---@param code string include 指令的参数
---@return string 包含文件的处理结果
local function handle_include(template, env, code)
    -- 支持三种引用方式：双引号、单引号、无引号
    local module_name = code:match([["(.-)"]]) or code:match([['(.-)']]) or code:match("([%w%.]+)")
    if not module_name then
        error_with_context("无效的 include 语法", template, 1)
    end
    
    -- 尝试加载模块
    local ok, content = pcall(require, module_name)
    if not ok then
        error_with_context("找不到包含文件: " .. module_name, template, 1)
    end
    
    -- 处理不同类型的返回值
    if type(content) == "string" then
        return parse_template(content, env)
    elseif type(content) == "table" and content[1] then
        return parse_template(tostring(content[1]), env)
    else
        error_with_context("包含文件未返回字符串", template, 1)
        return ""  -- 虽然上面会抛出错误，但为了类型检查添加返回值
    end
end

--- 处理 if 条件块
---@param template string 模板字符串
---@param env table 环境变量
---@param tag_end integer if 标签的结束位置
---@param code string 条件表达式
---@return string result 处理结果
---@return integer next_pos 下一个处理位置
local function handle_if(template, env, tag_end, code)
    local end_s, end_e = find_block_end(template, tag_end + 1)
    if not end_s then
        error_with_context("if 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    local cond = eval(code, env)
    local result = ""
    
    -- 只有条件为真时才处理块内容
    if cond then
        result = parse_template(block, env)
    end
    
    return result, end_e + 1
end

--- 处理 for 循环块
---@param template string 模板字符串
---@param env table 环境变量
---@param tag_end integer for 标签的结束位置
---@param code string 循环表达式
---@return string result 处理结果
---@return integer next_pos 下一个处理位置
local function handle_for(template, env, tag_end, code)
    local end_s, end_e = find_block_end(template, tag_end + 1)
    if not end_s then
        error_with_context("for 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    local result = {}
    
    -- 解析 for k,v in table 语法
    local key_var, value_var, expr = code:match("([%w_]+)%s*,%s*([%w_]+)%s+in%s+(.+)")
    if key_var and value_var then
        local list = eval(expr, env)
        if type(list) == "table" then
            for k, v in pairs(list) do
                local new_env = setmetatable({[key_var] = k, [value_var] = v}, {__index = env})
                table.insert(result, parse_template(block, new_env))
            end
        end
        return table.concat(result), end_e + 1
    end
    
    -- 解析 for var in table 语法
    local var, expr = code:match("([%w_]+)%s+in%s+(.+)")
    if var and expr then
        local list = eval(expr, env)
        if type(list) == "table" then
            for _, v in ipairs(list) do
                local new_env = setmetatable({[var] = v}, {__index = env})
                table.insert(result, parse_template(block, new_env))
            end
        end
        return table.concat(result), end_e + 1
    end
    
    return "", end_e + 1
end

--============================================================================
-- 主解析函数
--============================================================================

--- 解析模板字符串的主函数
---@param template string 要解析的模板字符串
---@param env table 环境变量表
---@return string 解析后的结果字符串
function parse_template(template, env)
    local result = {}  -- 结果字符串数组
    local pos = 1      -- 当前处理位置
    
    while pos <= #template do
        -- 查找注释 {# comment #}
        local comment_s, comment_e = template:find("{#.-#}", pos)
        -- 类型保护：确保 comment_s 和 comment_e 是有效的整数
        comment_s = comment_s and math.floor(comment_s) or nil
        comment_e = comment_e and math.floor(comment_e) or nil
        
        -- 查找模板标签 {% tag code %}
        local tag_s, tag_e = template:find("{%%[^}]*%%}", pos)
        -- 类型保护：确保 tag_s 和 tag_e 是有效的整数
        tag_s = tag_s and math.floor(tag_s) or nil
        tag_e = tag_e and math.floor(tag_e) or nil
        
        -- 确定下一个要处理的位置和类型
        local next_pos = nil
        local is_comment = false
        
        if comment_s and tag_s then
            -- 两种标记都存在，选择位置较前的
            if comment_s < tag_s then
                next_pos = comment_s
                is_comment = true
            else
                next_pos = tag_s
            end
        elseif comment_s then
            next_pos = comment_s
            is_comment = true
        elseif tag_s then
            next_pos = tag_s
        else
            -- 没有更多标记，处理剩余文本
            local remaining_text = template:sub(pos)
            local processed_text = replace_variables(remaining_text, env)
            if type(processed_text) == "string" then
                table.insert(result, processed_text)
            else
                error("replace_variables 返回了非字符串类型: " .. type(processed_text))
            end
            break
        end
        
        -- 添加标记前的普通文本
        if next_pos > pos then
            local text_part = template:sub(pos, next_pos - 1)
            local processed_text = replace_variables(text_part, env)
            if type(processed_text) == "string" then
                table.insert(result, processed_text)
            else
                error("replace_variables 返回了非字符串类型: " .. type(processed_text))
            end
        end
        
        if is_comment then
            -- 跳过注释
            if comment_e then
                pos = comment_e + 1
            else
                pos = pos + 1  -- 如果注释结束位置为 nil，跳到下一个位置
            end
        else
            -- 处理模板标签
            if not tag_s or not tag_e then
                -- 标签解析失败，跳到下一个位置
                pos = pos + 1
            else
                local content = template:sub(tag_s + 2, tag_e - 2):match("^%s*(.-)%s*$")
                local tag_name, code = content:match("^(%w+)%s*(.*)")
                
                if tag_name == "include" then
                    -- 处理 include 指令
                    table.insert(result, handle_include(template, env, code))
                    pos = tag_e + 1
                elseif tag_name == "if" then
                    -- 处理 if 条件块
                    local block_result, new_pos = handle_if(template, env, tag_e, code)
                    table.insert(result, block_result)
                    pos = new_pos
                elseif tag_name == "for" then
                    -- 处理 for 循环块
                    local block_result, new_pos = handle_for(template, env, tag_e, code)
                    table.insert(result, block_result)
                    pos = new_pos
                else
                    -- 未知标签，跳过
                    pos = tag_e + 1
                end
            end
        end
    end
    
    return table.concat(result)
end

--============================================================================
-- 公共 API
--============================================================================

--- 渲染模板字符串
---@param template string 模板字符串
---@param env table 环境变量表
---@param options? table 选项表，支持 {trim_whitespace: boolean}
---@return string 渲染后的结果
function M.render(template, env, options)
    options = options or {}
    local result = parse_template(template, env)
    
    -- 可选的空格处理
    if options.trim_whitespace then
        result = result:gsub("%s+", " ")     -- 合并多个空格为一个
                       :gsub("^%s+", "")     -- 去除开头空格
                       :gsub("%s+$", "")     -- 去除结尾空格
    end
    
    return result
end

--- 编译模板为可重用的函数（带缓存）
---@param template string 模板字符串
---@return fun(env: table): string 编译后的模板函数
function M.compile(template)
    -- 检查缓存
    if template_cache[template] then
        cache_stats.hits = cache_stats.hits + 1
        return template_cache[template]
    end
    
    cache_stats.misses = cache_stats.misses + 1
    
    -- 缓存大小限制
    if cache_stats.size >= MAX_CACHE_SIZE then
        -- 简单的 LRU：清空一半缓存
        local keys = {}
        for k in pairs(template_cache) do
            table.insert(keys, k)
        end
        
        for i = 1, math.floor(#keys / 2) do
            template_cache[keys[i]] = nil
        end
        cache_stats.size = math.floor(cache_stats.size / 2)
    end
    
    -- 编译模板
    local compiled_func = function(env)
        return parse_template(template, env)
    end
    
    -- 存入缓存
    template_cache[template] = compiled_func
    cache_stats.size = cache_stats.size + 1
    
    return compiled_func
end

--- 清空模板缓存
function M.clear_cache()
    template_cache = {}
    cache_stats = {
        hits = 0,
        misses = 0,
        size = 0
    }
end

--- 获取缓存统计信息
---@return table 缓存统计
function M.get_cache_stats()
    return {
        hits = cache_stats.hits,
        misses = cache_stats.misses,
        size = cache_stats.size,
        hit_rate = cache_stats.hits > 0 and (cache_stats.hits / (cache_stats.hits + cache_stats.misses)) or 0
    }
end

--- 带缓存的渲染函数
---@param template string 模板字符串
---@param env table 环境变量表
---@param options? table 选项表
---@return string 渲染后的结果
function M.render_cached(template, env, options)
    local compiled = M.compile(template)
    local result = compiled(env)
    
    -- 应用选项
    if options and options.trim_whitespace then
        result = result:gsub("%s+", " ")     -- 合并多个空格为一个
                       :gsub("^%s+", "")     -- 去除开头空格
                       :gsub("%s+$", "")     -- 去除结尾空格
    end
    
    return result
end

return M
