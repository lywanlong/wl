--============================================================================
-- STRP 模板引擎 - 基于 Y3 Class 的实现 v3.0
--
-- 这是一个功能强大的模板引擎，支持：
-- • 变量替换：${variable}
-- • 嵌套模板：${var|filter:${nested_var}}
-- • 控制结构：if, for, while, with, try-catch, switch
-- • 宏定义：macro
-- • 过滤器链：${variable|filter1|filter2:arg}
-- • 包含文件：{% include "path" %}
-- • 注释：{# comment #}
-- • 独立实例缓存：每个实例拥有独立的缓存系统
-- • 模板注册管理：支持命名模板的注册和管理
--
-- 设计特点：
-- • 基于 Y3 Class 系统的面向对象设计
-- • 每个实例独立的缓存系统
-- • 类型安全，完善的错误处理
-- • 支持嵌套结构和复杂表达式
-- • 高性能优化和内存管理
--============================================================================

-- 导入核心模块
local constants = require 'wl.tools.strp.constants'
local utils = require 'wl.tools.strp.utils'
local parser = require 'wl.tools.strp.parser'
local handlers = require 'wl.tools.strp.handlers'

---@class StrpRenderOptions
---@field cache? boolean 是否启用缓存，默认为 true
---@field debug? boolean 是否启用调试模式，默认为 false
---@field recursive? boolean 是否启用递归渲染，默认为 false
---@field max_recursive_depth? integer 最大递归深度，默认为 10

-- 声明 STRP 类
---@class Strp
---@overload fun(options?: StrpRenderOptions): Strp
---@field options StrpRenderOptions 实例配置
---@field template_cache table 模板缓存存储
---@field cache_access_time table 缓存访问时间记录
---@field template_registry table<string, string> 命名模板注册表
---@field cache_stats table 缓存性能统计
---@field error_handler function 错误处理器
local M = Class 'Strp'


Extends('Strp', 'GCHost')

--============================================================================
-- 实例初始化
--============================================================================

--- STRP 引擎初始化
---@param options? StrpRenderOptions 初始化选项
function M:__init(options)
    -- 实例配置
    self.options = constants.merge_options(options or {})
    
    -- 实例专属缓存系统
    self.template_cache = {}        -- 模板缓存存储
    self.cache_access_time = {}     -- 缓存访问时间记录（用于LRU淘汰）
    self.template_registry = {}     -- 命名模板注册表
    
    -- 缓存性能统计
    self.cache_stats = {
        hits = 0,           -- 缓存命中次数
        misses = 0,         -- 缓存未命中次数
        total_requests = 0, -- 总请求次数
        cache_size = 0,     -- 当前缓存大小
        last_cleanup = 0    -- 最后清理时间
    }
    
    -- 错误处理器
    self.error_handler = self:create_error_handler(self.options)
end

--- 析构函数
function M:__del()
    self:clear_cache()
    self.template_registry = nil
end


--============================================================================
-- 缓存系统方法
--============================================================================

--- 生成缓存键
---@param template string 模板字符串
---@param options? table 选项参数
---@return string cache_key 缓存键
function M:generate_cache_key(template, options)
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
function M:cleanup_cache()
    local current_time = os.time()
    local cache_size = 0
    
    -- 计算当前缓存大小
    for _ in pairs(self.template_cache) do
        cache_size = cache_size + 1
    end
    
    self.cache_stats.cache_size = cache_size
    
    -- 检查是否需要清理
    if cache_size <= constants.CACHE.MAX_ENTRIES then
        return
    end
    
    -- 收集所有缓存项及其访问时间
    local cache_items = {}
    for key, _ in pairs(self.template_cache) do
        table.insert(cache_items, {
            key = key,
            access_time = self.cache_access_time[key] or 0
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
        self.template_cache[key] = nil
        self.cache_access_time[key] = nil
    end
    
    self.cache_stats.last_cleanup = current_time
end

--- 自动清理过期缓存
function M:auto_cleanup()
    local current_time = os.time()
    local cleanup_interval = constants.CACHE.CLEANUP_INTERVAL
    
    if current_time - self.cache_stats.last_cleanup > cleanup_interval then
        self:cleanup_cache()
    end
end

--============================================================================
-- 错误处理
--============================================================================

--- 创建错误处理器
---@param options table 选项配置
---@return function error_handler 错误处理函数
function M:create_error_handler(options)
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

--- 安全执行函数
---@param func function 要执行的函数
---@return boolean success 是否成功
---@return any result 执行结果或错误信息
function M:safe_execute(func)
    local success, result = pcall(func)
    
    if not success then
        result = self.error_handler(result)
    end
    
    return success, result
end

--============================================================================
-- 模板编译
--============================================================================

--- 编译模板为可执行函数
---@param template string 模板字符串
---@param options? table 编译选项
---@return function|nil compiled_template 编译后的模板函数
---@return string|nil error_msg 错误信息
function M:compile(template, options)
    if type(template) ~= "string" then
        return nil, self.error_handler("模板必须是字符串类型")
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
    
    -- 编译模板
    local compiled_template = function(env)
        env = env or {}
        
        local success, result = self:safe_execute(function()
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
        end)
        
        if success then
            return result
        else
            return self.error_handler(result)
        end
    end
    
    return compiled_template, nil
end

--============================================================================
-- 主要渲染方法
--============================================================================

--- 渲染模板（主要API）
---@param template string 模板字符串
---@param env table 环境变量表
---@param options? StrpRenderOptions 渲染选项
---@return string result 渲染结果
function M:render(template, env, options)
    -- 参数验证
    if type(template) ~= "string" then
        return self.error_handler("模板必须是字符串类型")
    end
    
    env = env or {}
    options = constants.merge_options(options or {})
    
    -- 默认启用缓存
    local use_cache = options.cache ~= false
    
    -- 性能监控
    local start_time = os.clock()
    
    local compiled_template, compile_error
    
    if use_cache then
        -- 缓存模式
        -- 生成缓存键
        local cache_key = self:generate_cache_key(template, options)
        
        -- 检查缓存
        self.cache_stats.total_requests = self.cache_stats.total_requests + 1
        
        if self.template_cache[cache_key] then
            -- 缓存命中
            self.cache_stats.hits = self.cache_stats.hits + 1
            self.cache_access_time[cache_key] = os.time()
            compiled_template = self.template_cache[cache_key]
        else
            -- 缓存未命中，编译模板
            self.cache_stats.misses = self.cache_stats.misses + 1
            
            compiled_template, compile_error = self:compile(template, options)
            if not compiled_template then
                error(compile_error or "模板编译失败")
            end
            
            -- 存入缓存
            self.template_cache[cache_key] = compiled_template
            self.cache_access_time[cache_key] = os.time()
            
            -- 自动清理缓存
            self:auto_cleanup()
        end
    else
        -- 非缓存模式，直接编译
        compiled_template, compile_error = self:compile(template, options)
        if not compiled_template then
            error(compile_error or "模板编译失败")
        end
    end
    
    -- 执行渲染
    local result = compiled_template(env)
    
    -- 递归渲染
    if options.recursive then
        local max_depth = options.max_recursive_depth or 10
        local depth = options._current_depth or 0
        
        if depth < max_depth then
            -- 检查结果中是否还包含模板变量
            if result:find('%${.+}') then
                -- 创建新的选项，增加深度计数器
                local recursive_options = {}
                for k, v in pairs(options) do
                    recursive_options[k] = v
                end
                recursive_options._current_depth = depth + 1
                
                -- 递归渲染
                result = self:render(result, env, recursive_options)
            end
        elseif options.debug then
            print(string.format("[STRP] 警告: 达到最大递归深度 %d", max_depth))
        end
    end
    
    -- 性能统计
    local end_time = os.clock()
    local render_time = (end_time - start_time) * 1000
    
    if options.debug then
        local cache_status = use_cache and "cached" or "direct"
        print(string.format("[STRP] 渲染耗时: %.2f ms (%s)", render_time, cache_status))
    end
    
    return result
end

--============================================================================
-- 模板注册系统
--============================================================================

--- 注册一个命名模板
---@param name string 模板名称
---@param template string 模板内容
---@return string|nil result 如果发生错误，返回错误信息或空字符串
function M:register_template(name, template)
    if type(name) ~= "string" or type(template) ~= "string" then
        return self.error_handler("模板名称和内容必须是字符串类型")
    end
    
    if name == "" then
        return self.error_handler("模板名称不能为空")
    end
    
    self.template_registry[name] = template
end

--- 获取已注册的模板
---@param name string 模板名称
---@return string|nil template 模板内容，如果不存在则返回 nil
function M:get_registered_template(name)
    return self.template_registry[name]
end

--- 检查模板是否已注册
---@param name string 模板名称
---@return boolean exists 是否存在
function M:template_exists(name)
    return self.template_registry[name] ~= nil
end

--- 获取所有已注册的模板名称
---@return table names 模板名称列表
function M:list_templates()
    local names = {}
    for name in pairs(self.template_registry) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- 移除已注册的模板
---@param name string 模板名称
---@return boolean success 是否成功移除
function M:unregister_template(name)
    if self.template_registry[name] then
        self.template_registry[name] = nil
        return true
    end
    return false
end

--- 通过模板名称渲染模板
---@param template_name string 模板名称
---@param env table 环境变量表
---@param options? StrpRenderOptions 渲染选项
---@return string result 渲染结果
function M:render_by_name(template_name, env, options)
    if type(template_name) ~= "string" then
        return self.error_handler("模板名称必须是字符串类型")
    end
    
    local template = self.template_registry[template_name]
    if not template then
        return self.error_handler("未找到模板: " .. tostring(template_name))
    end
    
    return self:render(template, env, options)
end

--============================================================================
-- 缓存管理方法
--============================================================================

--- 清空所有缓存
function M:clear_cache()
    self.template_cache = {}
    self.cache_access_time = {}
    parser.clear_cache()
    
    -- 重置统计信息
    self.cache_stats = {
        hits = 0,
        misses = 0,
        total_requests = 0,
        cache_size = 0,
        last_cleanup = 0
    }
end

--- 获取缓存统计信息
---@return table stats 缓存统计
function M:get_cache_stats()
    local cache_size = 0
    for _ in pairs(self.template_cache) do
        cache_size = cache_size + 1
    end
    
    self.cache_stats.cache_size = cache_size
    
    local hit_rate = 0
    if self.cache_stats.total_requests > 0 then
        hit_rate = self.cache_stats.hits / self.cache_stats.total_requests
    end
    
    local parser_stats = nil
    local memory_usage = nil
    
    -- 安全调用 parser.get_cache_stats()
    local success1, result1 = pcall(parser.get_cache_stats)
    if success1 then
        parser_stats = result1
    else
        parser_stats = {error = "无法获取解析器缓存统计"}
    end
    
    -- 安全调用 utils.get_memory_usage()
    local success2, result2 = pcall(utils.get_memory_usage)
    if success2 then
        memory_usage = result2
    else
        memory_usage = 0
    end
    
    return {
        template_cache = {
            size = self.cache_stats.cache_size,
            hits = self.cache_stats.hits,
            misses = self.cache_stats.misses,
            total_requests = self.cache_stats.total_requests,
            hit_rate = hit_rate,
            last_cleanup = self.cache_stats.last_cleanup
        },
        parser_cache = parser_stats,
        memory_usage = memory_usage
    }
end

--============================================================================
-- 工具方法
--============================================================================

--- 获取版本信息
---@return string version 版本号
function M:get_version()
    return constants.VERSION
end

--- 预热缓存（可选的性能优化）
---@param templates table 模板列表
---@param options? table 选项配置
---@return nil
function M:warm_cache(templates, options)
    if type(templates) ~= "table" then
        return
    end
    
    options = constants.merge_options(options or {})
    -- 确保预热时启用缓存
    options.cache = true
    
    for _, template in ipairs(templates) do
        if type(template) == "string" then
            -- 渲染一次以存入缓存（使用空环境）
            self:render(template, {}, options)
        end
    end
    -- 预热后同步统计
    local cache_size = 0
    for _ in pairs(self.template_cache) do
        cache_size = cache_size + 1
    end
    self.cache_stats.cache_size = cache_size
    self.cache_stats.size = cache_size
end

--- 健康检查
---@return table health 健康状态
function M:health_check()
    local memory_over_threshold, current_memory = utils.check_memory_threshold()
    
    return {
        version = constants.VERSION,
        memory_usage = current_memory,
        memory_warning = memory_over_threshold,
        cache_stats = self:get_cache_stats(),
        modules_loaded = {
            constants = constants ~= nil,
            utils = utils ~= nil,
            parser = parser ~= nil,
            handlers = handlers ~= nil
        }
    }
end

--============================================================================
-- 便利方法
--============================================================================

--- 强制启用缓存的渲染方法
---@param template string 模板字符串
---@param env table 环境变量表
---@param options? StrpRenderOptions 其他选项
---@return string result 渲染结果
function M:render_cached(template, env, options)
    options = options or {}
    options.cache = true
    return self:render(template, env, options)
end

--- 强制禁用缓存的渲染方法
---@param template string 模板字符串
---@param env table 环境变量表
---@param options? StrpRenderOptions 其他选项
---@return string result 渲染结果
function M:render_direct(template, env, options)
    options = options or {}
    options.cache = false
    return self:render(template, env, options)
end

--============================================================================
-- 便利方法
--============================================================================

--- 创建新的 STRP 实例（静态方法）
---@param options? StrpRenderOptions 选项表
---@return Strp
function M.create(options)
    return New 'Strp' (options)
end



return M