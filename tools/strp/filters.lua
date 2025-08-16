--- 字符串解析过滤器
local M = {}

local filters = {}
local orders = {}

-- 导入扩展的 UTF-8 库
local utf8_ext = require('wl.util.utf8')


--- 添加过滤器
--- @param name string             -- 过滤器名称
--- @param func fun(value: any, ...): any  -- 过滤器函数，可以返回任意类型
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

--============================================================================
-- 默认值过滤器
--============================================================================

-- 提供默认值
-- 当值为 nil、空字符串或空白字符串时，使用默认值
-- 用法：${variable|default:"默认值"} 或 ${variable|default:fallback_var}
M.add_filter('default', function(value, default_value)
    -- 检查值是否为空或需要替换
    if value == nil then
        return default_value or ""
    end
    
    if type(value) == "string" then
        if value == "" or value:match("^%s*$") then
            return default_value or ""
        end
    end
    
    return value
end)

-- 提供非空默认值（只有当值为 nil 时才使用默认值）
-- 用法：${variable|default_if_nil:"默认值"}
M.add_filter('default_if_nil', function(value, default_value)
    if value == nil then
        return default_value or ""
    end
    return value
end)

-- 提供非空字符串默认值（当值为 nil 或空字符串时使用默认值）
-- 用法：${variable|default_if_empty:"默认值"}
M.add_filter('default_if_empty', function(value, default_value)
    if value == nil or value == "" then
        return default_value or ""
    end
    return value
end)

--============================================================================
-- 日期时间过滤器
--============================================================================

-- 格式化日期时间
M.add_filter('date', function(timestamp, format)
    if not timestamp then return "" end
    
    local num_timestamp = tonumber(timestamp)
    if not num_timestamp then return tostring(timestamp) end
    
    format = format or "Y-m-d H:i:s"
    
    -- 支持标准的strftime格式（%Y-%m-%d）
    if format:match("%%") then
        return os.date(format, math.floor(num_timestamp))
    end
    
    local date_table = os.date("*t", math.floor(num_timestamp))
    if not date_table then return tostring(timestamp) end
    
    -- 格式化替换映射（自定义格式）
    local format_map = {
        Y = string.format("%04d", date_table.year),
        m = string.format("%02d", date_table.month),
        d = string.format("%02d", date_table.day),
        H = string.format("%02d", date_table.hour),
        i = string.format("%02d", date_table.min),
        s = string.format("%02d", date_table.sec),
        y = string.format("%02d", date_table.year % 100),
        M = os.date("%b", math.floor(num_timestamp)), -- 月份缩写
        D = os.date("%a", math.floor(num_timestamp)), -- 星期缩写
    }
    
    local result = format
    for pattern, replacement in pairs(format_map) do
        result = result:gsub(pattern, replacement)
    end
    
    return result
end)

-- 解析日期字符串
M.add_filter('strptime', function(date_str, format)
    if not date_str or not format then return "0" end
    
    -- 简化实现：只支持基本的日期格式
    local year, month, day = date_str:match("(%d%d%d%d)-(%d%d)-(%d%d)")
    if year and month and day then
        local timestamp = os.time({
            year = math.floor(tonumber(year) or 0),
            month = math.floor(tonumber(month) or 0),
            day = math.floor(tonumber(day) or 0),
            hour = 0,
            min = 0,
            sec = 0
        })
        return tostring(timestamp or 0)
    end
    
    return "0"
end)

