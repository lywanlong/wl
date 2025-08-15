--============================================================================
-- 模板块处理器
--============================================================================

local utils = require 'wl.tools.strp.utils'
local parser = require 'wl.tools.strp.parser'
local constants = require 'wl.tools.strp.constants'

---@class StrpHandlers
local M = {}

-- 前向声明主解析函数
local parse_template

--- 设置主解析函数的引用
---@param func function 主解析函数
function M.set_parse_template(func)
    parse_template = func
end

--- 处理 include 指令（包含其他模板文件）
---@param template string 当前模板（用于错误报告）
---@param env table 环境变量
---@param code string include 指令的参数
---@return string 包含文件的处理结果
function M.handle_include(template, env, code)
    -- 支持三种引用方式：双引号、单引号、无引号
    local module_name = code:match([["(.-)"]]) or code:match([['(.-)']]) or code:match("([%w%.]+)")
    if not module_name then
        utils.error_with_context("无效的 include 语法", template, 1)
    end
    
    -- 尝试加载模块
    local ok, content = pcall(require, module_name)
    if not ok then
        utils.error_with_context("找不到包含文件: " .. module_name, template, 1)
    end
    
    -- 处理不同类型的返回值
    if type(content) == "string" then
        return parse_template(content, env)
    elseif type(content) == "table" and content[1] then
        return parse_template(tostring(content[1]), env)
    else
        utils.error_with_context("包含文件未返回字符串", template, 1)
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
function M.handle_if(template, env, tag_end, code)
    local end_s, end_e = parser.find_block_end(template, tag_end + 1)
    if not end_s then
        utils.error_with_context("if 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    local cond = utils.eval(code, env)
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
function M.handle_for(template, env, tag_end, code)
    local end_s, end_e = parser.find_block_end(template, tag_end + 1)
    if not end_s then
        utils.error_with_context("for 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    local result = {}
    
    -- 解析 for k,v in table 语法
    local key_var, value_var, expr = code:match("([%w_]+)%s*,%s*([%w_]+)%s+in%s+(.+)")
    if key_var and value_var then
        local list = utils.eval(expr, env)
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
        local list = utils.eval(expr, env)
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
-- Switch 处理辅助函数
--============================================================================

--- 检查是否是开启块的标签
---@param tag_name string 标签名
---@return boolean
local function is_block_start_tag(tag_name)
    return constants.BLOCK_KEYWORDS[tag_name] or false
end

--- 检查是否是结束块的标签
---@param tag_name string 标签名
---@return boolean
local function is_block_end_tag(tag_name)
    return constants.END_KEYWORDS[tag_name] or false
end

--- 提取分支内容（直到下一个 case/default 或块结束）
---@param block string 块内容
---@param start_pos integer 开始位置
---@param current_tag string 当前标签类型
---@return table result {content: string, next_pos: integer}
local function extract_branch_content(block, start_pos, current_tag)
    local content_start = start_pos + 1
    local pos = content_start
    local depth = 0
    
    while pos <= #block do
        local tag_s, tag_e = block:find("{%%[^}]*%%}", pos)
        if not tag_s or not tag_e then
            -- 没有更多标签，内容到块结束
            return {
                content = block:sub(content_start),
                next_pos = #block + 1
            }
        end
        
        tag_s = math.floor(tag_s)
        tag_e = math.floor(tag_e)
        
        local content = block:sub(tag_s + 2, tag_e - 2):match("^%s*(.-)%s*$")
        local tag_name = content:match("^(%w+)")
        
        -- 处理嵌套
        if is_block_start_tag(tag_name) then
            depth = depth + 1
        elseif is_block_end_tag(tag_name) then
            depth = depth - 1
        elseif depth == 0 and (tag_name == "case" or tag_name == "default") then
            -- 遇到同级的 case 或 default，结束当前分支
            return {
                content = block:sub(content_start, tag_s - 1),
                next_pos = tag_s
            }
        end
        
        pos = tag_e + 1
    end
    
    -- 到达块结束
    return {
        content = block:sub(content_start),
        next_pos = #block + 1
    }
end

--- 解析 switch 块中的所有分支（case 和 default）
---@param block string switch 块内容
---@return table branches 分支信息数组
---@return string? error 错误信息（如果有）
local function parse_switch_branches(block)
    local branches = {}
    local pos = 1
    local depth = 0
    
    while pos <= #block do
        local tag_s, tag_e = block:find("{%%[^}]*%%}", pos)
        if not tag_s or not tag_e then
            break
        end
        
        tag_s = math.floor(tag_s)
        tag_e = math.floor(tag_e)
        
        local content = block:sub(tag_s + 2, tag_e - 2):match("^%s*(.-)%s*$")
        local tag_name, tag_code = content:match("^(%w+)%s*(.*)")
        
        -- 处理嵌套块的深度
        if is_block_start_tag(tag_name) then
            depth = depth + 1
        elseif is_block_end_tag(tag_name) then
            depth = depth - 1
        elseif depth == 0 and (tag_name == "case" or tag_name == "default") then
            -- 只在顶级处理 case 和 default
            local branch_content = extract_branch_content(block, tag_e, tag_name)
            
            table.insert(branches, {
                type = tag_name,
                value = tag_code,
                content = branch_content.content,
                next_pos = branch_content.next_pos
            })
            
            pos = branch_content.next_pos
            goto continue
        end
        
        pos = tag_e + 1
        ::continue::
    end
    
    return branches, nil
end

--- 验证 switch 分支结构
---@param branches table 分支数组
---@param template string 模板字符串（用于错误报告）
---@param pos integer 位置（用于错误报告）
local function validate_switch_branches(branches, template, pos)
    if #branches == 0 then
        utils.error_with_context("switch 块中没有找到任何 case 或 default 分支", template, pos)
    end
    
    local default_count = 0
    for _, branch in ipairs(branches) do
        if branch.type == "default" then
            default_count = default_count + 1
        elseif branch.type == "case" and (not branch.value or branch.value == "") then
            utils.error_with_context("case 分支缺少比较值", template, pos)
        end
    end
    
    if default_count > 1 then
        utils.error_with_context("switch 块中只能有一个 default 分支", template, pos)
    end
end

--- 比较两个值是否相等（支持类型转换）
---@param a any 值A
---@param b any 值B  
---@return boolean 是否相等
local function compare_values(a, b)
    -- 直接相等
    if a == b then
        return true
    end
    
    -- 数字和字符串的相互转换比较
    if type(a) == "number" and type(b) == "string" then
        return tostring(a) == b
    elseif type(a) == "string" and type(b) == "number" then
        return a == tostring(b)
    end
    
    -- 布尔值和字符串比较
    if type(a) == "boolean" and type(b) == "string" then
        return tostring(a) == b
    elseif type(a) == "string" and type(b) == "boolean" then
        return a == tostring(b)
    end
    
    return false
end

--- 执行 switch 匹配逻辑
---@param branches table 分支数组
---@param switch_value any 要匹配的值
---@param env table 环境变量
---@return string result 执行结果
local function execute_switch_logic(branches, switch_value, env)
    -- 首先尝试匹配所有 case（优化：按顺序匹配，找到就立即返回）
    for i, branch in ipairs(branches) do
        if branch.type == "case" then
            local case_value, eval_error = utils.eval(branch.value, env)
            if eval_error then
                error("case 分支值计算错误（分支 " .. i .. "）: " .. eval_error)
            end
            
            -- 支持多种类型的比较
            if compare_values(switch_value, case_value) then
                return parse_template(branch.content, env)
            end
        end
    end
    
    -- 如果没有匹配的 case，查找 default
    for _, branch in ipairs(branches) do
        if branch.type == "default" then
            return parse_template(branch.content, env)
        end
    end
    
    -- 没有匹配的分支，返回空字符串
    return ""
end

--- 处理 switch 选择块
---@param template string 模板字符串
---@param env table 环境变量
---@param tag_end integer switch 标签的结束位置
---@param code string 选择表达式
---@return string result 处理结果
---@return integer next_pos 下一个处理位置
function M.handle_switch(template, env, tag_end, code)
    local end_s, end_e = parser.find_block_end(template, tag_end + 1)
    if not end_s then
        utils.error_with_context("switch 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    
    -- 提前计算switch值，避免重复计算
    local switch_value, eval_error = utils.eval(code, env)
    if eval_error then
        utils.error_with_context("switch 表达式计算错误: " .. eval_error, template, tag_end)
    end
    
    -- 解析所有分支
    local branches, parse_error = parse_switch_branches(block)
    if parse_error then
        utils.error_with_context("switch 分支解析错误: " .. parse_error, template, tag_end)
    end
    
    -- 验证分支结构
    validate_switch_branches(branches, template, tag_end)
    
    -- 执行匹配逻辑
    local result = execute_switch_logic(branches, switch_value, env)
    
    return result, end_e + 1
end

return M
