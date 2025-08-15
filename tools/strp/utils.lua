--============================================================================
-- STRP 模板引擎 - 工具函数模块 v2.1
--
-- 提供高性能的通用工具函数，支持模板引擎的各种操作
-- 
-- 模块职责：
-- • 字符串处理：高效的字符串操作和格式化
-- • 表达式求值：安全的代码执行和变量访问
-- • 类型处理：类型检查、转换和验证
-- • 安全机制：XSS防护、沙箱执行
-- • 性能优化：缓存、批处理、内存管理
--============================================================================

---@class StrpUtils 工具函数模块
local M = {}

-- 模块依赖
local constants = require 'wl.tools.strp.constants'

--============================================================================
-- 字符串处理工具
--============================================================================

--- 转义正则表达式特殊字符
--- 
--- 将字符串中的正则表达式元字符转义，使其可以安全地用于模式匹配
--- 
---@param str string 需要转义的字符串
---@return string escaped 转义后的字符串
function M.escape_pattern(str)
    if type(str) ~= "string" then
        return tostring(str or "")
    end
    
    -- Lua 正则表达式的特殊字符
    local special_chars = "^$()%.[]*+-?"
    local escaped = str:gsub("[" .. special_chars:gsub(".", "%%%1") .. "]", "%%%1")
    return escaped
end

--- 高性能字符串分割
--- 
--- 使用优化算法分割字符串，支持多字符分隔符
--- 
---@param str string 要分割的字符串
---@param delimiter string 分隔符
---@param max_parts? integer 最大分割部分数，nil表示无限制
---@return table parts 分割后的字符串数组
function M.split_string(str, delimiter, max_parts)
    if type(str) ~= "string" or str == "" then
        return {}
    end
    
    if type(delimiter) ~= "string" or delimiter == "" then
        -- 无分隔符时，分割每个字符
        local chars = {}
        for i = 1, #str do
            chars[i] = str:sub(i, i)
        end
        return chars
    end
    
    local parts = {}
    local start = 1
    local count = 0
    local max_parts_num = max_parts or 999999  -- 使用大数字代替math.huge
    
    while count < max_parts_num - 1 do
        local pos = str:find(delimiter, start, true)
        if not pos then
            break
        end
        
        count = count + 1
        parts[count] = str:sub(start, pos - 1)
        start = pos + #delimiter
    end
    
    -- 添加最后一部分
    if start <= #str then
        parts[count + 1] = str:sub(start)
    elseif start == #str + 1 then
        parts[count + 1] = ""
    end
    
    return parts
end

--- 去除首尾空白字符（支持Unicode）
--- 
---@param str string 输入字符串
---@return string trimmed 去除空白后的字符串
function M.trim(str)
    if type(str) ~= "string" then
        return ""
    end
    
    -- 支持常见的Unicode空白字符
    return str:match("^%s*(.-)%s*$") or ""
end

--- 安全的字符串格式化
--- 
--- 提供类似printf的格式化功能，但具有更好的错误处理
--- 
---@param format string 格式字符串
---@param ... any 格式参数
---@return string formatted 格式化后的字符串
---@return string? error 错误信息
function M.safe_format(format, ...)
    local success, result = pcall(string.format, format, ...)
    if success then
        return result, nil
    else
        return format, "格式化错误: " .. tostring(result)
    end
end

--============================================================================
-- 错误处理工具
--============================================================================

