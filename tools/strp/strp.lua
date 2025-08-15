--============================================================================
-- STRP 模板引擎 - 主模块
--
-- 这是一个功能强大的模板引擎，支持：
-- • 变量替换：${variable}
-- • 控制结构：if, for, while, with, try-catch, switch
-- • 宏定义：macro
-- • 过滤器链：${variable|filter1|filter2:arg}
-- • 包含文件：{% include "path" %}
-- • 注释：{# comment #}
--
-- 设计特点：
-- • 模块化架构，易于扩展
-- • 智能缓存系统，提升性能
-- • 类型安全，完善的错误处理
-- • 支持嵌套结构和复杂表达式
--============================================================================

---@class StrpModule STRP 模板引擎主模块
---@field render fun(template: string, env: table, options?: table): string 渲染模板
---@field compile fun(template: string): fun(env: table): string 编译模板为函数
---@field render_cached fun(template: string, env: table, options?: table): string 带缓存的渲染
---@field clear_cache fun(): nil 清空缓存
---@field get_cache_stats fun(): table 获取缓存统计
local M = {}

---@type StrpModule
setmetatable(M, {
    __call = function(_, ...)
        return M.render(...)
    end
})

-- 导入核心模块
local constants = require 'wl.tools.strp.constants' -- 常量定义
local utils = require 'wl.tools.strp.utils'         -- 工具函数
local parser = require 'wl.tools.strp.parser'       -- 解析器
local handlers = require 'wl.tools.strp.handlers'   -- 处理器

--============================================================================
-- 缓存系统 - 提升模板渲染性能
--============================================================================

--- 模板缓存存储
--- 将编译后的模板函数缓存起来，避免重复解析相同模板
---@type table<string, fun(env: table): string>
local template_cache = {}

--- 缓存性能统计
--- 用于监控缓存命中率和使用情况
---@class CacheStats
---@field hits integer 缓存命中次数
---@field misses integer 缓存未命中次数
---@field size integer 当前缓存条目数量
local cache_stats = {
    hits = 0,
    misses = 0,
    size = 0
}

--============================================================================
-- 核心解析引擎
--============================================================================

--- 模板解析主函数
---
--- 这是模板引擎的核心，负责：
--- 1. 识别和处理各种模板标记（变量、控制结构、注释）
--- 2. 管理解析状态和位置跟踪
--- 3. 协调各个处理器模块的工作
--- 4. 构建最终的渲染结果
---
---@param template string 要解析的模板字符串
---@param env table 环境变量表，提供模板中使用的数据
---@return string result 解析后的结果字符串
local function parse_template(template, env)
    -- 验证输入参数
    if type(template) ~= "string" then
        error("模板必须是字符串类型", 2)
    end
    if type(env) ~= "table" then
        error("环境变量必须是表类型", 2)
    end

    local result = {} -- 用于收集解析结果的数组
    local pos = 1     -- 当前解析位置指针

    -- 主解析循环：逐字符扫描模板，识别特殊标记
    while pos <= #template do
        -- 第一步：查找注释标记 {# comment #}
        local comment_s, comment_e = template:find("{#.-#}", pos)
        comment_s = comment_s and math.floor(comment_s) or nil
        comment_e = comment_e and math.floor(comment_e) or nil

        -- 第二步：查找控制标记 {% tag code %}
        local tag_s, tag_e = template:find("{%%[^}]*%%}", pos)
        tag_s = tag_s and math.floor(tag_s) or nil
        tag_e = tag_e and math.floor(tag_e) or nil

        -- 第三步：决定处理优先级（注释优先级高于控制标记）
        local next_pos, is_comment = nil, false

        if comment_s and tag_s then
            -- 两种标记都存在时，处理位置较前的
            if comment_s < tag_s then
                next_pos, is_comment = comment_s, true
            else
                next_pos = tag_s
            end
        elseif comment_s then
            next_pos, is_comment = comment_s, true
        elseif tag_s then
            next_pos = tag_s
        else
            -- 没有更多特殊标记，处理剩余的普通文本
            local remaining_text = template:sub(pos)
            local processed_text = parser.replace_variables(remaining_text, env)

            -- 类型安全检查
            if type(processed_text) == "string" then
                table.insert(result, processed_text)
            else
                utils.error_with_context(
                    "变量替换返回了非字符串类型: " .. type(processed_text),
                    template, pos
                )
            end
            break
        end

        -- 第四步：处理标记前的普通文本
        if next_pos > pos then
            local text_part = template:sub(pos, next_pos - 1)
            local processed_text = parser.replace_variables(text_part, env)

            -- 类型安全检查
            if type(processed_text) == "string" then
                table.insert(result, processed_text)
            else
                utils.error_with_context(
                    "变量替换返回了非字符串类型: " .. type(processed_text),
                    template, pos
                )
            end
        end

        -- 第五步：处理特殊标记
        if is_comment then
            -- 注释处理：直接跳过，不产生任何输出
            pos = comment_e and (comment_e + 1) or (pos + 1)
        else
            -- 控制标记处理：分发给相应的处理器
            if not tag_s or not tag_e then
                -- 标记格式错误，跳过并继续
                pos = pos + 1
                goto continue
            end

            -- 解析标记内容
            local content = template:sub(tag_s + 2, tag_e - 2):match("^%s*(.-)%s*$")
            local tag_name, code = content:match("^(%w+)%s*(.*)")

            -- 分发给相应的处理器
            local block_result, new_pos = nil, tag_e + 1

            if tag_name == "include" then
                block_result = handlers.handle_include(template, env, code)
            elseif tag_name == "if" then
                block_result, new_pos = handlers.handle_if(template, env, tag_e, code)
            elseif tag_name == "for" then
                block_result, new_pos = handlers.handle_for(template, env, tag_e, code)
            elseif tag_name == "while" then
                block_result, new_pos = handlers.handle_while(template, env, tag_e, code)
            elseif tag_name == "with" then
                block_result, new_pos = handlers.handle_with(template, env, tag_e, code)
            elseif tag_name == "try" then
                block_result, new_pos = handlers.handle_try(template, env, tag_e, code)
            elseif tag_name == "switch" then
                block_result, new_pos = handlers.handle_switch(template, env, tag_e, code)
            elseif tag_name == "macro" then
                block_result, new_pos = handlers.handle_macro(template, env, tag_e, code)
            else
                -- 未知标记：记录警告但继续处理
                -- TODO: 可以考虑添加调试模式来显示未知标记警告
            end

            -- 收集处理结果
            if block_result then
                table.insert(result, block_result)
            end

            pos = new_pos
        end

        ::continue::
    end

    return table.concat(result)
end

-- 将解析函数注册到处理器模块（用于递归调用）
handlers.set_parse_template(parse_template)

--============================================================================
-- 公共 API - 对外接口
--============================================================================

--- 渲染模板字符串
---
--- 这是最常用的接口，直接渲染模板并返回结果。
--- 适用于一次性渲染或模板变化频繁的场景。
---
--- @param template string 模板字符串，支持完整的 STRP 语法
--- @param env table 环境变量表，提供模板中使用的数据
--- @param options? table 可选配置项
---   - trim_whitespace: boolean 是否压缩空白字符
--- @return string result 渲染后的结果字符串
---
--- @usage
--- local result = strp.render("Hello ${name}!", {name = "World"})
--- print(result)  -- 输出: Hello World!
function M.render(template, env, options)
    -- 参数验证
    if type(template) ~= "string" then
        error("模板参数必须是字符串类型", 2)
    end
    if type(env) ~= "table" then
        error("环境变量参数必须是表类型", 2)
    end

    options = options or {}
    local result = parse_template(template, env)

    -- 可选的空白字符处理
    if options.trim_whitespace then
        result = result:gsub("%s+", " ") -- 合并多个空格为一个
            :gsub("^%s+", "")            -- 去除开头空格
            :gsub("%s+$", "")            -- 去除结尾空格
    end

    return result
end

--- 编译模板为可重用函数
---
--- 将模板预编译为函数并缓存，适用于：
--- 1. 相同模板需要多次渲染的场景
--- 2. 性能敏感的应用
--- 3. 模板内容固定，只有数据变化的情况
---
--- @param template string 模板字符串
--- @return fun(env: table): string compiled_func 编译后的模板函数
---
--- @usage
--- local template_func = strp.compile("Hello ${name}!")
--- local result1 = template_func({name = "Alice"})
--- local result2 = template_func({name = "Bob"})
function M.compile(template)
    if type(template) ~= "string" then
        error("模板参数必须是字符串类型", 2)
    end

    -- 检查缓存
    if template_cache[template] then
        cache_stats.hits = cache_stats.hits + 1
        return template_cache[template]
    end

    cache_stats.misses = cache_stats.misses + 1

    -- 缓存大小管理：使用简单的 LRU 策略
    if cache_stats.size >= constants.MAX_CACHE_SIZE then
        -- 清空一半缓存以避免内存无限增长
        local keys = {}
        for k in pairs(template_cache) do
            table.insert(keys, k)
        end

        -- 删除前一半的缓存项
        for i = 1, math.floor(#keys / 2) do
            template_cache[keys[i]] = nil
        end
        cache_stats.size = math.floor(cache_stats.size / 2)
    end

    -- 编译模板为函数
    local compiled_func = function(env)
        if type(env) ~= "table" then
            error("环境变量参数必须是表类型", 2)
        end
        return parse_template(template, env)
    end

    -- 存入缓存
    template_cache[template] = compiled_func
    cache_stats.size = cache_stats.size + 1

    return compiled_func
end

--- 带缓存的渲染函数
---
--- 结合了 compile 和 render 的优点：
--- - 自动使用缓存提升性能
--- - 接口简单，无需手动管理编译函数
--- - 适用于大多数使用场景
---
--- @param template string 模板字符串
--- @param env table 环境变量表
--- @param options? table 选项表
--- @return string result 渲染后的结果
---
--- @usage
--- -- 第一次调用会编译并缓存模板
--- local result1 = strp.render_cached(template, {name = "Alice"})
--- -- 后续调用直接使用缓存，提升性能
--- local result2 = strp.render_cached(template, {name = "Bob"})
function M.render_cached(template, env, options)
    local compiled = M.compile(template)
    local result = compiled(env)

    -- 应用选项
    if options and options.trim_whitespace then
        result = result:gsub("%s+", " ") -- 合并多个空格为一个
            :gsub("^%s+", "")            -- 去除开头空格
            :gsub("%s+$", "")            -- 去除结尾空格
    end

    return result
end

--============================================================================
-- 缓存管理 API
--============================================================================

--- 清空模板缓存
---
--- 在以下情况下可能需要清空缓存：
--- 1. 内存使用过多时
--- 2. 开发调试期间
--- 3. 模板定义发生变化时
---
--- @usage
--- strp.clear_cache()  -- 清空所有缓存
function M.clear_cache()
    template_cache = {}
    cache_stats = {
        hits = 0,
        misses = 0,
        size = 0
    }
end

--- 获取缓存统计信息
---
--- 用于监控缓存性能和调试：
--- - hits: 缓存命中次数
--- - misses: 缓存未命中次数
--- - size: 当前缓存大小
--- - hit_rate: 缓存命中率（0-1之间）
---
--- @return table stats 缓存统计信息
---
--- @usage
--- local stats = strp.get_cache_stats()
--- print("缓存命中率:", stats.hit_rate * 100 .. "%")
function M.get_cache_stats()
    local total_requests = cache_stats.hits + cache_stats.misses
    return {
        hits = cache_stats.hits,
        misses = cache_stats.misses,
        size = cache_stats.size,
        hit_rate = total_requests > 0 and (cache_stats.hits / total_requests) or 0
    }
end

return M
