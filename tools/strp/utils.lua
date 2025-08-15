--============================================================================
-- 模板引擎核心工具函数
--============================================================================

---@class StrpUtils
local M = {}

--- 安全执行 Lua 表达式
---@param expr string 要执行的表达式
---@param env table 环境变量表
---@return any|nil result 执行结果，失败时返回 nil
---@return string? error 错误信息，成功时返回 nil
function M.eval(expr, env)
    local f, err = load("return " .. expr, nil, "t", env)
    if not f then return nil, err end
    local ok, res = pcall(f)
    return ok and res or nil, not ok and res or err
end

--- 报错并提供上下文信息
---@param msg string 错误消息
---@param template string 模板字符串
---@param pos number 错误位置
function M.error_with_context(msg, template, pos)
    local context = template:sub(math.max(1, pos - 20), math.min(#template, pos + 20))
    error(string.format("%s\n附近: ...%s...", msg, context))
end

--- 获取嵌套对象的值（支持 obj.prop.subprop 语法）
---@param env table 环境变量表
---@param key string 属性键（支持点分隔）
---@return any|nil 属性值，不存在时返回 nil
function M.get_env_value(env, key)
    local cur = env
    for part in key:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end

return M