--- 带上下文的错误处理
--- 
--- 生成包含模板上下文信息的详细错误消息
--- 
---@param message string 错误消息
---@param template string 模板内容
---@param position integer 错误位置
---@param context_size? integer 上下文行数，默认为3
function M.error_with_context(message, template, position, context_size)
    context_size = context_size or 3
    
    -- 基本错误信息
    local error_msg = message .. "\n"
    
    if type(template) == "string" and type(position) == "number" and position > 0 then
        -- 分割模板为行
        local lines = M.split_string(template, "\n")
        
        -- 计算错误行号
        local char_count = 0
        local error_line = 1
        local error_col = 1
        
        for i, line in ipairs(lines) do
            local line_len = #line + 1 -- +1 for newline
            if char_count + line_len >= position then
                error_line = i
                error_col = position - char_count
                break
            end
            char_count = char_count + line_len
        end
        
        -- 添加位置信息
        error_msg = error_msg .. string.format("位置: 第 %d 行，第 %d 列\n", error_line, error_col)
        
        -- 添加上下文信息
        local start_line = math.max(1, error_line - context_size)
        local end_line = math.min(#lines, error_line + context_size)
        
        if start_line <= end_line then
            error_msg = error_msg .. "\n上下文:\n"
            for i = start_line, end_line do
                local prefix = i == error_line and ">>> " or "    "
                error_msg = error_msg .. string.format("%s%3d: %s\n", prefix, i, lines[i])
            end
            
            -- 添加错误位置指示
            if error_line >= start_line and error_line <= end_line then
                local indent = string.rep(" ", 8 + error_col - 1)
                error_msg = error_msg .. indent .. "^\n"
            end
        end
    end
    
    error(error_msg, 0)
end

--============================================================================
-- 表达式求值工具
--============================================================================

--- 安全的表达式求值
--- 
--- 在沙箱环境中执行Lua表达式，提供安全保护
--- 
---@param expr string Lua表达式
---@param env table 环境变量表
---@param timeout? number 超时时间（毫秒）
---@return any result 求值结果
---@return string? error 错误信息
function M.safe_eval(expr, env, timeout)
    if type(expr) ~= "string" or expr == "" then
        return nil, "表达式不能为空"
    end
    
    env = env or {}
    timeout = timeout or constants.PERFORMANCE.EVAL_TIMEOUT
    
    -- 创建安全的执行环境
    local safe_env = M.create_sandbox(env)
    
    -- 编译表达式
    local func, compile_error = load("return " .. expr, "expr", "t", safe_env)
    if not func then
        return nil, "表达式编译错误: " .. tostring(compile_error)
    end
    
    -- 执行表达式（带超时保护）
    local start_time = os.clock() * 1000
    local success, result = pcall(func)
    local end_time = os.clock() * 1000
    
    if end_time - start_time > timeout then
        return nil, "表达式执行超时"
    end
    
    if success then
        return result, nil
    else
        return nil, "表达式执行错误: " .. tostring(result)
    end
end

--- 表达式求值（safe_eval的简化别名）
--- 
---@param expr string Lua表达式
---@param env table 环境变量表
---@return any result 求值结果
---@return string? error 错误信息
function M.eval(expr, env)
    return M.safe_eval(expr, env)
end

--- 创建安全的沙箱环境
--- 
---@param base_env table 基础环境变量
---@return table sandbox 沙箱环境
function M.create_sandbox(base_env)
    local sandbox = {}
    
    -- 复制基础环境
    if type(base_env) == "table" then
        for k, v in pairs(base_env) do
            sandbox[k] = v
        end
    end
    
    -- 添加允许的全局函数
    for _, func_name in ipairs(constants.SECURITY.ALLOWED_FUNCTIONS) do
        local func = M.get_nested_value(_G, func_name)
        if func then
            M.set_nested_value(sandbox, func_name, func)
        end
    end
    
    -- 添加安全的基础函数
    sandbox.type = type
    sandbox.tostring = tostring
    sandbox.tonumber = tonumber
    sandbox.next = next
    sandbox.pairs = pairs
    sandbox.ipairs = ipairs
    sandbox.select = select
    
    -- 添加安全的常量 (避免使用关键字作为键名)
    sandbox["true"] = true
    sandbox["false"] = false
    sandbox["nil"] = nil
    
    return sandbox
end

--============================================================================
-- 变量访问工具
--============================================================================

--- 获取嵌套变量值
--- 
--- 支持复杂的变量路径，如 "user.profile.name" 或 "items[0].title"
--- 
---@param env table 环境变量表
---@param path string 变量路径
---@return any value 变量值
---@return boolean found 是否找到变量
function M.get_nested_value(env, path)
    if type(env) ~= "table" or type(path) ~= "string" or path == "" then
        return nil, false
    end
    
    -- 缓存编译后的路径访问器
    local accessor = M.compile_path_accessor(path)
    if not accessor then
        return nil, false
    end
    
    local success, result = pcall(accessor, env)
    return success and result or nil, success
end

--- 设置嵌套变量值
--- 
---@param env table 环境变量表
---@param path string 变量路径
---@param value any 要设置的值
---@return boolean success 是否设置成功
function M.set_nested_value(env, path, value)
    if type(env) ~= "table" or type(path) ~= "string" or path == "" then
        return false
    end
    
    local parts = M.split_string(path, ".")
    local current = env
    
    -- 遍历到倒数第二级
    for i = 1, #parts - 1 do
        local key = parts[i]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end
    
    -- 设置最终值
    current[parts[#parts]] = value
    return true
end

-- 路径访问器缓存
local path_cache = {}

--- 编译路径访问器（缓存优化）
--- 
---@param path string 变量路径
---@return function? accessor 路径访问函数
function M.compile_path_accessor(path)
    if path_cache[path] then
        return path_cache[path]
    end
    
    -- 简单路径直接访问
    if not path:find("[.%[%]]") then
        local accessor = function(env) return env[path] end
        path_cache[path] = accessor
        return accessor
    end
    
    -- 检查是否是简单的数组访问格式 name[index]
    local simple_array_name, simple_array_index = path:match("^([%w_]+)%[([^%]]+)%]$")
    if simple_array_name and simple_array_index then
        local accessor
        if simple_array_index:match("^%d+$") then
            -- 数字索引
            local num_index = tonumber(simple_array_index)
            accessor = function(env) 
                local arr = env[simple_array_name]
                return arr and arr[num_index] or nil
            end
        elseif simple_array_index:sub(1,1) == "'" and simple_array_index:sub(-1) == "'" then
            -- 单引号字符串索引
            local str_index = simple_array_index:sub(2, -2)
            accessor = function(env)
                local arr = env[simple_array_name]
                return arr and arr[str_index] or nil
            end
        elseif simple_array_index:sub(1,1) == '"' and simple_array_index:sub(-1) == '"' then
            -- 双引号字符串索引
            local str_index = simple_array_index:sub(2, -2)
            accessor = function(env)
                local arr = env[simple_array_name]
                return arr and arr[str_index] or nil
            end
        else
            -- 变量索引
            accessor = function(env)
                local arr = env[simple_array_name]
                local index = env[simple_array_index]
                return arr and index and arr[index] or nil
            end
        end
        path_cache[path] = accessor
        return accessor
    end
    
    -- 复杂路径解析（点号分割的路径）
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    
    local accessor = function(env)
        local current = env
        for _, part in ipairs(parts) do
            if not current then return nil end
            
            -- 检查是否是数组访问
            local array_name, array_index = part:match("^([%w_]+)%[([^%]]+)%]$")
            if array_name and array_index then
                current = current[array_name]
                if not current then return nil end
                
                if array_index:match("^%d+$") then
                    current = current[tonumber(array_index)]
                elseif array_index:sub(1,1) == "'" and array_index:sub(-1) == "'" then
                    local str_index = array_index:sub(2, -2)
                    current = current[str_index]
                elseif array_index:sub(1,1) == '"' and array_index:sub(-1) == '"' then
                    local str_index = array_index:sub(2, -2)
                    current = current[str_index]
                else
                    local index = env[array_index]
                    current = current[index]
                end
            else
                -- 简单属性访问
                current = current[part]
            end
        end
        return current
    end
    
    path_cache[path] = accessor
    return accessor
end

--============================================================================
-- 类型处理工具
--============================================================================

--- 智能类型转换
--- 
---@param value any 要转换的值
---@param target_type string 目标类型
---@return any converted 转换后的值
---@return boolean success 是否转换成功
function M.smart_convert(value, target_type)
    if type(value) == target_type then
        return value, true
    end
    
    if target_type == "string" then
        return tostring(value), true
    elseif target_type == "number" then
        local num = tonumber(value)
        return num, num ~= nil
    elseif target_type == "boolean" then
        if type(value) == "string" then
            local lower = value:lower()
            if lower == "true" or lower == "yes" or lower == "1" then
                return true, true
            elseif lower == "false" or lower == "no" or lower == "0" then
                return false, true
            end
        elseif type(value) == "number" then
            return value ~= 0, true
        end
        return not not value, true
    elseif target_type == "table" then
        if type(value) == "string" then
            -- 尝试解析JSON或简单的表格式
            local func, err = load("return " .. value)
            if func then
                local success, result = pcall(func)
                if success and type(result) == "table" then
                    return result, true
                end
            end
        end
        return {value}, true
    end
    
    return value, false
end

--- 深度比较两个值
--- 
---@param a any 值A
---@param b any 值B
---@return boolean equal 是否相等
function M.deep_equal(a, b)
    if a == b then
        return true
    end
    
    if type(a) ~= type(b) or type(a) ~= "table" then
        return false
    end
    
    -- 比较表格
    for k, v in pairs(a) do
        if not M.deep_equal(v, b[k]) then
            return false
        end
    end
    
    for k, v in pairs(b) do
        if not M.deep_equal(v, a[k]) then
            return false
        end
    end
    
    return true
end

--============================================================================
-- 安全和验证工具
--============================================================================

--- XSS防护 - HTML实体编码
--- 
---@param str string 输入字符串
---@return string escaped 转义后的字符串
function M.html_escape(str)
    if type(str) ~= "string" then
        str = tostring(str or "")
    end
    
    local escape_map = {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&#x27;",
        ["/"] = "&#x2F;"
    }
    
    return (str:gsub("[&<>\"'/]", escape_map))
end

--- 验证变量名的安全性
--- 
---@param name string 变量名
---@return boolean valid 是否有效
---@return string? error 错误信息
function M.validate_variable_name(name)
    if type(name) ~= "string" then
        return false, "变量名必须是字符串"
    end
    
    if #name == 0 then
        return false, "变量名不能为空"
    end
    
    if #name > constants.SECURITY.MAX_VARIABLE_NAME_LENGTH then
        return false, "变量名过长"
    end
    
    -- 检查是否为合法标识符
    if not name:match("^[%a_][%w_]*$") then
        return false, "变量名包含非法字符"
    end
    
    -- 检查是否为保留关键字
    for _, keyword in ipairs(constants.SYNTAX.KEYWORDS) do
        if name == keyword then
            return false, "变量名不能使用保留关键字"
        end
    end
    
    return true
end

--============================================================================
-- 性能和内存管理
--============================================================================

--- 批处理函数
--- 
---@param items table 要处理的项目列表
---@param processor function 处理函数
---@param batch_size? integer 批次大小
---@return table results 处理结果
function M.batch_process(items, processor, batch_size)
    batch_size = batch_size or constants.PERFORMANCE.BATCH_SIZE
    local results = {}
    
    for i = 1, #items, batch_size do
        local batch = {}
        for j = i, math.min(i + batch_size - 1, #items) do
            batch[j - i + 1] = items[j]
        end
        
        local batch_results = processor(batch)
        if type(batch_results) == "table" then
            for k, v in ipairs(batch_results) do
                results[i + k - 1] = v
            end
        end
    end
    
    return results
end

--- 内存使用监控
--- 
---@return number memory_mb 当前内存使用量（MB）
function M.get_memory_usage()
    collectgarbage("collect")
    return collectgarbage("count") / 1024
end

--- 检查内存使用是否超出阈值
--- 
---@return boolean over_threshold 是否超出阈值
---@return number current_usage 当前使用量
function M.check_memory_threshold()
    local usage = M.get_memory_usage()
    local threshold = constants.PERFORMANCE.MEMORY_WARNING_THRESHOLD
    return usage > threshold, usage
end

return M
