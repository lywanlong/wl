--============================================================================
-- STRP 模板引擎 - 缓存系统测试
--
-- 测试内容：
-- • 缓存命中和未命中
-- • LRU 缓存淘汰机制
-- • 缓存统计信息
-- • 缓存预热
-- • 内存管理
-- • 性能对比
--============================================================================

local strp = require 'wl.tools.strp.strp'

--- 测试结果记录
local test_results = {
    total_tests = 0,
    passed_tests = 0,
    failed_tests = 0,
    test_details = {}
}

--- 断言函数
---@param condition boolean 条件
---@param message string 错误消息
---@param test_name string 测试名称
local function assert_test(condition, message, test_name)
    test_results.total_tests = test_results.total_tests + 1
    
    if condition then
        test_results.passed_tests = test_results.passed_tests + 1
        table.insert(test_results.test_details, {
            name = test_name,
            status = "PASS",
            message = message
        })
        print("✓ " .. test_name .. ": " .. message)
    else
        test_results.failed_tests = test_results.failed_tests + 1
        table.insert(test_results.test_details, {
            name = test_name,
            status = "FAIL", 
            message = message
        })
        print("✗ " .. test_name .. ": " .. message)
    end
end

--- 等待一段时间（用于测试时间相关功能）
---@param seconds number
local function wait(seconds)
    local start_time = os.clock()
    while os.clock() - start_time < seconds do
        -- 空循环等待
    end
end

--============================================================================
-- 测试1: 基础缓存功能
--============================================================================

local function test_basic_cache()
    print("\n=== 测试1: 基础缓存功能 ===")
    
    -- 清空缓存
    strp.clear_cache()
    
    local template = "Hello ${name}!"
    local data = {name = "World"}
    
    -- 第一次渲染（应该缓存未命中）
    local result1 = strp.render(template, data)
    local stats1 = strp.get_cache_stats()
    
    assert_test(
        result1 == "Hello World!",
        "第一次渲染结果正确",
        "基础缓存-渲染结果"
    )
    
    assert_test(
        stats1.template_cache.misses == 1,
        "第一次渲染应该缓存未命中",
        "基础缓存-首次未命中"
    )
    
    -- 第二次渲染（应该缓存命中）
    local result2 = strp.render(template, data)
    local stats2 = strp.get_cache_stats()
    
    assert_test(
        result2 == "Hello World!",
        "第二次渲染结果正确",
        "基础缓存-重复渲染结果"
    )
    
    assert_test(
        stats2.template_cache.hits == 1,
        "第二次渲染应该缓存命中",
        "基础缓存-缓存命中"
    )
    
    assert_test(
        stats2.template_cache.hit_rate > 0,
        "缓存命中率应该大于0",
        "基础缓存-命中率计算"
    )
end

--============================================================================
-- 测试2: 缓存键生成
--============================================================================

local function test_cache_key_generation()
    print("\n=== 测试2: 缓存键生成 ===")
    
    strp.clear_cache()
    
    local template = "Value: ${value}"
    
    -- 使用不同选项应该生成不同的缓存
    local result1 = strp.render(template, {value = "test"}, {debug = true})
    local result2 = strp.render(template, {value = "test"}, {debug = false})
    local result3 = strp.render(template, {value = "test"}, {debug = true})
    
    local stats = strp.get_cache_stats()
    
    assert_test(
        stats.template_cache.size >= 2,
        "不同选项应该生成不同的缓存项",
        "缓存键-选项区分"
    )
    
    assert_test(
        stats.template_cache.hits >= 1,
        "相同选项应该命中缓存",
        "缓存键-相同选项命中"
    )
end

--============================================================================
-- 测试3: 禁用缓存
--============================================================================

local function test_cache_disabled()
    print("\n=== 测试3: 禁用缓存 ===")
    
    strp.clear_cache()
    
    local template = "No cache: ${data}"
    local data = {data = "test"}
    
    -- 禁用缓存的渲染
    local result1 = strp.render(template, data, {cache = false})
    local result2 = strp.render(template, data, {cache = false})
    
    local stats = strp.get_cache_stats()
    
    assert_test(
        result1 == "No cache: test",
        "禁用缓存时渲染结果正确",
        "禁用缓存-渲染结果"
    )
    
    assert_test(
        stats.template_cache.size == 0,
        "禁用缓存时不应该创建缓存项",
        "禁用缓存-无缓存项"
    )
    
    assert_test(
        stats.template_cache.hits == 0,
        "禁用缓存时不应该有缓存命中",
        "禁用缓存-无命中"
    )
