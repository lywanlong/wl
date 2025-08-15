--============================================================================
-- 模板解析工具函数
--============================================================================

local constants = require 'wl.tools.strp.constants'
local utils = require 'wl.tools.strp.utils'
local filter_mod = require 'wl.tools.strp.filters'

---@class StrpParser
local M = {}

--- 查找匹配的块结束位置（支持嵌套）
---@param template string 模板字符串
---@param start_pos integer 开始搜索的位置
---@return integer|nil end_start 结束标签的开始位置
---@return integer|nil end_finish 结束标签的结束位置
function M.find_block_end(template, start_pos)
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
        
        if constants.END_KEYWORDS[tag_name] then
            depth = depth - 1
            if depth == 0 then return tag_s, tag_e end
        elseif constants.BLOCK_KEYWORDS[tag_name] then
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
function M.parse_filters(text)
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
            -- 有参数的过滤器
            local args = {}
            -- 简单解析参数（支持字符串和数字）
            for arg in args_str:gmatch("([^,]+)") do
                arg = arg:match("^%s*(.-)%s*$")  -- 去除空格
                if arg:match("^['\"].*['\"]$") then
                    -- 字符串参数，去除引号
                    table.insert(args, arg:sub(2, -2))
                elseif tonumber(arg) then
                    -- 数字参数
                    table.insert(args, tonumber(arg))
                else
                    -- 其他类型，当作字符串处理
                    table.insert(args, arg)
                end
            end
            table.insert(filters, {name = name, args = args})
        else
            -- 无参数的过滤器
            local name = parts[i]:match("^%s*([%w_]+)%s*$")
            if name then
                table.insert(filters, {name = name, args = {}})
            end
        end
    end
    
    return key, filters
end

--- 替换模板中的变量（${variable} 语法）
---@param template string 模板字符串
---@param env table 环境变量表
---@return string 替换后的字符串
function M.replace_variables(template, env)
    local result = template:gsub("%${([^}]+)}", function(content)
        -- 去除首尾空格
        content = content:match("^%s*(.-)%s*$")
        
        -- 解析变量名和过滤器
        local key, filters = M.parse_filters(content)
        
        -- 获取变量值
        local value = utils.get_env_value(env, key)
        
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
    return result
end

return M