-- 相对时间显示
M.add_filter('timeago', function(timestamp)
    local num_timestamp = tonumber(timestamp)
    if not num_timestamp then return tostring(timestamp) end
    
    local now = os.time()
    local diff = now - num_timestamp
    
    if diff < 60 then
        return "刚刚"
    elseif diff < 3600 then
        return string.format("%d分钟前", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d小时前", math.floor(diff / 3600))
    elseif diff < 2592000 then
        return string.format("%d天前", math.floor(diff / 86400))
    else
        return string.format("%d个月前", math.floor(diff / 2592000))
    end
end)

-- 计算时长
M.add_filter('duration', function(start_time, end_time)
    local start_num = tonumber(start_time)
    local end_num = tonumber(end_time)
    
    if not start_num or not end_num then return "0秒" end
    
    local diff = math.abs(end_num - start_num)
    
    if diff < 60 then
        return string.format("%d秒", diff)
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        local seconds = diff % 60
        return string.format("%d分%d秒", minutes, seconds)
    else
        local hours = math.floor(diff / 3600)
        local minutes = math.floor((diff % 3600) / 60)
        return string.format("%d小时%d分", hours, minutes)
    end
end)

--============================================================================
-- 数学运算过滤器
--============================================================================

-- 数组求和
M.add_filter('sum', function(numbers)
    if type(numbers) ~= "table" then return "0" end
    
    local total = 0
    for _, v in ipairs(numbers) do
        local num = tonumber(v)
        if num then
            total = total + num
        end
    end
    
    return tostring(total)
end)

-- 平均值
M.add_filter('avg', function(numbers)
    if type(numbers) ~= "table" or #numbers == 0 then return "0" end
    
    local total = 0
    local count = 0
    for _, v in ipairs(numbers) do
        local num = tonumber(v)
        if num then
            total = total + num
            count = count + 1
        end
    end
    
    if count == 0 then return "0" end
    return tostring(total / count)
end)

-- 中位数
M.add_filter('median', function(numbers)
    if type(numbers) ~= "table" or #numbers == 0 then return "0" end
    
    local nums = {}
    for _, v in ipairs(numbers) do
        local num = tonumber(v)
        if num then
            table.insert(nums, num)
        end
    end
    
    if #nums == 0 then return "0" end
    
    table.sort(nums)
    local mid = math.ceil(#nums / 2)
    
    if #nums % 2 == 0 then
        return tostring((nums[mid] + nums[mid + 1]) / 2)
    else
        return tostring(nums[mid])
    end
end)

-- 四舍五入
M.add_filter('round', function(value, decimal_places)
    local num = tonumber(value)
    if not num then return tostring(value) end
    
    decimal_places = tonumber(decimal_places) or 0
    local multiplier = 10 ^ decimal_places
    
    return tostring(math.floor(num * multiplier + 0.5) / multiplier)
end)

-- 正弦函数
M.add_filter('sin', function(value)
    local num = tonumber(value)
    if not num then return "0" end
    
    return tostring(math.sin(num))
end)

-- 余弦函数
M.add_filter('cos', function(value)
    local num = tonumber(value)
    if not num then return "0" end
    
    return tostring(math.cos(num))
end)

-- 正切函数
M.add_filter('tan', function(value)
    local num = tonumber(value)
    if not num then return "0" end
    
    return tostring(math.tan(num))
end)

--============================================================================
-- 集合操作过滤器
--============================================================================

-- 数组并集
M.add_filter('union', function(list1, list2)
    if type(list1) ~= "table" then list1 = {} end
    if type(list2) ~= "table" then list2 = {} end
    
    local seen = {}
    local result = {}
    
    -- 添加第一个列表的元素
    for _, v in ipairs(list1) do
        if not seen[v] then
            seen[v] = true
            table.insert(result, v)
        end
    end
    
    -- 添加第二个列表的元素
    for _, v in ipairs(list2) do
        if not seen[v] then
            seen[v] = true
            table.insert(result, v)
        end
    end
    
    return result
end)

-- 数组交集
M.add_filter('intersect', function(list1, list2)
    if type(list1) ~= "table" or type(list2) ~= "table" then return {} end
    
    local set2 = {}
    for _, v in ipairs(list2) do
        set2[v] = true
    end
    
    local result = {}
    for _, v in ipairs(list1) do
        if set2[v] then
            table.insert(result, v)
        end
    end
    
    return result
end)

-- 数组去重
M.add_filter('unique', function(list)
    if type(list) ~= "table" then return {} end
    
    local seen = {}
    local result = {}
    
    for _, v in ipairs(list) do
        if not seen[v] then
            seen[v] = true
            table.insert(result, v)
        end
    end
    
    return result
end)

-- 按属性排序
M.add_filter('sort', function(list, key)
    if type(list) ~= "table" then return {} end
    
    local result = {}
    for _, v in ipairs(list) do
        table.insert(result, v)
    end
    
    if key then
        table.sort(result, function(a, b)
            local a_val = type(a) == "table" and a[key] or a
            local b_val = type(b) == "table" and b[key] or b
            return tostring(a_val or "") < tostring(b_val or "")
        end)
    else
        table.sort(result, function(a, b)
            return tostring(a or "") < tostring(b or "")
        end)
    end
    
    return result
end)

-- 按属性分组
M.add_filter('group_by', function(list, key)
    if type(list) ~= "table" then return {} end
    
    local groups = {}
    for _, item in ipairs(list) do
        local group_key = type(item) == "table" and item[key] or tostring(item)
        if not groups[group_key] then
            groups[group_key] = {}
        end
        table.insert(groups[group_key], item)
    end
    
    return groups
end)

--============================================================================
-- 文本处理过滤器
--============================================================================

-- 词数统计
M.add_filter('word_count', function(text)
    if type(text) ~= "string" then return "0" end
    
    local count = 0
    for word in text:gmatch("%S+") do
        count = count + 1
    end
    
    return tostring(count)
end)

-- 字符数统计
M.add_filter('char_count', function(text)
    if type(text) ~= "string" then return "0" end
    
    return tostring(utf8_ext.len(text) or #text)
end)

-- 行数统计
M.add_filter('line_count', function(text)
    if type(text) ~= "string" then return "0" end
    
    local count = 1
    for _ in text:gmatch("\n") do
        count = count + 1
    end
    
    return tostring(count)
end)

--============================================================================
-- 游戏特定过滤器
--============================================================================

-- 进度条过滤器
M.add_filter('progress_bar', function(current, max_value, width)
    local curr = tonumber(current) or 0
    local max_val = tonumber(max_value) or 100
    local bar_width = tonumber(width) or 10
    
    if max_val == 0 then max_val = 1 end -- 避免除零
    
    local percentage = math.max(0, math.min(1, curr / max_val))
    local filled_chars = math.floor(percentage * bar_width)
    local empty_chars = bar_width - filled_chars
    
    local filled = string.rep("█", filled_chars)
    local empty = string.rep("░", math.floor(empty_chars))
    
    return string.format("%s%s %d/%d", filled, empty, curr, max_val)
end)



--============================================================================
-- 字符串操作过滤器（返回非字符串类型）
--============================================================================

-- 字符串分割（返回数组）
M.add_filter('split', function(str, delimiter)
    if type(str) ~= "string" or not delimiter then 
        return {}
    end
    
    local result = {}
    local pattern = "(.-)" .. delimiter:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    local last_end = 1
    local s, e = str:find(delimiter, 1, true)
    
    while s do
        if s ~= 1 or last_end ~= 1 then
            table.insert(result, str:sub(last_end, s - 1))
        end
        last_end = e + 1
        s, e = str:find(delimiter, last_end, true)
    end
    
    if last_end <= #str then
        table.insert(result, str:sub(last_end))
    end
    
    return result
end)

-- 提取数字数组
M.add_filter('extract_numbers', function(str)
    if type(str) ~= "string" then return {} end
    
    local numbers = {}
    for num in str:gmatch("%-?%d+%.?%d*") do
        local parsed = tonumber(num)
        if parsed then
            table.insert(numbers, parsed)
        end
    end
    
    return numbers
end)

-- 字符串转字符数组
M.add_filter('to_chars', function(str)
    if type(str) ~= "string" then return {} end
    
    local chars = {}
    for i = 1, utf8_ext.len(str) or #str do
        local char = utf8_ext.char_at(str, i) or str:sub(i, i)
        table.insert(chars, char)
    end
    
    return chars
end)

--============================================================================
-- 统计分析过滤器（返回数值类型）
--============================================================================

-- 最大值过滤器（用于数组）
M.add_filter('max_value', function(list)
    if type(list) ~= "table" or #list == 0 then return 0 end
    
    local max_val = tonumber(list[1]) or 0
    for i = 2, #list do
        local val = tonumber(list[i]) or 0
        if val > max_val then
            max_val = val
        end
    end
    
    return max_val
end)

-- 最小值过滤器（用于数组）
M.add_filter('min_value', function(list)
    if type(list) ~= "table" or #list == 0 then return 0 end
    
    local min_val = tonumber(list[1]) or 0
    for i = 2, #list do
        local val = tonumber(list[i]) or 0
        if val < min_val then
            min_val = val
        end
    end
    
    return min_val
end)

-- 标准差
M.add_filter('std_dev', function(list)
    if type(list) ~= "table" or #list == 0 then return 0 end
    
    -- 计算平均值
    local sum = 0
    local count = 0
    for _, v in ipairs(list) do
        local num = tonumber(v)
        if num then
            sum = sum + num
            count = count + 1
        end
    end
    
    if count == 0 then return 0 end
    local mean = sum / count
    
    -- 计算方差
    local variance_sum = 0
    for _, v in ipairs(list) do
        local num = tonumber(v)
        if num then
            variance_sum = variance_sum + (num - mean) ^ 2
        end
    end
    
    local variance = variance_sum / count
    return math.sqrt(variance)
end)

--============================================================================
-- 条件和逻辑过滤器（返回布尔转字符串）
--============================================================================

-- 大于比较
M.add_filter('gt', function(value, threshold)
    local num1 = tonumber(value) or 0
    local num2 = tonumber(threshold) or 0
    return num1 > num2
end)

-- 小于比较  
M.add_filter('lt', function(value, threshold)
    local num1 = tonumber(value) or 0
    local num2 = tonumber(threshold) or 0
    return num1 < num2
end)

-- 等于比较
M.add_filter('eq', function(value, target)
    return tostring(value) == tostring(target)
end)

-- 包含检查
M.add_filter('contains', function(str, substring)
    if type(str) ~= "string" or type(substring) ~= "string" then
        return false
    end
    return str:find(substring, 1, true) ~= nil
end)

-- 匹配正则表达式
M.add_filter('matches', function(str, pattern)
    if type(str) ~= "string" or type(pattern) ~= "string" then
        return false
    end
    return str:match(pattern) ~= nil
end)

--============================================================================
-- 数据转换过滤器
--============================================================================

-- 转换为布尔值
M.add_filter('to_bool', function(value)
    if type(value) == "boolean" then
        return value
    elseif type(value) == "string" then
        local lower = value:lower()
        return lower == "true" or lower == "yes" or lower == "1" or lower == "on"
    elseif type(value) == "number" then
        return value ~= 0
    else
        return value ~= nil
    end
end)

-- 转换为整数
M.add_filter('to_int', function(value)
    local num = tonumber(value)
    return num and math.floor(num) or 0
end)

-- 转换为浮点数
M.add_filter('to_float', function(value)
    return tonumber(value) or 0.0
end)

--============================================================================
-- 数组操作过滤器（增强版）
--============================================================================

-- 数组切片
M.add_filter('slice', function(list, start_idx, end_idx)
    if type(list) ~= "table" then return {} end
    
    local start_pos = tonumber(start_idx) or 1
    local end_pos = tonumber(end_idx) or #list
    
    start_pos = math.max(1, math.floor(start_pos))
    end_pos = math.min(#list, math.floor(end_pos))
    
    local result = {}
    for i = start_pos, end_pos do
        table.insert(result, list[i])
    end
    
    return result
end)

-- 数组反转
M.add_filter('reverse_array', function(list)
    if type(list) ~= "table" then return {} end
    
    local result = {}
    for i = #list, 1, -1 do
        table.insert(result, list[i])
    end
    
    return result
end)

-- 数组随机打乱
M.add_filter('shuffle', function(list)
    if type(list) ~= "table" then return {} end
    
    local result = {}
    for _, v in ipairs(list) do
        table.insert(result, v)
    end
    
    for i = #result, 2, -1 do
        local j = math.random(i)
        result[i], result[j] = result[j], result[i]
    end
    
    return result
end)

-- 数组取样（随机选择 n 个元素）
M.add_filter('sample', function(list, count)
    if type(list) ~= "table" then return {} end
    
    local sample_count = math.min(tonumber(count) or 1, #list)
    local indices = {}
    for i = 1, #list do
        table.insert(indices, i)
    end
    
    -- 洗牌索引
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    
    local result = {}
    for i = 1, sample_count do
        table.insert(result, list[indices[i]])
    end
    
    return result
end)

-- 转大写
M.add_filter('upper', function(str)
    if str == nil then
        return ""
    end
    return string.upper(tostring(str))
end)

-- 格式化（如 format="玩家：%s"）
M.add_filter('format', function(str, fmt)
    if str == nil then
        str = ""
    end
    if fmt == nil then
        return tostring(str)
    end
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

--============================================================================
-- 文本后缀前缀过滤器
--============================================================================

-- 添加后缀
M.add_filter('suffix', function(str, suffix_text)
    if not suffix_text then return tostring(str or "") end
    return tostring(str or "") .. tostring(suffix_text)
end)

-- 添加前缀
M.add_filter('prefix', function(str, prefix_text)
    if not prefix_text then return tostring(str or "") end
    return tostring(prefix_text) .. tostring(str or "")
end)

-- 包装文本（同时添加前缀和后缀）
M.add_filter('wrap', function(str, prefix_text, suffix_text)
    local prefix = prefix_text or ""
    local suffix = suffix_text or ""
    return tostring(prefix) .. tostring(str or "") .. tostring(suffix)
end)

--- 获取过滤器的排序顺序
--- @param name string
--- @return integer
function M.get_sort_order(name)
    return orders[name] or 0
end

--- 获取过滤器
--- @param name string
--- @return fun(value: any, ...): any|nil
function M.get_filter(name)
    return filters[name]
end

return M