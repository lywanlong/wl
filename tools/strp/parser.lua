--============================================================================
-- STRP 模板引擎 - 解析器模块 v3.2 (修复无限循环问题)
-- 
-- 负责模板语法的解析和处理：
-- • 块结构解析：查找匹配的开始/结束标记
-- • 过滤器链解析：处理复杂的过滤器语法
-- • 变量替换：处理 ${variable} 语法
-- • 嵌套模板：支持 ${var|filter:${nested_var}} 语法 ✨新功能
-- • 参数解析：处理函数参数和过滤器参数
-- 
-- 核心算法：
-- • 递归下降解析：处理嵌套结构
-- • 智能括号匹配：支持任意深度的嵌套
-- • 惰性求值：提升性能
-- • 缓存优化：复用编译结果
--
-- v3.2 修复：
-- • 修复无限递归问题
-- • 优化嵌套变量处理逻辑
-- • 增强错误检测和防护
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
-- 智能字符串化辅助函数
--============================================================================

--- 智能字符串化
---@param value any 要转换的值
---@return string result 字符串结果
local function smart_stringify(value)
    if value == nil then
        return ""
    elseif type(value) == "table" then
        -- 对于table类型，提供更有用的表示
        if value.name then
            return tostring(value.name)
        elseif #value > 0 then
            -- 如果是数组，显示数组内容概要
            if #value <= 3 then
                local items = {}
                for i = 1, #value do
                    table.insert(items, tostring(value[i]))
                end
                return "[" .. table.concat(items, ",") .. "]"
            else
                return "[" .. tostring(value[1]) .. ",...(" .. #value .. " items)]"
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
                return "{" .. table.concat(json_parts, ",") .. "}"
            else
                return "{object}"
            end
        end
    else
        return tostring(value)
    end
end

--============================================================================
-- 块结构解析 - 处理嵌套的控制结构
--============================================================================

--- 查找匹配的块结束位置
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
-- 🌟 修复版 - 变量替换核心功能
--============================================================================

--- 替换模板中的变量（修复无限循环版本）
---@param template string 模板字符串
---@param env table 环境变量表
---@param max_depth? integer 最大递归深度，防止无限循环
---@return string result 替换后的字符串
function M.replace_variables(template, env, max_depth)
    if type(template) ~= "string" then
        return tostring(template or "")
    end
    
    max_depth = max_depth or constants.PERFORMANCE.MAX_RECURSION_DEPTH
    if max_depth <= 0 then
        error("模板嵌套深度超出限制")
    end
    
    -- 如果没有变量标记，直接返回
    if not template:find(constants.SYNTAX.VARIABLE_START, 1, true) then
        return template
    end
    
    -- 📌 关键修复：使用单次传递而不是多次迭代
    return M.process_template_single_pass(template, env, max_depth)
end

--- 单次传递处理模板变量（修复版）
---@param template string 模板字符串
---@param env table 环境变量表
---@param max_depth integer 剩余递归深度
---@return string result 处理后的字符串
function M.process_template_single_pass(template, env, max_depth)
    local result = ""
    local pos = 1
    local template_len = #template
    
    while pos <= template_len do
        -- 查找下一个变量开始标记
        local var_start = template:find(constants.SYNTAX.VARIABLE_START, pos, true)
        
        if not var_start then
            -- 没有更多变量，添加剩余部分
            result = result .. template:sub(pos)
            break
        end
        
        -- 添加变量前的内容
        if var_start > pos then
            result = result .. template:sub(pos, var_start - 1)
        end
        
        -- 提取完整的变量表达式
        local var_content, var_end = M.extract_balanced_variable(template, var_start)

        if var_content then
            -- 📌 关键修复：直接处理变量表达式，不再重新包装
            local processed_value = M.process_variable_expression_fixed(var_content, env, max_depth)
            result = result .. processed_value
            pos = var_end + 1
        else
            -- 变量表达式不完整，保持原样
            result = result .. constants.SYNTAX.VARIABLE_START
            pos = var_start + #constants.SYNTAX.VARIABLE_START
        end
    end
    
    return result
end

