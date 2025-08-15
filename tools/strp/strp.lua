---@class StrpModule
---@field render fun(template: string, env: table, options?: table): string
---@field compile fun(template: string): fun(env: table): string
---@field clear_cache fun(): nil
local M = {}

-- 导入模块
local constants = require 'wl.tools.strp.constants'
local utils = require 'wl.tools.strp.utils'
local parser = require 'wl.tools.strp.parser'
local handlers = require 'wl.tools.strp.handlers'

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

--============================================================================
-- 主解析函数
--============================================================================

--- 解析模板字符串的主函数
---@param template string 要解析的模板字符串
---@param env table 环境变量表
---@return string 解析后的结果字符串
local function parse_template(template, env)
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
            local processed_text = parser.replace_variables(remaining_text, env)
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
            local processed_text = parser.replace_variables(text_part, env)
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
                    table.insert(result, handlers.handle_include(template, env, code))
                    pos = tag_e + 1
                elseif tag_name == "if" then
                    -- 处理 if 条件块
                    local block_result, new_pos = handlers.handle_if(template, env, tag_e, code)
                    table.insert(result, block_result)
                    pos = new_pos
                elseif tag_name == "for" then
                    -- 处理 for 循环块
                    local block_result, new_pos = handlers.handle_for(template, env, tag_e, code)
                    table.insert(result, block_result)
                    pos = new_pos
                elseif tag_name == "switch" then
                    -- 处理 switch 选择块
                    local block_result, new_pos = handlers.handle_switch(template, env, tag_e, code)
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

-- 设置解析函数到handlers模块
handlers.set_parse_template(parse_template)

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
    if cache_stats.size >= constants.MAX_CACHE_SIZE then
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
