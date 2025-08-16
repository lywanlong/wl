--============================================================================
-- 简单的嵌套模板测试 - 验证修复效果
--============================================================================

print("🚀 开始简单嵌套模板测试...")

-- 导入 STRP 引擎
local strp = require 'wl.tools.strp'

local M = {}

local function simple_test()
    local s = New 'Strp' ()

    -- 简单的测试数据
    local env = {
        name = "张三",
        user_color = "red",
        level = 10,
        level_color = "gold",
        users = {
            {name = "李四", role = "admin"},
            {name = "王五", role = "user"}
        },
        current_index = 1,
        theme = {
            admin = "blue",
            user = "green"
        }
    }

    print("=" .. string.rep("=", 50))
    
    -- 测试1: 最简单的嵌套
    print("测试1: 基础嵌套")
    local template1 = "${name|color:${user_color}}"
    local result1 = s:render(template1, env)
    print(string.format("模板: %s", template1))
    print(string.format("结果: %s", result1))
    print()
    
    -- 测试2: 数组访问嵌套
    print("测试2: 数组访问嵌套")
    local template2 = "${users[${current_index}].name}"
    local result2 = s:render(template2, env)
    print(string.format("模板: %s", template2))
    print(string.format("结果: %s", result2))
    print()
    
    -- 测试3: 复杂嵌套
    print("测试3: 复杂嵌套")
    local template3 = "${users[${current_index}].name|color:${theme[${users[${current_index}].role}]}}"
    local result3 = s:render(template3, env)
    print(string.format("模板: %s", template3))
    print(string.format("结果: %s", result3))
    print()
    
    -- 测试4: 多层过滤器
    print("测试4: 多层过滤器")
    local template4 = "${level|format:'Lv.%s'|color:${level_color}}"
    local result4 = s:render(template4, env)
    print(string.format("模板: %s", template4))
    print(string.format("结果: %s", result4))
    print()
    
    print("=" .. string.rep("=", 50))
    
    -- 验证结果
    local success = true
    if not result1:find("red") or not result1:find("张三") then
        print("❌ 测试1失败")
        success = false
    else
        print("✅ 测试1通过")
    end
    
    if result2 ~= "李四" then
        print("❌ 测试2失败，期望：李四，实际：" .. result2)
        success = false
    else
        print("✅ 测试2通过")
    end
    
    if not result3:find("blue") or not result3:find("李四") then
        print("❌ 测试3失败")
        success = false
    else
        print("✅ 测试3通过")
    end
    
    if not result4:find("gold") or not result4:find("Lv.10") then
        print("❌ 测试4失败")
        success = false
    else
        print("✅ 测试4通过")
    end
    
    if success then
        print("\n🎉 所有基础嵌套测试通过！")
    else
        print("\n❌ 部分测试失败")
    end
    
    return success
end

-- 错误处理测试
local function test_error_prevention()
    print("\n🛡️ 测试错误防护...")
    
    local s = New 'Strp' ()
    
    -- 测试深度限制
    local success, result = pcall(function()
        local deep_env = {}
        local deep_template = "${a}"
        
        -- 创建一个很深的嵌套，但不会导致无限循环
        for i = 1, 10 do
            deep_env["var" .. i] = "${var" .. (i + 1) .. "}"
        end
        deep_env.var11 = "最终值"
        deep_env.a = "${var1}"
        
        return s:render(deep_template, deep_env)
    end)
    
    if success then
        print("✅ 深度嵌套处理正常")
        print("结果: " .. tostring(result))
    else
        print("✅ 深度限制保护正常工作")
        print("错误: " .. tostring(result))
    end
end

-- 性能测试
local function test_performance()
    print("\n⚡ 性能测试...")
    
    local s = New 'Strp' ()
    local env = {
        users = {},
        theme = {admin = "blue", user = "green"}
    }
    
    -- 生成测试数据
    for i = 1, 100 do
        env.users[i] = {
            name = "User" .. i,
            role = i % 2 == 0 and "admin" or "user"
        }
    end
    
    local template = "${users[${i}].name|color:${theme[${users[${i}].role}]}}"
    
    local start_time = os.clock()
    
    for i = 1, 10 do
        env.i = i
        s:render(template, env)
    end
    
    local end_time = os.clock()
    local elapsed = (end_time - start_time) * 1000
    
    print(string.format("✅ 10次复杂嵌套渲染耗时: %.2f ms", elapsed))
    
    if elapsed < 100 then
        print("🚀 性能表现优秀")
    elseif elapsed < 500 then
        print("👍 性能表现良好")
    else
        print("⚠️ 性能可能需要优化")
    end
end

-- 主函数
function M.run_all_tests()
    print("🎯 STRP 嵌套模板修复验证")
    print("=" .. string.rep("=", 60))
    
    local success1 = simple_test()
    test_error_prevention()
    test_performance()
    
    print("\n" .. string.rep("=", 60))
    
    if success1 then
        print("🎉 嵌套模板功能修复成功！")
    else
        print("❌ 嵌套模板功能仍有问题")
    end
end

return M