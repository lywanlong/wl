-- 测试新增的过滤器功能
package.path = package.path .. ";e:\\WorkSpace\\大闯关项目\\大闯关\\maps\\EntryMap\\script\\?.lua"

local strp = require('wl.tools.strp.strp')

print("=== 测试新增过滤器功能 ===")

-- 测试数据
local test_data = {
    name = "  john doe  ",
    items = {"apple", "banana", "cherry"},
    count = 42,
    price = "123.45",
    long_text = "这是一个很长的文本，需要被截取以避免显示过多内容",
    json_data = "hello world",
    boolean_val = true
}

-- 测试模板
local template = [[
姓名: ${name|trim|capitalize}
项目数量: ${items|length}
计数: ${count}
价格: ${price|tonumber}
截取文本: ${long_text|truncate:20}
JSON字符串: ${json_data|json}
替换测试: ${name|trim|replace:john:Jane|capitalize}
]]

print("模板:")
print(template)
print("\n渲染结果:")

local result = strp.render(template, test_data)
print(result)

print("\n=== 单独测试各个过滤器 ===")

-- 测试 length 过滤器
print("length 过滤器:")
print("  字符串长度:", strp.render("${name|length}", {name = "hello"}))
print("  数组长度:", strp.render("${items|length}", {items = {"a", "b", "c"}}))

-- 测试 truncate 过滤器
print("\ntruncate 过滤器:")
print("  截取:", strp.render("${text|truncate:10}", {text = "这是一个很长的文本"}))

-- 测试 replace 过滤器
print("\nreplace 过滤器:")
print("  替换:", strp.render("${text|replace:old:new}", {text = "old value"}))

-- 测试 capitalize 过滤器
print("\ncapitalize 过滤器:")
print("  首字母大写:", strp.render("${text|capitalize}", {text = "hello world"}))

-- 测试 trim 过滤器
print("\ntrim 过滤器:")
print("  去空格:", strp.render("'${text|trim}'", {text = "  hello  "}))

-- 测试 tonumber 过滤器
print("\ntonumber 过滤器:")
print("  转数字:", strp.render("${text|tonumber}", {text = "123.45"}))

-- 测试 json 过滤器
print("\njson 过滤器:")
print("  JSON化:", strp.render("${text|json}", {text = 'hello "world"'}))

print("\n=== 过滤器链式调用测试 ===")
print("链式:", strp.render("${text|trim|capitalize|truncate:8}", {text = "  hello world  "}))
