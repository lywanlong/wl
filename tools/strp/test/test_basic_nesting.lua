-- 简单的嵌套语法测试
package.path = package.path .. ";e:\\WorkSpace\\大闯关项目\\大闯关\\maps\\EntryMap\\script\\?.lua"

local strp = require('wl.tools.strp.strp')

print("=== 基础嵌套语法测试 ===")

-- 简单测试数据
local test_data = {
    user = {
        name = "  张三  ",
        level = 95,
        vip = true,
        strength = 85
    },
    items = {
        {name = "剑", level = 100, broken = false},
        {name = "盾", level = 50, broken = true}
    }
}

-- 测试 1: 基础条件判断
print("测试 1: 基础条件判断")
local template1 = [[
用户: ${user.name|trim}
{% if user.vip %}
VIP用户: 是
{% else %}
VIP用户: 否
{% endif %}
等级评价: {% if user.level > 90 %}大师级{% else %}普通级{% endif %}
]]

local result1 = strp.render(template1, test_data)
print("结果:")
print(result1)

-- 测试 2: 基础循环
print("\n测试 2: 基础循环")
local template2 = [[
物品列表:
{% for item in items %}
- ${item.name}: 等级${item.level}{% if item.broken %} (已损坏){% endif %}
{% endfor %}
]]

local result2 = strp.render(template2, test_data)
print("结果:")
print(result2)

-- 测试 3: 嵌套条件和循环
print("\n测试 3: 嵌套条件和循环")
local template3 = [[
{% if user.level > 80 %}
高级用户装备:
{% for item in items %}
  {% if item.level > 70 %}
    ⭐ ${item.name} (等级${item.level}){% if item.broken %} - 需要修复{% endif %}
  {% endif %}
{% endfor %}
{% else %}
普通用户，建议提升等级
{% endif %}
]]

local result3 = strp.render(template3, test_data)
print("结果:")
print(result3)

-- 测试 4: 多重条件判断
print("\n测试 4: 多重条件判断")
local template4 = [[
力量评价: 
{% if user.strength > 90 %}
极强
{% elif user.strength > 70 %}
较强
{% elif user.strength > 50 %}
一般
{% else %}
较弱
{% endif %}
]]

local result4 = strp.render(template4, test_data)
print("结果:")
print(result4)

-- 测试 5: 过滤器链式调用
print("\n测试 5: 过滤器和数学运算")
local template5 = [[
用户信息:
- 姓名: ${user.name|trim|capitalize}
- 等级: ${user.level}
- 下级经验需求: ${user.level|mult:1000|format_number}
- 力量评级: ${user.strength|max:100}
]]

local result5 = strp.render(template5, test_data)
print("结果:")
print(result5)

print("\n=== 所有基础测试完成 ===")
print("如果上述结果正确显示了条件判断和循环，说明模板引擎工作正常！")