--- 提取平衡的变量表达式（处理嵌套括号）
function M.extract_balanced_variable(template, start_pos)
    local var_start_len = #constants.SYNTAX.VARIABLE_START
    local var_end_char = constants.SYNTAX.VARIABLE_END
    
    -- 检查开始标记
    if template:sub(start_pos, start_pos + var_start_len - 1) ~= constants.SYNTAX.VARIABLE_START then
        return nil, start_pos
    end
    
    local pos = start_pos + var_start_len
    local brace_count = 1
    local content_start = pos
    
    while pos <= #template and brace_count > 0 do
        local char = template:sub(pos, pos)
        
        if char == "{" then
            brace_count = brace_count + 1
        elseif char == "}" then
            brace_count = brace_count - 1
        end
        
        pos = pos + 1
    end
    
    if brace_count == 0 then
        local content = template:sub(content_start, pos - 2)  -- 不包含最后的 }
        return content, pos - 1
    else
        -- 未找到匹配的右括号
        return nil, start_pos + var_start_len
    end
end

--- 📌 修复版：处理单个变量表达式
---@param expression string 变量表达式内容
---@param env table 环境变量表
---@param max_depth integer 剩余递归深度
---@return string result 处理结果
function M.process_variable_expression_fixed(expression, env, max_depth)
    if not expression or expression == "" then
        return ""
    end
    
    -- 📌 关键修复：先解析过滤器，再递归处理嵌套变量
    local key, filters = M.parse_filters_enhanced(expression, env, max_depth)
    
    -- 获取变量值
    local value = get_variable_value(key, env)
    
    -- 应用过滤器链
    for _, filter in ipairs(filters) do
        value = M.apply_filter_enhanced(value, filter, env, max_depth)
    end
    
    -- 智能字符串化
    return smart_stringify(value)
end

--============================================================================
-- 🌟 修复版 - 过滤器解析增强版
--============================================================================

--- 解析过滤器链（修复版：支持嵌套模板参数）
---@param text string 要解析的文本
---@param env table 环境变量表
---@param max_depth integer 剩余递归深度
---@return string key 变量名
---@return table filters 过滤器列表
function M.parse_filters_enhanced(text, env, max_depth)
    if type(text) ~= "string" or text == "" then
        return "", {}
    end
    
    -- 智能分割过滤器链（考虑嵌套的${}）
    local parts = M.split_filters_smart(text)
    
    if #parts == 0 then
        return "", {}
    end
    
    local key = utils.trim(parts[1])  -- 第一部分是变量名
    
    -- 📌 关键修复：如果key包含嵌套变量，先递归处理
    if key:find(constants.SYNTAX.VARIABLE_START, 1, true) and max_depth > 0 then
        key = M.replace_variables(key, env, max_depth - 1)
    end
    
    local filters = {}
    
    -- 解析每个过滤器（从第二部分开始）
    for i = 2, #parts do
        local filter_part = utils.trim(parts[i])
        local filter_info = M.parse_single_filter_enhanced(filter_part, env, max_depth)
        
        if filter_info then
            table.insert(filters, filter_info)
        end
    end
    
    return key, filters
end

--- 智能分割过滤器链（处理嵌套的${}）
function M.split_filters_smart(text)
    local parts = {}
    local current_part = ""
    local brace_count = 0
    local i = 1
    
    while i <= #text do
        local char = text:sub(i, i)
        local next_char = text:sub(i + 1, i + 1)
        
        if char == "$" and next_char == "{" then
            -- 进入嵌套变量
            brace_count = brace_count + 1
            current_part = current_part .. char .. next_char
            i = i + 2
        elseif char == "}" and brace_count > 0 then
            -- 退出嵌套变量
            brace_count = brace_count - 1
            current_part = current_part .. char
            i = i + 1
        elseif char == "|" and brace_count == 0 then
            -- 只在不在嵌套变量内时才作为过滤器分隔符
            table.insert(parts, current_part)
            current_part = ""
            i = i + 1
        else
            current_part = current_part .. char
            i = i + 1
        end
    end
    
    -- 添加最后一部分
    if current_part ~= "" then
        table.insert(parts, current_part)
    end
    
    return parts
