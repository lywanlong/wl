--- 字符串解析过滤器
local M = {}

local filters = {}
local orders = {}

-- 导入扩展的 UTF-8 库
local utf8_ext = require('wl.util.utf8')


--- 添加过滤器
--- @param name string             -- 过滤器名称
--- @param func fun(str: string, ...): string  -- 过滤器函数
--- @param sort_order integer?     -- 排序顺序，数字越大越后处理
function M.add_filter(name, func, sort_order)
    filters[name] = func
    orders[name] = sort_order or 0
end

--- 首字母大写
M.add_filter('capitalize', function(str)
    if type(str) == "string" and #str > 0 then
        return str:sub(1, 1):upper() .. str:sub(2)
    end
    return tostring(str)
end)

-- 去除前后空白
M.add_filter('trim', function(str)
    if type(str) == "string" then
        return str:match("^%s*(.-)%s*$")
    end
    return tostring(str)
end)

-- 转换为数字
M.add_filter('tonumber', function(str)
    local num = tonumber(str)
    return tostring(num or 0)
end)

-- 颜色修饰器
M.add_filter('color',function (str, color)
    return string.format("%s%s#E", color, str)
end, 100)

-- 转小写
M.add_filter('lower', function(str)
    return string.lower(str)
end)

-- 转大写
M.add_filter('upper', function(str)
    return string.upper(str)
end)

-- 格式化（如 format="玩家：%s"）
M.add_filter('format', function(str, fmt)
    return string.format(fmt, str)
end)

-- 默认值
M.add_filter('default', function(str, def)
    if str == nil or str == "" then
        return def
    end
    return str
end)

