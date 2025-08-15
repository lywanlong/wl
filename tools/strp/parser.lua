--============================================================================
-- STRP 模板引擎 - 解析器模块
-- 
-- 负责模板语法的解析和处理：
-- • 块结构解析：查找匹配的开始/结束标记
-- • 过滤器链解析：处理复杂的过滤器语法
-- • 变量替换：处理 ${variable} 语法
-- • 参数解析：处理函数参数和过滤器参数
-- 
-- 核心算法：
-- • 递归下降解析：处理嵌套结构
-- • 有限状态机：解析复杂语法
-- • 惰性求值：提升性能
--============================================================================

-- 模块依赖
local constants = require 'wl.tools.strp.constants'
local utils = require 'wl.tools.strp.utils'
local filter_mod = require 'wl.tools.strp.filters'

---@class StrpParser 解析器模块
local M = {}

--============================================================================
-- 块结构解析 - 处理嵌套的控制结构
--============================================================================

--- 查找匹配的块结束位置
--- 
--- 使用栈式算法处理嵌套的控制结构，确保正确配对。
--- 支持任意深度的嵌套，如：if 中嵌套 for，for 中嵌套 switch 等。
--- 
--- 算法流程：
--- 1. 从起始位置开始扫描
--- 2. 遇到开始标记时深度+1
--- 3. 遇到结束标记时深度-1  
--- 4. 深度为0时找到匹配的结束位置
--- 
---@param template string 完整的模板字符串
---@param start_pos integer 搜索起始位置（通常是开始标记的结束位置）
---@return integer|nil end_start 结束标记的开始位置
---@return integer|nil end_finish 结束标记的结束位置
--- 
---@usage
--- local template = "{% if true %}{% for i in list %}...{% endfor %}{% endif %}"
--- local end_start, end_finish = parser.find_block_end(template, 12)
function M.find_block_end(template, start_pos)
    -- 参数验证
    if type(template) ~= "string" then
        return nil
    end
    if type(start_pos) ~= "number" or start_pos < 1 then
        return nil
    end
    
    local depth = 1  -- 嵌套深度计数器
    local pos = start_pos
    
    -- 扫描模板，查找匹配的结束标记
    while depth > 0 and pos <= #template do
        -- 查找下一个控制标记
        local tag_s, tag_e = template:find("{%%[^}]*%%}", pos)
        if not tag_s or not tag_e then 
            break  -- 没有更多标记，退出循环
        end
        
        -- 确保位置为整数（类型安全）
        tag_s = math.floor(tag_s)
        tag_e = math.floor(tag_e)
        
        -- 解析标记内容
        local content = template:sub(tag_s + 2, tag_e - 2):match("^%s*(.-)%s*$")
        local tag_name = content and content:match("^(%w+)") or ""
        
        -- 更新嵌套深度
        if constants.END_KEYWORDS[tag_name] then
            depth = depth - 1
            if depth == 0 then 
                return tag_s, tag_e  -- 找到匹配的结束标记
            end
        elseif constants.BLOCK_KEYWORDS[tag_name] then
            depth = depth + 1
        end
        
        pos = tag_e + 1
    end
    
    return nil  -- 未找到匹配的结束标记
end

--============================================================================
-- 过滤器解析 - 处理复杂的过滤器链
--============================================================================

--- 解析过滤器字符串
--- 
--- 支持多种过滤器语法：
--- 1. 简单过滤器：variable|filter
--- 2. 带参数过滤器：variable|filter:arg 或 variable|filter(arg1,arg2)
--- 3. 过滤器链：variable|filter1|filter2:arg|filter3(arg1,arg2)
--- 
--- 解析过程：
--- 1. 按 | 分割过滤器链
--- 2. 第一部分是变量名
--- 3. 后续部分是过滤器和参数
--- 
---@param text string 包含过滤器的文本，如 "name|upper|format('Hello %s')"
---@return string key 变量名部分
---@return table filters 过滤器列表，每个元素包含 name 和 args
--- 
---@usage
--- local key, filters = parser.parse_filters("user.name|upper|format('Hello %s')")
--- -- key = "user.name"
--- -- filters = {{name="upper", args={}}, {name="format", args={"Hello %s"}}}
function M.parse_filters(text)
    -- 参数验证
    if type(text) ~= "string" or text == "" then
        return "", {}
    end
    
    -- 按管道符分割过滤器链
    local parts = {}
    for part in text:gmatch("[^|]+") do
        local trimmed = part:match("^%s*(.-)%s*$")  -- 去除首尾空格
        if trimmed ~= "" then
            table.insert(parts, trimmed)
        end
    end
    
    if #parts == 0 then
        return "", {}
    end
    
    local key = parts[1]  -- 第一部分是变量名
    local filters = {}
    
    -- 解析每个过滤器（从第二部分开始）
    for i = 2, #parts do
        local filter_part = parts[i]
        local filter_info = M.parse_single_filter(filter_part)
        
        if filter_info then
            table.insert(filters, filter_info)
        end
    end
    
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
---@return table|nil filter_info 过滤器信息，格式: {name=string, args=table}
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
        local arg = M.parse_single_arg(args_str)
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
--- 
---@param args_str string 参数字符串，如 "'hello', 123, variable"
---@return table args 解析后的参数数组
function M.parse_function_args(args_str)
    local args = {}
    
    if not args_str or args_str == "" then
        return args
    end
    
    -- 简单的参数分割（不处理嵌套括号）
    for arg in args_str:gmatch("([^,]+)") do
        local trimmed_arg = arg:match("^%s*(.-)%s*$")
        local parsed_arg = M.parse_single_arg(trimmed_arg)
        table.insert(args, parsed_arg)
    end
    
    return args