end

--- 解析单个过滤器（修复版：支持嵌套模板参数）
function M.parse_single_filter_enhanced(filter_text, env, max_depth)
    if type(filter_text) ~= "string" or filter_text == "" then
        return nil
    end
    
    -- 尝试解析括号语法：filter(arg1, arg2, ...)
    local name, args_str = M.extract_function_call(filter_text)
    if name then
        local args = {}
        if args_str and args_str ~= "" then
            args = M.parse_function_args_enhanced(args_str, env, max_depth)
        end
        return {name = name, args = args}
    end
    
    -- 尝试解析冒号语法：filter:arg
    name, args_str = M.extract_colon_syntax(filter_text)
    if name and args_str then
        local arg = M.parse_smart_arg_enhanced(args_str, env, max_depth)
        return {name = name, args = {arg}}
    end
    
    -- 解析无参数过滤器：filter
    name = filter_text:match("^([%w_]+)%s*$")
    if name then
        return {name = name, args = {}}
    end
    
    return nil
end

--- 提取函数调用语法
function M.extract_function_call(text)
    -- 查找函数名和括号
    local name_end = text:find("%(")
    if not name_end then
        return nil, nil
    end
    
    local name = utils.trim(text:sub(1, name_end - 1))
    
    -- 查找匹配的右括号
    local paren_count = 0
    local args_start = name_end + 1
    local i = name_end
    
    while i <= #text do
        local char = text:sub(i, i)
        if char == "(" then
            paren_count = paren_count + 1
        elseif char == ")" then
            paren_count = paren_count - 1
            if paren_count == 0 then
                local args_str = text:sub(args_start, i - 1)
                return name, args_str
            end
        end
        i = i + 1
    end
    
    return nil, nil
end

--- 提取冒号语法
function M.extract_colon_syntax(text)
    -- 查找不在嵌套变量内的冒号
    local brace_count = 0
    local i = 1
    
    while i <= #text do
        local char = text:sub(i, i)
        local next_char = text:sub(i + 1, i + 1)
        
        if char == "$" and next_char == "{" then
            brace_count = brace_count + 1
            i = i + 2
        elseif char == "}" and brace_count > 0 then
            brace_count = brace_count - 1
            i = i + 1
        elseif char == ":" and brace_count == 0 then
            -- 找到顶层的冒号
            local name = utils.trim(text:sub(1, i - 1))
            local args = utils.trim(text:sub(i + 1))
            return name, args
        else
            i = i + 1
        end
    end
    
    return nil, nil
end

--- 解析函数参数列表（修复版：支持嵌套模板）
function M.parse_function_args_enhanced(args_str, env, max_depth)
    if type(args_str) ~= "string" or args_str == "" then
        return {}
    end
    
    local args = {}
    local parts = M.split_args_smart(args_str)
    
    for _, part in ipairs(parts) do
        local trimmed = utils.trim(part)
        if trimmed ~= "" then
            local arg = M.parse_smart_arg_enhanced(trimmed, env, max_depth)
            table.insert(args, arg)
        end
    end
    
    return args
end

--- 智能分割参数（处理嵌套的${}和引号）
function M.split_args_smart(args_str)
    local parts = {}
    local current_part = ""
    local brace_count = 0
    local in_quote = false
    local quote_char = nil
    local i = 1
    
    while i <= #args_str do
        local char = args_str:sub(i, i)
        local next_char = args_str:sub(i + 1, i + 1)
        
        if not in_quote then
            if char == "'" or char == '"' then
                -- 进入引号
                in_quote = true
                quote_char = char
                current_part = current_part .. char
            elseif char == "$" and next_char == "{" then
                -- 进入嵌套变量
                brace_count = brace_count + 1
                current_part = current_part .. char .. next_char
                i = i + 1  -- 跳过下一个字符
            elseif char == "}" and brace_count > 0 then
                -- 退出嵌套变量
                brace_count = brace_count - 1
                current_part = current_part .. char
            elseif char == "," and brace_count == 0 then
                -- 只在不在嵌套变量内时才作为参数分隔符
                table.insert(parts, current_part)
                current_part = ""
            else
                current_part = current_part .. char
            end
        else
            -- 在引号内
            current_part = current_part .. char
            if char == quote_char then
                -- 退出引号
                in_quote = false
                quote_char = nil
            end
        end
        
        i = i + 1
    end
    
    -- 添加最后一部分
    if current_part ~= "" then
        table.insert(parts, current_part)
    end
    
    return parts
