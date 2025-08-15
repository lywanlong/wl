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

-- 宏定义存储
local macro_definitions = {}

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

--- 处理 while 循环块
---@param template string 模板字符串
---@param env table 环境变量
---@param tag_end integer while 标签的结束位置
---@param code string 循环条件表达式
---@return string result 处理结果
---@return integer next_pos 下一个处理位置
function M.handle_while(template, env, tag_end, code)
    local end_s, end_e = parser.find_block_end(template, tag_end + 1)
    if not end_s then
        utils.error_with_context("while 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    local result = {}
    local iterations = 0
    
    -- 安全循环：限制最大迭代次数
    while iterations < constants.MAX_LOOP_ITERATIONS do
        local condition, eval_error = utils.eval(code, env)
        if eval_error then
            utils.error_with_context("while 条件计算错误: " .. eval_error, template, tag_end)
        end
        
        if not condition then
            break
        end
        
        table.insert(result, parse_template(block, env))
        iterations = iterations + 1
    end
    
    -- 检查是否因为超出最大迭代次数而退出
    if iterations >= constants.MAX_LOOP_ITERATIONS then
        utils.error_with_context("while 循环超出最大迭代次数限制 (" .. constants.MAX_LOOP_ITERATIONS .. ")", template, tag_end)
    end
    
    return table.concat(result), end_e + 1
end

--- 处理 with 作用域块
---@param template string 模板字符串
---@param env table 环境变量
---@param tag_end integer with 标签的结束位置
---@param code string 作用域表达式
---@return string result 处理结果
---@return integer next_pos 下一个处理位置
function M.handle_with(template, env, tag_end, code)
    local end_s, end_e = parser.find_block_end(template, tag_end + 1)
    if not end_s then
        utils.error_with_context("with 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    
    -- 解析 with 语法：支持 "expr as var" 和 "var = expr" 两种形式
    local var_name, expr
    
    -- 尝试 "expr as var" 格式
    local as_match = code:match("(.+)%s+as%s+([%w_]+)")
    if as_match then
        expr = as_match:match("^%s*(.-)%s*$")
        var_name = code:match("as%s+([%w_]+)%s*$")
    else
        -- 尝试 "var = expr" 格式
        var_name, expr = code:match("([%w_]+)%s*=%s*(.+)")
    end
    
    if not var_name or not expr then
        utils.error_with_context("with 语法错误，应使用 'expr as var' 或 'var = expr' 格式", template, tag_end)
    end
    
    -- 计算表达式值
    local value, eval_error = utils.eval(expr, env)
    if eval_error then
        utils.error_with_context("with 表达式计算错误: " .. eval_error, template, tag_end)
    end
    
    -- 创建新的作用域环境
    local new_env = setmetatable({[var_name] = value}, {__index = env})
    
    -- 在新作用域中渲染块内容
    local result = parse_template(block, new_env)
    
    return result, end_e + 1
end

--- 解析 try-catch 块内容
---@param block string try 块内容
---@return string try_content try 部分内容
---@return string? catch_content catch 部分内容
---@return string? error_var 错误变量名
local function parse_try_catch_block(block)
    local pos = 1
    local depth = 0
    local catch_start = nil
    local catch_tag_start = nil
    local error_var = nil
    
    while pos <= #block do
        local tag_s, tag_e = block:find("{%%[^}]*%%}", pos)
        if not tag_s or not tag_e then
            break
        end
        
        tag_s = math.floor(tag_s)
        tag_e = math.floor(tag_e)
        
        local content = block:sub(tag_s + 2, tag_e - 2):match("^%s*(.-)%s*$")
        local tag_name, tag_code = content:match("^(%w+)%s*(.*)")
        
        -- 处理嵌套深度
        if constants.BLOCK_KEYWORDS[tag_name] then
            depth = depth + 1
        elseif constants.END_KEYWORDS[tag_name] then
            depth = depth - 1
        elseif depth == 0 and tag_name == "catch" then
            -- 找到同级的 catch 标签
            catch_tag_start = tag_s
            catch_start = tag_e + 1
            if tag_code and tag_code ~= "" then
                error_var = tag_code:match("([%w_]+)")
            end
            break
        end
        
        pos = tag_e + 1
    end
    
    if catch_start and catch_tag_start then
        return block:sub(1, catch_tag_start - 1), block:sub(catch_start), error_var
    else
        return block, nil, nil
    end
end

--- 处理 try-catch 错误处理块
---@param template string 模板字符串
---@param env table 环境变量
---@param tag_end integer try 标签的结束位置
---@param code string try 表达式（通常为空）
---@return string result 处理结果
---@return integer next_pos 下一个处理位置
function M.handle_try(template, env, tag_end, code)
    local end_s, end_e = parser.find_block_end(template, tag_end + 1)
    if not end_s then
        utils.error_with_context("try 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    
    -- 查找 catch 分隔符
    local try_content, catch_content, error_var = parse_try_catch_block(block)
    
    -- 尝试执行 try 块
    local success, result = pcall(parse_template, try_content, env)
    
    if success then
        -- try 块执行成功
        return result, end_e + 1
    else
        -- 发生错误，执行 catch 块
        if catch_content then
            local catch_env = env
            if error_var then
                -- 将错误信息注入到 catch 环境中
                catch_env = setmetatable({[error_var] = result}, {__index = env})
            end
            
            local catch_result = parse_template(catch_content, catch_env)
            return catch_result, end_e + 1
        else
            -- 没有 catch 块，返回空字符串（静默处理错误）
            return "", end_e + 1
        end
    end
end

--- 处理 macro 宏定义块
---@param template string 模板字符串
---@param env table 环境变量
---@param tag_end integer macro 标签的结束位置
---@param code string 宏定义表达式
---@return string result 处理结果（宏定义不产生输出）
---@return integer next_pos 下一个处理位置
function M.handle_macro(template, env, tag_end, code)
    local end_s, end_e = parser.find_block_end(template, tag_end + 1)
    if not end_s then
        utils.error_with_context("macro 块未正确关闭", template, tag_end)
    end
    
    local block = template:sub(tag_end + 1, end_s - 1)
    
    -- 解析宏定义：macro name(param1, param2, ...)
    local macro_name, params_str = code:match("^([%w_]+)%s*%((.*)%)%s*$")
    if not macro_name then
        -- 尝试无参数宏：macro name
        macro_name = code:match("^([%w_]+)%s*$")
        params_str = ""
    end
    
    if not macro_name then
        utils.error_with_context("macro 语法错误，应使用 'macro name(param1, param2)' 格式", template, tag_end)
    end
    
    -- 解析参数列表
    local params = {}
    local defaults = {}
    
    if params_str and params_str ~= "" then
        for param in params_str:gmatch("[^,]+") do
            param = param:match("^%s*(.-)%s*$") -- 去除首尾空格
            
            -- 检查是否有默认值：param=default
            local param_name, default_value = param:match("^([%w_]+)%s*=%s*(.+)$")
            if param_name then
                table.insert(params, param_name)
                defaults[param_name] = default_value
            else
                -- 无默认值的参数
                param_name = param:match("^([%w_]+)$")
                if param_name then
                    table.insert(params, param_name)
                else
                    utils.error_with_context("macro 参数格式错误: " .. param, template, tag_end)
                end
            end
        end
    end
    
    -- 存储宏定义
    macro_definitions[macro_name] = {
        params = params,
        defaults = defaults,
        body = block
    }
    
    -- 宏定义不产生输出
    return "", end_e + 1
end

--- 调用宏
---@param macro_name string 宏名称
---@param args table 参数列表
---@param env table 当前环境
---@return string? result 宏展开结果
---@return string? error 错误信息（如果有）
function M.call_macro(macro_name, args, env)
    local macro_def = macro_definitions[macro_name]
    if not macro_def then
        return nil, "未定义的宏: " .. macro_name
    end
    
    -- 创建宏的局部环境
    local macro_env = setmetatable({}, {__index = env})
    
    -- 设置参数值
    for i, param_name in ipairs(macro_def.params) do
        local arg_value = args[i]
        
        -- 如果没有提供参数，使用默认值
        if arg_value == nil and macro_def.defaults[param_name] then
            local default_val, eval_error = utils.eval(macro_def.defaults[param_name], env)
            if eval_error then
                return nil, "宏默认参数计算错误: " .. eval_error
            end
            arg_value = default_val
        end
        
        macro_env[param_name] = arg_value
    end
    
    -- 展开宏
    local success, result = pcall(parse_template, macro_def.body, macro_env)
    if success then
        return result, nil
    else
        return nil, "宏展开错误: " .. result
    end
end

--- 清空所有宏定义（用于测试或重置）
function M.clear_macros()
    macro_definitions = {}
end

--- 获取已定义的宏列表
function M.get_macro_names()
    local names = {}
    for name in pairs(macro_definitions) do
        table.insert(names, name)
    end
    return names
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
