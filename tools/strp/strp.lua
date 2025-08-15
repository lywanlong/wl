--============================================================================
-- STRP 模板引擎 - 主模块 v2.1
--
-- 这是一个功能强大的模板引擎，支持：
-- • 变量替换：${variable}
-- • 嵌套模板：${var|filter:${nested_var}}
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
-- • 高性能优化和内存管理
--============================================================================

---@class StrpModule STRP 模板引擎主模块
---@field render fun(template: string, env: table, options?: table): string 渲染模板
---@field render_cached fun(template: string, env: table, options?: table): string 带缓存的渲染
---@field clear_cache fun(): nil 清空缓存
---@field get_cache_stats fun(): table 获取缓存统计
---@field get_version fun(): string 获取版本信息
local M = {}

---@type StrpModule
setmetatable(M, {
    __call = function(_, ...)
        return M.render(...)
    end
})

-- 导入核心模块
local constants = require 'wl.tools.strp.constants'
local utils = require 'wl.tools.strp.utils'
local parser = require 'wl.tools.strp.parser'
local handlers = require 'wl.tools.strp.handlers'

--============================================================================
-- 缓存系统 - 提升模板渲染性能
--============================================================================

--- 模板缓存存储
--- 将编译后的模板函数缓存起来，避免重复解析相同模板
---@type table<string, fun(env: table): string>
local template_cache = {}

--- 缓存访问时间记录（用于LRU淘汰）
---@type table<string, number>
local cache_access_time = {}

--- 缓存性能统计
--- 用于监控缓存命中率和使用情况
local cache_stats = {
    hits = 0,           -- 缓存命中次数
    misses = 0,         -- 缓存未命中次数
    total_requests = 0, -- 总请求次数
    cache_size = 0,     -- 当前缓存大小
    last_cleanup = 0    -- 最后清理时间
}

--- 生成缓存键
---@param template string 模板字符串
---@param options? table 选项参数
---@return string cache_key 缓存键
local function generate_cache_key(template, options)
    if not options or next(options) == nil then
        return template
    end
    
    -- 将选项序列化为字符串
    local option_parts = {}
    for k, v in pairs(options) do
        table.insert(option_parts, tostring(k) .. "=" .. tostring(v))
    end
    table.sort(option_parts)
    
    return template .. "|" .. table.concat(option_parts, "&")
end

--- LRU缓存淘汰
local function cleanup_cache()
    local current_time = os.time()
    local cache_size = 0
    
    -- 计算当前缓存大小
    for _ in pairs(template_cache) do
        cache_size = cache_size + 1
    end
    
    cache_stats.cache_size = cache_size
    
    -- 检查是否需要清理
    if cache_size <= constants.CACHE.MAX_ENTRIES then
        return
    end
    
    -- 收集所有缓存项及其访问时间
    local cache_items = {}
    for key, _ in pairs(template_cache) do
        table.insert(cache_items, {
            key = key,
            access_time = cache_access_time[key] or 0
        })
    end
    
    -- 按访问时间排序（最少访问的在前）
    table.sort(cache_items, function(a, b)
        return a.access_time < b.access_time
    end)
    
    -- 删除一半的缓存项
    local items_to_remove = math.floor(cache_size / 2)
    for i = 1, items_to_remove do
        local key = cache_items[i].key
        template_cache[key] = nil
        cache_access_time[key] = nil
    end
    
    cache_stats.last_cleanup = current_time
end

--- 自动清理过期缓存
local function auto_cleanup()
    local current_time = os.time()
    local cleanup_interval = constants.CACHE.CLEANUP_INTERVAL
    
    if current_time - cache_stats.last_cleanup > cleanup_interval then
        cleanup_cache()
    end
end

--============================================================================
-- 错误处理
--============================================================================

--- 安全执行函数
---@param func function 要执行的函数
---@param error_handler? function 错误处理函数
---@return boolean success 是否成功
---@return any result 执行结果或错误信息
local function safe_execute(func, error_handler)
    local success, result = pcall(func)
    
    if not success and error_handler then
        result = error_handler(result)
    end
    
    return success, result
end

--- 创建错误处理器
---@param options table 选项配置
---@return function error_handler 错误处理函数
local function create_error_handler(options)
    local strategy = options.error_handling or "strict"
    
    return function(error_msg)
        if strategy == "strict" then
            error(error_msg)
        elseif strategy == "ignore" then
            return ""
        elseif strategy == "replace" then
            return "[ERROR: " .. tostring(error_msg) .. "]"
        end
        return tostring(error_msg)
    end
end

--============================================================================
-- 模板编译
--============================================================================