-- 长度/计数
M.add_filter('length', function(str)
    if type(str) == "table" then
        return tostring(#str)
    elseif type(str) == "string" then
        return tostring(utf8_ext.char_count(str))
    else
        return "0"
    end
end)

-- 截取字符串
M.add_filter('truncate', function(str, len)
    len = math.floor(tonumber(len) or 50)
    if type(str) == "string" and utf8_ext.char_count(str) > len then
        return utf8_ext.truncate(str, len) .. "..."
    end
    return tostring(str or "")
end)

-- 替换
M.add_filter('replace', function(str, old, new)
    if type(str) == "string" and old and new then
        local result, _ = str:gsub(tostring(old), tostring(new))
        return result
    end
    return tostring(str or "")
end)

-- 首字母大写
M.add_filter('capitalize', function(str)
    if type(str) == "string" and #str > 0 then
        return str:sub(1, 1):upper() .. str:sub(2):lower()
    end
    return tostring(str or "")
end)

-- 去除空格
M.add_filter('trim', function(str)
    if type(str) == "string" then
        return str:match("^%s*(.-)%s*$") or str
    end
    return tostring(str or "")
end)

-- 转换为数字
M.add_filter('tonumber', function(str)
    local num = tonumber(str)
    return tostring(num or 0)
end)

-- JSON 序列化（简单版）
M.add_filter('json', function(obj)
    if type(obj) == "table" then
        local pairs_func = pairs
        local result = {}
        table.insert(result, "{")
        local first = true
        for k, v in pairs_func(obj) do
            if not first then table.insert(result, ",") end
            first = false
            table.insert(result, string.format('"%s":', tostring(k)))
            if type(v) == "string" then
                table.insert(result, string.format('"%s"', v))
            else
                table.insert(result, tostring(v))
            end
        end
        table.insert(result, "}")
        return table.concat(result)
    end
    return tostring(obj)
end)

-- UTF-8 扩展过滤器

-- 字符串反转（按字符反转，支持中文）
M.add_filter('reverse', function(str)
    if type(str) == "string" then
        return utf8_ext.reverse(str)
    end
    return tostring(str or "")
end)

-- 字符串分割
M.add_filter('split', function(str, delimiter)
    if type(str) == "string" and delimiter then
        local parts = utf8_ext.split(str, tostring(delimiter))
        return table.concat(parts, ", ")
    end
    return tostring(str or "")
end)

-- 字符串填充（左对齐）
M.add_filter('pad_left', function(str, width, fill_char)
    width = math.floor(tonumber(width) or 10)
    fill_char = fill_char or " "
    if type(str) == "string" then
        return utf8_ext.pad(str, width, fill_char, "left")
    end
    return tostring(str or "")
end)

-- 字符串填充（右对齐）
M.add_filter('pad_right', function(str, width, fill_char)
    width = math.floor(tonumber(width) or 10)
    fill_char = fill_char or " "
    if type(str) == "string" then
        return utf8_ext.pad(str, width, fill_char, "right")
    end
    return tostring(str or "")
end)

-- 字符串填充（居中对齐）
M.add_filter('pad_center', function(str, width, fill_char)
    width = math.floor(tonumber(width) or 10)
    fill_char = fill_char or " "
    if type(str) == "string" then
        return utf8_ext.pad(str, width, fill_char, "center")
    end
    return tostring(str or "")
end)

-- 获取指定位置的字符
M.add_filter('char_at', function(str, pos)
    pos = math.floor(tonumber(pos) or 1)
    if type(str) == "string" then
        return utf8_ext.char_at(str, pos) or ""
    end
    return ""
end)

-- 子字符串提取（按字符位置）
M.add_filter('substr', function(str, start_pos, end_pos)
    start_pos = math.floor(tonumber(start_pos) or 1)
    local end_pos_num = end_pos and tonumber(end_pos)
    end_pos_num = end_pos_num and math.floor(end_pos_num) or nil
    if type(str) == "string" then
        return utf8_ext.sub(str, start_pos, end_pos_num)
    end
    return tostring(str or "")
end)

-- 验证是否为有效 UTF-8
M.add_filter('is_valid_utf8', function(str)
    if type(str) == "string" then
        return utf8_ext.isvalid(str) and "true" or "false"
    end
    return "false"
end)

-- 数学运算过滤器

-- 加法
M.add_filter('add', function(str, value)
    local num1 = tonumber(str) or 0
    local num2 = tonumber(value) or 0
    return tostring(num1 + num2)
end)

-- 减法
M.add_filter('sub', function(str, value)
    local num1 = tonumber(str) or 0
    local num2 = tonumber(value) or 0
    return tostring(num1 - num2)
end)

-- 乘法
M.add_filter('mult', function(str, value)
    local num1 = tonumber(str) or 0
    local num2 = tonumber(value) or 1
    return tostring(num1 * num2)
end)

-- 除法
M.add_filter('div', function(str, value)
    local num1 = tonumber(str) or 0
    local num2 = tonumber(value) or 1
    if num2 == 0 then return "Error: Division by zero" end
    return tostring(math.floor(num1 / num2))
end)

-- 求余
M.add_filter('mod', function(str, value)
    local num1 = tonumber(str) or 0
    local num2 = tonumber(value) or 1
    if num2 == 0 then return "0" end
    return tostring(num1 % num2)
end)

-- 最大值
M.add_filter('max', function(str, value)
    local num1 = tonumber(str) or 0
    local num2 = tonumber(value) or 0
    return tostring(math.max(num1, num2))
end)

-- 最小值
M.add_filter('min', function(str, value)
    local num1 = tonumber(str) or 0
    local num2 = tonumber(value) or 0
    return tostring(math.min(num1, num2))
end)

-- 数字格式化（添加千分位分隔符）
M.add_filter('format_number', function(str)
    local num = tonumber(str)
    if not num then return str end
    
    local formatted = tostring(math.floor(num))
    local len = #formatted
    if len > 3 then
        local result = {}
        for i = len, 1, -1 do
            table.insert(result, 1, formatted:sub(i, i))
            if (len - i + 1) % 3 == 0 and i > 1 then
                table.insert(result, 1, ",")
            end
        end
        return table.concat(result)
    end
    return formatted
end)

--- 获取过滤器的排序顺序
--- @param name string
--- @return integer
function M.get_sort_order(name)
    return orders[name] or 0
end

--- 获取过滤器
--- @param name string
--- @return fun(str: string, ...): string
function M.get_filter(name)
    return filters[name]
end

return M