end

--- 📌 修复版：智能解析参数（支持嵌套模板变量）
---@param args_str string 参数字符串
---@param env table 环境变量表
---@param max_depth integer 剩余递归深度
---@return any parsed_arg 解析后的参数值
function M.parse_smart_arg_enhanced(args_str, env, max_depth)
    if not args_str or args_str == "" then
        return ""
    end
    
    local trimmed = utils.trim(args_str)
    
    -- 📌 关键修复：检查是否包含嵌套模板变量，直接递归处理
    if trimmed:find(constants.SYNTAX.VARIABLE_START, 1, true) then
        -- 递归处理嵌套模板（不再重新包装）
        if max_depth > 0 then
            return M.replace_variables(trimmed, env, max_depth - 1)
        else
            return trimmed  -- 达到最大深度，返回原始字符串
        end
    end
    
    -- 其他情况使用原有解析逻辑
    return M.parse_single_arg(trimmed)
end

--- 解析单个参数
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

--============================================================================
-- 🌟 修复版 - 过滤器应用增强版
--============================================================================

--- 应用过滤器（修复版：支持嵌套模板参数）
function M.apply_filter_enhanced(value, filter, env, max_depth)
    local filter_func = get_filter_function(filter.name)
    if filter_func then
        -- 处理参数（支持嵌套模板）
        local processed_args = {}
        for i, arg in ipairs(filter.args) do
            processed_args[i] = M.process_filter_arg_enhanced(arg, env, max_depth)
        end
        
        return filter_func(value, table.unpack(processed_args))
    else
        -- 过滤器不存在，返回原值
        return value
    end
end

--- 📌 修复版：处理过滤器参数
function M.process_filter_arg_enhanced(arg, env, max_depth)
    -- 如果参数是字符串且包含模板变量，则进行递归处理
    if type(arg) == "string" and max_depth > 0 and arg:find(constants.SYNTAX.VARIABLE_START, 1, true) then
        return M.replace_variables(arg, env, max_depth - 1)
    end
    
    return arg
end

--============================================================================
-- 向后兼容的函数接口
--============================================================================

--- 兼容旧版API：解析过滤器链
function M.parse_filters(text, env, max_depth)
    -- 如果没有提供环境或深度参数，使用默认值
    env = env or {}
    max_depth = max_depth or constants.PERFORMANCE.MAX_RECURSION_DEPTH
    return M.parse_filters_enhanced(text, env, max_depth)
end

--- 兼容旧版API：解析单个过滤器
function M.parse_single_filter(filter_text, env, max_depth)
    env = env or {}
    max_depth = max_depth or constants.PERFORMANCE.MAX_RECURSION_DEPTH
    return M.parse_single_filter_enhanced(filter_text, env, max_depth)
end

--- 兼容旧版API：解析函数参数
function M.parse_function_args(args_str, env, max_depth)
    env = env or {}
    max_depth = max_depth or constants.PERFORMANCE.MAX_RECURSION_DEPTH
    return M.parse_function_args_enhanced(args_str, env, max_depth)
end

--- 兼容旧版API：智能解析参数
function M.parse_smart_arg(args_str, env, max_depth)
    env = env or {}
    max_depth = max_depth or constants.PERFORMANCE.MAX_RECURSION_DEPTH
    return M.parse_smart_arg_enhanced(args_str, env, max_depth)
end

--- 兼容旧版API：应用过滤器
function M.apply_filter(value, filter, env, max_depth)
    env = env or {}
    max_depth = max_depth or constants.PERFORMANCE.MAX_RECURSION_DEPTH
    return M.apply_filter_enhanced(value, filter, env, max_depth)
end

--============================================================================
-- 其他原有功能保持不变
--============================================================================

--- 处理嵌套模板参数
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

--- 处理宏调用
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