--- 编译模板为可执行函数
---@param template string 模板字符串
---@param options? table 编译选项
---@return function|nil compiled_template 编译后的模板函数
---@return string|nil error_msg 错误信息
function M.compile(template, options)
    if type(template) ~= "string" then
        return nil, "模板必须是字符串类型"
    end
    
    options = constants.merge_options(options or {})
    
    -- 验证配置
    local config_valid, config_error = constants.validate_config(options)
    if not config_valid then
        return nil, config_error
    end
    
    -- 检查模板大小
    if #template > constants.PERFORMANCE.MAX_TEMPLATE_SIZE then
        return nil, "模板大小超出限制"
    end
    
    -- 创建错误处理器
    local error_handler = create_error_handler(options)
    
    -- 编译模板
    local compiled_template = function(env)
        env = env or {}
        
        local success, result = safe_execute(function()
            -- 开始处理模板
            local processed = template
            
            -- 处理变量替换 (核心功能)
            processed = parser.replace_variables(processed, env)
            
            -- 检查输出大小
            if #processed > constants.PERFORMANCE.MAX_OUTPUT_SIZE then
                error("输出大小超出限制")
            end
            
            -- 自动转义（如果启用）
            if options.autoescape then
                processed = utils.html_escape(processed)
            end
            
            return processed
        end, error_handler)
        
        if success then
            return result
        else
            return error_handler(result)
        end
    end
    
    return compiled_template, nil
end

--============================================================================
-- 主要API函数
--============================================================================

--- 渲染模板（主要API）
---@param template string 模板字符串
---@param env table 环境变量表
---@param options? table 渲染选项
---@return string result 渲染结果
function M.render(template, env, options)
    if type(template) ~= "string" then
        error("模板必须是字符串类型")
    end
    
    env = env or {}
    options = constants.merge_options(options or {})
    
    -- 性能监控
    local start_time = os.clock()
    
    -- 编译并执行模板
    local compiled_template, compile_error = M.compile(template, options)
    if not compiled_template then
        error(compile_error or "模板编译失败")
    end
    
    local result = compiled_template(env)
    
    -- 性能统计
    local end_time = os.clock()
    local render_time = (end_time - start_time) * 1000
    
    if options.debug then
        print(string.format("[STRP] 渲染耗时: %.2f ms", render_time))
    end
    
    return result
end

--- 带缓存的渲染（推荐用于生产环境）
---@param template string 模板字符串
---@param env table 环境变量表
---@param options? table 渲染选项
---@return string result 渲染结果
function M.render_cached(template, env, options)
    if type(template) ~= "string" then
        error("模板必须是字符串类型")
    end
    
    env = env or {}
    options = constants.merge_options(options or {})
    
    -- 如果禁用缓存，直接渲染
    if not options.cache then
        return M.render(template, env, options)
    end
    
    -- 生成缓存键
    local cache_key = generate_cache_key(template, options)
    
    -- 检查缓存
    cache_stats.total_requests = cache_stats.total_requests + 1
    
    if template_cache[cache_key] then
        cache_stats.hits = cache_stats.hits + 1
        cache_access_time[cache_key] = os.time()
        return template_cache[cache_key](env)
    end
    
    -- 缓存未命中，编译模板
    cache_stats.misses = cache_stats.misses + 1
    
    local compiled_template, compile_error = M.compile(template, options)
    if not compiled_template then
        error(compile_error or "模板编译失败")
    end
    
    -- 存入缓存
    template_cache[cache_key] = compiled_template
    cache_access_time[cache_key] = os.time()
    
    -- 自动清理缓存
    auto_cleanup()
    
    return compiled_template(env)
end

--============================================================================
-- 缓存管理
--============================================================================

--- 清空所有缓存
function M.clear_cache()
    template_cache = {}
    cache_access_time = {}
    parser.clear_cache()
    
    -- 重置统计信息
    cache_stats = {
        hits = 0,
        misses = 0,
        total_requests = 0,
        cache_size = 0,
        last_cleanup = 0
    }
end

--- 获取缓存统计信息
---@return table stats 缓存统计
function M.get_cache_stats()
    local cache_size = 0
    for _ in pairs(template_cache) do
        cache_size = cache_size + 1
    end
    
    cache_stats.cache_size = cache_size
    
    local hit_rate = 0
    if cache_stats.total_requests > 0 then
        hit_rate = cache_stats.hits / cache_stats.total_requests
    end
    
    local parser_stats = parser.get_cache_stats()
    
    return {
        template_cache = {
            size = cache_stats.cache_size,
            hits = cache_stats.hits,
            misses = cache_stats.misses,
            total_requests = cache_stats.total_requests,
            hit_rate = hit_rate,
            last_cleanup = cache_stats.last_cleanup
        },
        parser_cache = parser_stats,
        memory_usage = utils.get_memory_usage()
    }
end

--============================================================================
-- 工具函数
--============================================================================

--- 获取版本信息
---@return string version 版本号
function M.get_version()
    return constants.VERSION
end

--- 预热缓存（可选的性能优化）
---@param templates table 模板列表
---@param options? table 选项配置
function M.warm_cache(templates, options)
    if type(templates) ~= "table" then
        return
    end
    
    options = constants.merge_options(options or {})
    
    for _, template in ipairs(templates) do
        if type(template) == "string" then
            -- 编译但不执行，只是为了缓存
            M.compile(template, options)
        end
    end
end

--- 健康检查
---@return table health 健康状态
function M.health_check()
    local memory_over_threshold, current_memory = utils.check_memory_threshold()
    
    return {
        version = constants.VERSION,
        memory_usage = current_memory,
        memory_warning = memory_over_threshold,
        cache_stats = M.get_cache_stats(),
        modules_loaded = {
            constants = constants ~= nil,
            utils = utils ~= nil,
            parser = parser ~= nil,
            handlers = handlers ~= nil
        }
    }
end

return M
