--============================================================================
-- STRP 模板引擎 - 解析器模块 v2.1
-- 
-- 负责模板语法的解析和处理：
-- • 块结构解析：查找匹配的开始/结束标记
-- • 过滤器链解析：处理复杂的过滤器语法
-- • 变量替换：处理 ${variable} 语法
-- • 嵌套模板：支持 ${var|filter:${nested_var}} 语法
-- • 参数解析：处理函数参数和过滤器参数
-- 
-- 核心算法：
-- • 递归下降解析：处理嵌套结构
-- • 智能括号匹配：支持任意深度的嵌套
-- • 惰性求值：提升性能
-- • 缓存优化：复用编译结果
--============================================================================

-- 模块依赖
local constants = require 'wl.tools.strp.constants'
local utils = require 'wl.tools.strp.utils'
local filter_mod = require 'wl.tools.strp.filters'

---@class StrpParser 解析器模块
local M = {}

--============================================================================
-- 缓存系统
--============================================================================

-- 编译缓存
local parse_cache = {}
local filter_cache = {}

-- 缓存清理函数
local function cleanup_cache()
    local cache_size = 0
    for _ in pairs(parse_cache) do
        cache_size = cache_size + 1
    end
    
    if cache_size > constants.PERFORMANCE.MAX_CACHE_SIZE then
        -- 清理一半的缓存（简单的LRU）
        local count = 0
        local half_size = math.floor(cache_size / 2)
        for key in pairs(parse_cache) do
            if count >= half_size then break end
            parse_cache[key] = nil
            count = count + 1
        end
    end
end

--============================================================================
-- 工具函数
--============================================================================

--- 获取变量值
---@param key string 变量键
---@param env table 环境变量表
---@return any value 变量值
local function get_variable_value(key, env)
    if not env or type(key) ~= "string" then
        return nil
    end
    
    -- 简单变量直接访问
    if not key:find("[.%[%]]") then
        return env[key]
    end
    
    -- 复杂路径使用工具函数
    local value, found = utils.get_nested_value(env, key)
    return found and value or nil
end

--- 转义正则表达式模式
---@param pattern string 模式字符串
---@return string escaped 转义后的模式
local function escape_pattern(pattern)
    return utils.escape_pattern(pattern)
end

--- 获取过滤器函数
---@param filter_name string 过滤器名称
---@return function? filter_func 过滤器函数
local function get_filter_function(filter_name)
    return filter_mod.get_filter(filter_name)
end

--============================================================================
-- 块结构解析 - 处理嵌套的控制结构
--============================================================================

