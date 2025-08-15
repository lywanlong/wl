--============================================================================
-- STRP 模板引擎 - 核心工具函数模块
-- 
-- 提供模板引擎运行时需要的核心工具函数：
-- • 安全的表达式求值
-- • 错误处理和上下文信息
-- • 嵌套对象属性访问
-- • 类型检查和验证
-- 
-- 设计原则：
-- • 安全第一：所有操作都有错误处理
-- • 性能优化：缓存常用操作结果
-- • 易于调试：提供丰富的错误信息
--============================================================================

---@class StrpUtils 工具函数模块
local M = {}

--============================================================================
-- 表达式求值 - 安全地执行用户提供的 Lua 代码
--============================================================================

--- 安全执行 Lua 表达式
--- 
--- 在受限环境中执行用户提供的表达式，避免安全风险。
--- 支持数学运算、逻辑判断、属性访问等常见操作。
--- 
--- @param expr string 要执行的 Lua 表达式
--- @param env table 提供给表达式的环境变量
--- @return any|nil result 执行结果，失败时返回 nil
--- @return string? error 错误信息，成功时返回 nil
--- 
--- @usage
--- local result, err = utils.eval("user.age > 18", {user = {age = 20}})
--- if err then
---     print("表达式错误:", err)
--- else
---     print("结果:", result)  -- 输出: true
--- end
function M.eval(expr, env)
    -- 参数验证
    if type(expr) ~= "string" then
        return nil, "表达式必须是字符串类型"
    end
    if type(env) ~= "table" then
        return nil, "环境变量必须是表类型"
    end
    
    -- 预处理表达式：检查是否包含危险操作
    if expr:match("os%.") or expr:match("io%.") or expr:match("require") then
        return nil, "表达式包含不安全的操作"
    end
    
    -- 尝试编译表达式
    local chunk, compile_err = load("return " .. expr, "表达式", "t", env)
    if not chunk then
        return nil, "语法错误: " .. (compile_err or "未知错误")
    end
    
    -- 安全执行表达式
    local success, result = pcall(chunk)
    if success then
        return result, nil
    else
        return nil, "运行时错误: " .. tostring(result)
    end
end

--============================================================================
-- 错误处理 - 提供丰富的调试信息
--============================================================================

--- 抛出错误并提供上下文信息
--- 
--- 当模板解析出错时，提供错误位置的上下文信息，
--- 帮助开发者快速定位和修复问题。
--- 
--- @param msg string 错误消息
--- @param template string 完整的模板字符串
--- @param pos integer 错误发生的字符位置
--- 
--- @usage
--- utils.error_with_context("未找到变量", template, 15)
--- -- 输出: 未找到变量
--- --       附近: ...{% if user.n...
function M.error_with_context(msg, template, pos)
    -- 参数验证
    if type(msg) ~= "string" then
        msg = tostring(msg)
    end
    if type(template) ~= "string" then
        template = tostring(template)
    end
    if type(pos) ~= "number" then
        pos = 1
    end
    
    -- 计算上下文范围（错误位置前后各20个字符）
    local context_start = math.max(1, pos - 20)
    local context_end = math.min(#template, pos + 20)
    local context = template:sub(context_start, context_end)
    
    -- 计算行号信息（更好的调试体验）
    local line_num = 1
    for i = 1, pos - 1 do
        if template:sub(i, i) == '\n' then
            line_num = line_num + 1
        end
    end
    
    -- 格式化错误信息
    local error_msg = string.format(
        "%s\n位置: 第 %d 行，字符 %d\n附近: ...%s...", 
        msg, line_num, pos, context
    )
    
    error(error_msg, 2)  -- 调用层级设为2，显示调用者的位置
end

--============================================================================
-- 对象属性访问 - 支持嵌套属性和安全访问
--============================================================================

--- 获取嵌套对象的属性值
--- 
--- 支持点分隔的属性路径，如 "user.profile.name"。
--- 在任何层级遇到非表类型时安全返回 nil。
--- 
--- @param env table 根对象
--- @param key string 属性路径，使用点分隔
--- @return any|nil value 属性值，路径不存在时返回 nil
--- 
--- @usage
--- local user = {profile = {name = "Alice", age = 25}}
--- local name = utils.get_env_value(user, "profile.name")  -- "Alice"
--- local city = utils.get_env_value(user, "profile.city")  -- nil
function M.get_env_value(env, key)
    -- 参数验证
    if type(env) ~= "table" then
        return nil
    end
    if type(key) ~= "string" or key == "" then
        return nil
    end
    
    -- 处理简单属性（无点分隔）
    if not key:find("%.") then
        return env[key]
    end
    
    -- 遍历属性路径
    local current = env
    for part in key:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil  -- 中间某个属性不是表类型
        end
        current = current[part]
        if current == nil then
            return nil  -- 属性不存在
        end
    end
    
    return current
end

--============================================================================
-- 类型检查和验证工具
--============================================================================

--- 检查值是否为"真值"（用于条件判断）
--- 
--- 提供类似 JavaScript 的真值判断逻辑：
--- - false, nil: 假值
--- - 0, "": 根据配置决定
--- - 其他: 真值
--- 
--- @param value any 要检查的值
--- @param strict? boolean 严格模式，默认为 false
--- @return boolean is_truthy 是否为真值
function M.is_truthy(value, strict)
    if value == nil or value == false then
        return false
    end
    
    if strict then
        -- 严格模式：只有 nil 和 false 是假值
        return true
    else
        -- 宽松模式：空字符串和 0 也是假值
        if value == "" or value == 0 then
            return false
        end
        return true
    end
end

--- 安全的类型转换
--- 
--- @param value any 要转换的值
--- @param target_type string 目标类型 ("string"|"number"|"boolean")
--- @return any|nil converted_value 转换后的值，失败时返回 nil
function M.safe_convert(value, target_type)
    if target_type == "string" then
        return tostring(value)
    elseif target_type == "number" then
        local num = tonumber(value)
        return num
    elseif target_type == "boolean" then
        return M.is_truthy(value)
    else
        return nil
    end
end

--============================================================================
-- 字符串处理工具
--============================================================================

--- 转义 HTML 特殊字符（防止 XSS）
--- 
--- @param str string 要转义的字符串
--- @return string escaped_str 转义后的字符串
function M.escape_html(str)
    if type(str) ~= "string" then
        str = tostring(str)
    end
    
    local result = str
    result = result:gsub("&", "&amp;")
    result = result:gsub("<", "&lt;")
    result = result:gsub(">", "&gt;")
    result = result:gsub('"', "&quot;")
    result = result:gsub("'", "&#39;")
    
    return result
end

--- 简单的字符串模板替换
--- 
--- @param template string 模板字符串
--- @param replacements table 替换映射表
--- @return string result 替换后的字符串
function M.simple_template(template, replacements)
    if type(template) ~= "string" then
        return tostring(template)
    end
    if type(replacements) ~= "table" then
        return template
    end
    
    local result = template
    for key, value in pairs(replacements) do
        local pattern = "%${" .. key .. "}"
        result = result:gsub(pattern, tostring(value))
    end
    
    return result
end

return M