end

--- 解析单个参数
--- 
---@param arg_str string 参数字符串
---@return any parsed_arg 解析后的参数值
function M.parse_single_arg(arg_str)
    if not arg_str or arg_str == "" then
        return ""
    end
    
    -- 字符串参数：去除引号
    if arg_str:match("^['\"].*['\"]$") then
        return arg_str:sub(2, -2)
    end
    
    -- 数字参数
    local num = tonumber(arg_str)
    if num then
        return num
    end
    
    -- 布尔参数
    if arg_str == "true" then
        return true
    elseif arg_str == "false" then
        return false
    elseif arg_str == "nil" then
        return nil
    end
    
    -- 其他情况当作字符串处理
    return arg_str
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
--- 4. 宏调用：${macro_name(arg1, arg2)}
--- 
--- 替换过程：
--- 1. 使用正则表达式查找 ${...} 模式
--- 2. 解析内容：区分宏调用、过滤器、普通变量
--- 3. 求值并应用过滤器
--- 4. 格式化输出结果
--- 
---@param template string 模板字符串
---@param env table 环境变量表，提供变量值
---@return string result 替换后的字符串
--- 
---@usage
--- local result = parser.replace_variables("Hello ${name|upper}!", {name = "world"})
--- -- result = "Hello WORLD!"
function M.replace_variables(template, env)
    -- 参数验证
    if type(template) ~= "string" then
        return ""
    end
    if type(env) ~= "table" then
        env = {}
    end
    
    -- 使用正则表达式查找并替换所有 ${...} 模式
    local result = template:gsub("%${([^}]+)}", function(content)
        return M.process_variable_content(content, env)
    end)
    
    return result
end

--- 处理单个变量内容
--- 
---@param content string 变量内容（去除 ${ } 包装）
---@param env table 环境变量表
---@return string result 处理后的结果
function M.process_variable_content(content, env)
    -- 去除首尾空格
    content = content:match("^%s*(.-)%s*$") or ""
    
    if content == "" then
        return ""
    end
    
    -- 检查是否是宏调用：macro_name(arg1, arg2, ...)
    local macro_name, args_str = content:match("^([%w_]+)%s*%((.*)%)%s*$")
    if macro_name then
        return M.process_macro_call(macro_name, args_str, env)
    end
    
    -- 解析变量名和过滤器链
    local key, filters = M.parse_filters(content)
    
    -- 获取变量值
    local value = utils.get_env_value(env, key)
    
    -- 应用过滤器链
    for _, filter in ipairs(filters) do
        value = M.apply_filter(value, filter)
    end
    
    -- 格式化输出
    return M.format_output(value, content)
end

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
            local trimmed_arg = arg:match("^%s*(.-)%s*$")
            
            -- 尝试作为表达式求值
            local value, eval_error = utils.eval(trimmed_arg, env)
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
        return "${" .. macro_name .. "(" .. (args_str or "") .. ")}"
    end
end

--- 应用单个过滤器
--- 
---@param value any 输入值
---@param filter table 过滤器信息 {name=string, args=table}
---@return any result 过滤器处理后的值
function M.apply_filter(value, filter)
    local filter_func = filter_mod.get_filter(filter.name)
    if filter_func then
        return filter_func(value, table.unpack(filter.args))
    else
        -- 过滤器不存在，返回原值
        return value
    end
end

--- 格式化输出值
--- 
--- 将过滤器处理后的值转换为字符串输出。
--- 对不同类型的值采用不同的格式化策略。
--- 
---@param value any 要格式化的值
---@param original_content string 原始内容（用于错误时的回退）
---@return string formatted 格式化后的字符串
function M.format_output(value, original_content)
    if value == nil then
        -- 值为 nil，返回原始内容
        return "${" .. original_content .. "}"
    elseif type(value) == "table" then
        -- 表类型：尝试转换为可读格式
        local success, result = pcall(function()
            if #value > 0 then
                -- 数组类型：用逗号分隔
                return "[" .. table.concat(value, ", ") .. "]"
            else
                -- 对象类型：显示类型信息
                return "[object Object]"
            end
        end)
        return success and result or "[object Object]"
    elseif type(value) == "boolean" then
        -- 布尔类型：转换为字符串
        return tostring(value)
    else
        -- 其他类型：直接转换为字符串
        return tostring(value)
    end
end

return M