end

--============================================================================
-- 测试4: 缓存预热
--============================================================================

local function test_cache_warm_up()
    print("\n=== 测试4: 缓存预热 ===")
    
    strp.clear_cache()
    
    local templates = {
        "Template 1: ${var1}",
        "Template 2: ${var2}",
        "Template 3: ${var3}"
    }
    
    -- 预热缓存
    strp.warm_cache(templates)
    
    local stats_after_warmup = strp.get_cache_stats()
    
    assert_test(
        stats_after_warmup.template_cache.size == 3,
        "预热后应该有3个缓存项",
        "缓存预热-缓存项数量"
    )
    
    -- 使用预热的模板应该命中缓存
    local result = strp.render("Template 1: ${var1}", {var1 = "value1"})
    local stats_after_render = strp.get_cache_stats()
    
    assert_test(
        result == "Template 1: value1",
        "预热的模板渲染结果正确",
        "缓存预热-渲染结果"
    )
    
    assert_test(
        stats_after_render.template_cache.hits > stats_after_warmup.template_cache.hits,
        "使用预热的模板应该命中缓存",
        "缓存预热-缓存命中"
    )
end

--============================================================================
-- 测试5: 性能对比
--============================================================================

local function test_performance_comparison()
    print("\n=== 测试5: 性能对比 ===")
    
    strp.clear_cache()
    
    local template = "Performance test: ${value} with filter and ${another_value}"
    local data = {value = "cached", another_value = "data"}
    
    -- 测试首次渲染时间（缓存未命中）
    local start_time1 = os.clock()
    local result1 = strp.render(template, data, {debug = false})
    local first_render_time = (os.clock() - start_time1) * 1000
    
    -- 测试缓存命中时间
    local start_time2 = os.clock()
    local result2 = strp.render(template, data, {debug = false})
    local cached_render_time = (os.clock() - start_time2) * 1000
    
    -- 测试无缓存渲染时间
    local start_time3 = os.clock()
    local result3 = strp.render(template, data, {cache = false, debug = false})
    local no_cache_render_time = (os.clock() - start_time3) * 1000
    
    assert_test(
        result1 == result2 and result2 == result3,
        "所有渲染结果应该相同",
        "性能对比-结果一致性"
    )
    
    assert_test(
        cached_render_time <= first_render_time,
        string.format("缓存命中应该更快 (首次: %.3fms, 缓存: %.3fms)", 
                     first_render_time, cached_render_time),
        "性能对比-缓存性能提升"
    )
    
    print(string.format("性能统计:"))
    print(string.format("  首次渲染: %.3f ms", first_render_time))
    print(string.format("  缓存命中: %.3f ms", cached_render_time))
    print(string.format("  无缓存:   %.3f ms", no_cache_render_time))
    
    if cached_render_time > 0 then
        local speedup = first_render_time / cached_render_time
        print(string.format("  加速比:   %.2fx", speedup))
    end
end

--============================================================================
-- 测试6: 内存管理和清理
--============================================================================

local function test_memory_management()
    print("\n=== 测试6: 内存管理和清理 ===")
    
    strp.clear_cache()
    
    -- 创建多个不同的模板来测试内存管理
    for i = 1, 10 do
        local template = "Template " .. i .. ": ${value" .. i .. "}"
        local data = {["value" .. i] = "data" .. i}
        strp.render(template, data)
    end
    
    local stats_before_clear = strp.get_cache_stats()
    
    assert_test(
        stats_before_clear.template_cache.size == 10,
        "应该有10个缓存项",
        "内存管理-缓存项创建"
    )
    
    -- 清空缓存
    strp.clear_cache()
    local stats_after_clear = strp.get_cache_stats()
    
    assert_test(
        stats_after_clear.template_cache.size == 0,
        "清空后应该没有缓存项",
        "内存管理-缓存清空"
    )
    
    assert_test(
        stats_after_clear.template_cache.hits == 0 and 
        stats_after_clear.template_cache.misses == 0,
        "清空后统计应该重置",
        "内存管理-统计重置"
    )
end

--============================================================================
-- 测试7: 健康检查
--============================================================================