--- 查找匹配的块结束位置
--- 
--- 使用栈式算法处理嵌套的控制结构，确保正确配对。
--- 支持任意深度的嵌套，如：if 中嵌套 for，for 中嵌套 switch 等。
--- 
---@param template string 完整的模板字符串
---@param start_pos integer 搜索起始位置
---@param block_type? string 块类型，用于精确匹配
---@return integer? end_start 结束标记的开始位置
---@return integer? end_finish 结束标记的结束位置
function M.find_block_end(template, start_pos, block_type)
    if type(template) ~= "string" or type(start_pos) ~= "number" then
        return nil, nil
    end
    
    local depth = 1
    local pos = start_pos
    local template_len = #template
    
    local block_start = constants.SYNTAX.BLOCK_START
    local block_end = constants.SYNTAX.BLOCK_END
    
    while pos <= template_len and depth > 0 do
        -- 查找下一个块标记
        local next_start = template:find(escape_pattern(block_start), pos, true)
        if not next_start then
            break
        end
        
        -- 查找对应的结束标记
        local tag_end = template:find(escape_pattern(block_end), next_start, true)
        if not tag_end then
            break
        end
        
        -- 提取标记内容
        local tag_content = template:sub(next_start + #block_start, tag_end - 1)
        local keyword = tag_content:match("^%s*(%w+)")
        
        if keyword then
            -- 检查是否为开始标记
            if constants.BLOCK_KEYWORDS[keyword] then
                depth = depth + 1
            -- 检查是否为结束标记
            elseif constants.END_KEYWORDS[keyword] then
                depth = depth - 1
                
                -- 如果找到匹配的结束标记
                if depth == 0 then
                    return next_start, tag_end + #block_end - 1
                end
            end
        end
        
        pos = tag_end + #block_end
    end
    
    return nil, nil
end

--============================================================================
-- 过滤器解析 - 处理复杂的过滤器链
--============================================================================

--- 解析过滤器链
--- 
--- 将形如 "user.name|upper|format('Hello %s')" 的文本解析为变量名和过滤器列表
--- 
---@param text string 要解析的文本
---@return string key 变量名
---@return table filters 过滤器列表，格式: {{name=string, args=table}, ...}
function M.parse_filters(text)
    if type(text) ~= "string" or text == "" then
        return "", {}
    end
    
    -- 检查缓存
    if filter_cache[text] then
        local cached = filter_cache[text]
        return cached[1], cached[2]
    end
    
    -- 按管道符分割过滤器链
    local parts = utils.split_string(text, constants.SYNTAX.FILTER_SEPARATOR)
    
    if #parts == 0 then
        return "", {}
    end
    
    local key = utils.trim(parts[1])  -- 第一部分是变量名
    local filters = {}
    
    -- 解析每个过滤器（从第二部分开始）
    for i = 2, #parts do
        local filter_part = utils.trim(parts[i])
        local filter_info = M.parse_single_filter(filter_part)
        
        if filter_info then
            table.insert(filters, filter_info)
        end
    end
    
    -- 缓存结果
    filter_cache[text] = {key, filters}
    cleanup_cache()
    
    return key, filters
end

--- 解析单个过滤器
--- 
--- 支持的语法格式：
--- 1. filter         -> {name="filter", args={}}
--- 2. filter:arg     -> {name="filter", args={"arg"}}
--- 3. filter(a,b)    -> {name="filter", args={"a","b"}}
--- 
---@param filter_text string 单个过滤器文本
---@return table? filter_info 过滤器信息，格式: {name=string, args=table}
function M.parse_single_filter(filter_text)
    if type(filter_text) ~= "string" or filter_text == "" then
        return nil
    end
    
    -- 尝试解析括号语法：filter(arg1, arg2, ...)
    local name, args_str = filter_text:match("^([%w_]+)%s*%((.*)%)%s*$")
    if name then
        local args = {}
        if args_str and args_str ~= "" then
            args = M.parse_function_args(args_str)
        end
        return {name = name, args = args}
    end
    
    -- 尝试解析冒号语法：filter:arg
    name, args_str = filter_text:match("^([%w_]+)%s*:%s*(.+)$")
    if name and args_str then
        -- 智能解析参数：支持模板变量和普通参数
        local arg = M.parse_smart_arg(args_str)
        return {name = name, args = {arg}}
    end
    
    -- 解析无参数过滤器：filter
    name = filter_text:match("^([%w_]+)%s*$")
    if name then
        return {name = name, args = {}}
    end
    
    return nil  -- 解析失败
end

--- 解析函数参数列表
--- 
--- 支持多种参数类型：
--- - 字符串：'text' 或 "text"
--- - 数字：123 或 12.34
--- - 变量：variable_name
--- - 嵌套模板：${variable}
--- 
---@param args_str string 参数字符串，如 "'hello', 123, variable"
---@return table args 解析后的参数数组
function M.parse_function_args(args_str)
    if type(args_str) ~= "string" or args_str == "" then
        return {}
    end
    
    local args = {}
    local parts = utils.split_string(args_str, constants.SYNTAX.ARG_SEPARATOR)
    
    for _, part in ipairs(parts) do
        local trimmed = utils.trim(part)
        if trimmed ~= "" then
            local arg = M.parse_single_arg(trimmed)
            table.insert(args, arg)
        end
    end
    
    return args
end

--- 解析单个参数
--- 
--- 支持字符串、数字、布尔值、变量名
--- 
---@param arg_str string 参数字符串
---@return any parsed_arg 解析后的参数值
function M.parse_single_arg(arg_str)
    if type(arg_str) ~= "string" then
        return arg_str
    end
    
    local trimmed = utils.trim(arg_str)
    
    -- 字符串字面量（单引号或双引号）
    local string_content = trimmed:match("^'(.*)'$") or trimmed:match('^"(.*)"$')
    if string_content then
        return string_content
    end
    
    -- 数字字面量
    local number_value = tonumber(trimmed)
    if number_value then
        return number_value
    end
    
    -- 布尔字面量
    if trimmed == "true" then
        return true
    elseif trimmed == "false" then
        return false
    elseif trimmed == "nil" or trimmed == "null" then
        return nil
    end
    
    -- 其他情况视为变量名或原始字符串
    return trimmed
end

--- 智能解析参数（支持嵌套模板变量）
--- 
---@param args_str string 参数字符串
---@return any parsed_arg 解析后的参数值
function M.parse_smart_arg(args_str)
    if not args_str or args_str == "" then
        return ""
    end
    
    -- 检查是否为嵌套模板变量格式
    if args_str:sub(1, 2) == constants.SYNTAX.VARIABLE_START and 
       args_str:sub(-1) == constants.SYNTAX.VARIABLE_END then
        -- 验证是否是有效的模板变量格式
        local content = args_str:sub(3, -2)  -- 移除 ${ 和 }
        if content and content ~= "" then
            return {type = "nested_template", content = args_str}
        end
    end
    
    -- 其他情况使用原有解析逻辑
    return M.parse_single_arg(args_str)
end

--============================================================================
-- 变量替换 - 处理模板中的变量和表达式
--============================================================================

--- 替换模板中的变量
--- 
--- 处理 ${variable} 语法，支持：
--- 1. 简单变量：${name}
--- 2. 嵌套属性：${user.profile.name}
--- 3. 过滤器链：${name|upper|format('Hello %s')}
--- 4. 嵌套模板：${var|filter:${nested_var}}
--- 
---@param template string 模板字符串
---@param env table 环境变量表
---@return string result 替换后的字符串
function M.replace_variables(template, env)
    if type(template) ~= "string" then
        return tostring(template or "")
    end
    
    if not template:find(constants.SYNTAX.VARIABLE_START, 1, true) then
        return template
    end
    
    -- 预处理嵌套模板语法
    -- 处理形如 ${outer[${inner}]} 的嵌套语法
    local function preprocess_nested_templates(text)
        local result = text
        local max_iterations = 10 -- 防止无限循环
        local iteration = 0
        
        while iteration < max_iterations do
            iteration = iteration + 1
            local changed = false
            
            -- 查找嵌套模板模式：${...${...}...}
            -- 只处理真正包含嵌套的模板，不处理独立的简单模板
            local nested_start = result:find("${[^{}]*${[^{}]*}[^{}]*}")
            if nested_start then
                -- 找到嵌套模板，查找最内层的简单变量
                local innermost_start, innermost_end = result:find("${[^{}]*}", nested_start)
                if innermost_start then
                    local inner_template = result:sub(innermost_start, innermost_end)
                    local inner_content = inner_template:sub(3, -2) -- 去掉 ${ 和 }
                    
                    -- 只处理简单变量（不包含 | 和 [ ）
                    if not inner_content:find("[|%[]") then
                        local inner_value = utils.get_nested_value(env, inner_content)
                        if inner_value then
                            local replacement = tostring(inner_value)
                            result = result:sub(1, innermost_start - 1) .. replacement .. result:sub(innermost_end + 1)
                            changed = true
                        end
                    end
                end
            end
            
            if not changed then
                break
            end
        end
        
        return result
    end
    
    -- 应用嵌套模板预处理
    template = preprocess_nested_templates(template)
    
    -- 智能提取 ${...} 内容，支持嵌套括号
    local function extract_template_content(text, start_pos)
        local var_start = constants.SYNTAX.VARIABLE_START
        if text:sub(start_pos, start_pos + #var_start - 1) ~= var_start then
            return nil, start_pos
        end
        
        local pos = start_pos + #constants.SYNTAX.VARIABLE_START
        local brace_count = 1
        local content_start = pos
        
        while pos <= #text and brace_count > 0 do
            local char = text:sub(pos, pos)
            if char == "{" then
                brace_count = brace_count + 1
            elseif char == "}" then
                brace_count = brace_count - 1
            end
            pos = pos + 1
        end
        
        if brace_count == 0 then
            local content = text:sub(content_start, pos - 2)  -- 不包含最后的 }
            return content, pos
        else
            -- 未找到匹配的右括号
            return nil, start_pos + #constants.SYNTAX.VARIABLE_START
        end
    end
    
    local result = template
    local pos = 1
    
    while pos <= #result do
        local dollar_pos = result:find(constants.SYNTAX.VARIABLE_START, pos, true)
        if not dollar_pos then
            break
        end
        
        local content, next_pos = extract_template_content(result, dollar_pos)
        if content then
            local key, filters = M.parse_filters(content)
            
            -- 获取变量值
            local value = get_variable_value(key, env)
            
            -- 应用过滤器链
            for _, filter in ipairs(filters) do
                value = M.apply_filter(value, filter, env)
            end
            
            -- 替换模板内容
            local full_template = constants.SYNTAX.VARIABLE_START .. content .. constants.SYNTAX.VARIABLE_END
            
            -- 智能字符串化
            local replacement
            if value == nil then
                replacement = ""
            elseif type(value) == "table" then
                -- 对于table类型，提供更有用的表示
                -- 如果table有name字段，优先显示
                if value.name then
                    replacement = tostring(value.name)
                elseif #value > 0 then
                    -- 如果是数组，显示数组内容概要
                    if #value <= 3 then
                        local items = {}
                        for i = 1, #value do
                            table.insert(items, tostring(value[i]))
                        end
                        replacement = "[" .. table.concat(items, ",") .. "]"
                    else
                        replacement = "[" .. tostring(value[1]) .. ",...(" .. #value .. " items)]"
                    end
                else
                    -- 否则显示JSON格式（简化版）
                    local json_parts = {}
                    for k, v in pairs(value) do
                        if type(k) == "string" and type(v) ~= "table" and type(v) ~= "function" then
                            table.insert(json_parts, k .. ":" .. tostring(v))
                        end
                    end
                    if #json_parts > 0 then
                        replacement = "{" .. table.concat(json_parts, ",") .. "}"
                    else
                        replacement = "{object}"
                    end
                end
            else
                replacement = tostring(value)
            end
            
            -- 使用简单的字符串替换，避免模式匹配问题
            local before = result:sub(1, dollar_pos - 1)
            local after = result:sub(dollar_pos + #full_template)
            result = before .. replacement .. after
            
            -- 更新位置
            pos = dollar_pos + #replacement
        else
            pos = next_pos
        end
    end
    
    return result
end

--============================================================================
-- 过滤器应用
--============================================================================

--- 应用过滤器
---@param value any 要过滤的值
---@param filter table 过滤器信息
---@param env table 环境变量表 (用于嵌套模板)
---@return any result 过滤器处理后的值
function M.apply_filter(value, filter, env)
    local filter_func = get_filter_function(filter.name)
    if filter_func then
        -- 处理嵌套模板参数
        local processed_args = {}
        for i, arg in ipairs(filter.args) do
            processed_args[i] = M.process_nested_template_arg(arg, env)
        end
        
        return filter_func(value, table.unpack(processed_args))
    else
        -- 过滤器不存在，返回原值
        return value
    end
end

--- 处理嵌套模板参数
--- 
--- 只处理无引号的嵌套模板语法 ${variable}
--- 
---@param arg any 原始参数
---@param env table 环境变量表
---@return any processed_arg 处理后的参数
function M.process_nested_template_arg(arg, env)
    -- 处理无引号的嵌套模板对象
    if type(arg) == "table" and arg.type == "nested_template" then
        if env then
            return M.replace_variables(arg.content, env)
        end
        return arg.content
    end
    
    -- 其他情况直接返回原参数
    return arg
end

--============================================================================
-- 宏和函数调用
--============================================================================

--- 处理宏调用
--- 
---@param macro_name string 宏名称
---@param args_str string 参数字符串
---@param env table 环境变量表
---@return string result 宏执行结果
function M.process_macro_call(macro_name, args_str, env)
    -- 解析宏参数
    local args = {}
    if args_str and args_str ~= "" then
        for arg in args_str:gmatch("[^,]+") do
            local trimmed_arg = utils.trim(arg)
            
            -- 尝试作为表达式求值
            local value, eval_error = utils.safe_eval(trimmed_arg, env)
            if not eval_error then
                table.insert(args, value)
            else
                -- 求值失败，当作字面量
                table.insert(args, M.parse_single_arg(trimmed_arg))
            end
        end
    end
    
    -- 调用宏
    local handlers = require 'wl.tools.strp.handlers'
    local success, result = pcall(handlers.call_macro, macro_name, args, env)
    
    if success then
        return result or ""
    else
        -- 宏调用失败，返回原始内容
        return constants.SYNTAX.VARIABLE_START .. macro_name .. "(" .. (args_str or "") .. ")" .. constants.SYNTAX.VARIABLE_END
    end
end

--============================================================================
-- 缓存管理
--============================================================================

--- 清空解析缓存
function M.clear_cache()
    parse_cache = {}
    filter_cache = {}
end

--- 获取缓存统计信息
---@return table stats 缓存统计
function M.get_cache_stats()
    local parse_count = 0
    local filter_count = 0
    
    for _ in pairs(parse_cache) do
        parse_count = parse_count + 1
    end
    
    for _ in pairs(filter_cache) do
        filter_count = filter_count + 1
    end
    
    return {
        parse_cache_size = parse_count,
        filter_cache_size = filter_count,
        total_cache_size = parse_count + filter_count
    }
end

return M