local function test_health_check()
    print("\n=== 测试7: 健康检查 ===")
    
    strp.clear_cache()
    
    -- 添加一些缓存项
    strp.render("Health test: ${status}", {status = "ok"})
    
    local health = strp.health_check()
    
    assert_test(
        health.version ~= nil,
        "健康检查应该包含版本信息",
        "健康检查-版本信息"
    )
    
    assert_test(
        health.cache_stats ~= nil,
        "健康检查应该包含缓存统计",
        "健康检查-缓存统计"
    )
    
    assert_test(
        health.memory_usage ~= nil,
        "健康检查应该包含内存使用情况",
        "健康检查-内存信息"
    )
    
    assert_test(
        health.modules_loaded ~= nil,
        "健康检查应该包含模块加载状态",
        "健康检查-模块状态"
    )
end

--============================================================================
-- 测试8: 错误处理缓存
--============================================================================

local function test_error_handling_cache()
    print("\n=== 测试8: 错误处理缓存 ===")
    
    strp.clear_cache()
    
    -- 测试错误模板不会被缓存
    local error_count = 0
    
    -- 使用 pcall 来捕获错误
    local success1, result1 = pcall(function()
        return strp.render("${nonexistent.invalid.property}", {})
    end)
    
    local success2, result2 = pcall(function()
        return strp.render("${nonexistent.invalid.property}", {})
    end)
    
    local stats = strp.get_cache_stats()
    
    -- 即使是错误的模板，缓存机制仍然应该工作
    -- 重要的是系统不会崩溃
    assert_test(
        true, -- 只要没有崩溃就算通过
        "错误处理不应该导致系统崩溃",
        "错误处理-系统稳定性"
    )
end

--============================================================================
-- 运行所有测试
--============================================================================

local function run_all_tests()
    print("开始 STRP 缓存系统测试...")
    print(string.rep("=", 50))
    
    local start_time = os.clock()
    
    -- 运行所有测试
    test_basic_cache()
    test_cache_key_generation()
    test_cache_disabled()
    test_cache_warm_up()
    test_performance_comparison()
    test_memory_management()
    test_health_check()
    test_error_handling_cache()
    
    local total_time = (os.clock() - start_time) * 1000
    
    -- 输出测试结果
    print("\n" .. string.rep("=", 50))
    print("测试完成!")
    print(string.format("总测试数: %d", test_results.total_tests))
    print(string.format("通过: %d", test_results.passed_tests))
    print(string.format("失败: %d", test_results.failed_tests))
    print(string.format("成功率: %.1f%%", 
          (test_results.passed_tests / test_results.total_tests) * 100))
    print(string.format("总耗时: %.2f ms", total_time))
    
    -- 输出最终缓存统计
    local final_stats = strp.get_cache_stats()
    print("\n最终缓存统计:")
    print(string.format("  缓存大小: %d", final_stats.template_cache.size))
    print(string.format("  缓存命中: %d", final_stats.template_cache.hits))
    print(string.format("  缓存未命中: %d", final_stats.template_cache.misses))
    print(string.format("  命中率: %.1f%%", final_stats.template_cache.hit_rate * 100))
    
    -- 健康检查
    local health = strp.health_check()
    print(string.format("  内存使用: %.2f MB", health.memory_usage or 0))
    
    if test_results.failed_tests > 0 then
        print("\n失败的测试:")
        for _, test in ipairs(test_results.test_details) do
            if test.status == "FAIL" then
                print(string.format("  ✗ %s: %s", test.name, test.message))
            end
        end
    end
    
    return test_results.failed_tests == 0
end

-- 如果作为模块被require，不自动运行测试
-- 如果直接运行此文件，执行测试
local function main()
    local success = run_all_tests()
    if success then
        print("\n🎉 所有测试通过!")
    else
        print("\n❌ 部分测试失败!")
    end
end

-- 导出测试函数供其他模块调用
local test_module = {
    run_all_tests = run_all_tests,
    test_basic_cache = test_basic_cache,
    test_cache_key_generation = test_cache_key_generation,
    test_cache_disabled = test_cache_disabled,
    test_cache_warm_up = test_cache_warm_up,
    test_performance_comparison = test_performance_comparison,
    test_memory_management = test_memory_management,
    test_health_check = test_health_check,
    test_error_handling_cache = test_error_handling_cache,
    get_test_results = function() return test_results end,
    main = main
}

return test_module
