--- UTF-8 字符串处理扩展库
--- 基于 Lua 5.3+ 的 utf8 库进行扩展
--- @class UTF8Extended
local M = {}

-- 导入标准 utf8 库
local utf8 = utf8 or require('utf8')

--============================================================================
-- 基础 UTF-8 操作（基于标准库）
--============================================================================

--- 获取 UTF-8 字符串的字符数量
--- @param str string
--- @param i? integer 起始位置（字节）
--- @param j? integer 结束位置（字节）
--- @return integer? 字符数量，如果字符串无效则返回 nil
--- @return integer? 错误位置（如果有错误）
function M.len(str, i, j)
    return utf8.len(str, i, j)
end

--- 按字符位置截取 UTF-8 字符串
--- @param str string 原字符串
--- @param start_char integer 开始字符位置（1-based）
--- @param end_char? integer 结束字符位置（1-based），默认到字符串末尾
--- @return string 截取的字符串
function M.sub(str, start_char, end_char)
    if type(str) ~= "string" then
        return ""
    end
    
    local char_count = utf8.len(str)
    if not char_count then
        return ""  -- 无效的 UTF-8 字符串
    end
    
    -- 处理负数索引
    if start_char < 0 then
        start_char = char_count + start_char + 1
    end
    if end_char and end_char < 0 then
        end_char = char_count + end_char + 1
    end
    
    -- 边界检查
    start_char = math.max(1, start_char)
    end_char = end_char and math.min(char_count, end_char) or char_count
    
    if start_char > end_char then
        return ""
    end
    
    -- 获取字节位置
    local start_byte = utf8.offset(str, start_char) or 1
    local end_byte = utf8.offset(str, end_char + 1)
    if end_byte then
        end_byte = end_byte - 1
    else
        end_byte = #str
    end
    
    return str:sub(start_byte, end_byte)
end

--- 按字符数截取字符串（从开头截取）
--- @param str string 原字符串
--- @param max_chars integer 最大字符数
--- @return string 截取的字符串
function M.truncate(str, max_chars)
    if type(str) ~= "string" or max_chars <= 0 then
        return ""
    end
    
    local char_count = utf8.len(str)
    if not char_count or char_count <= max_chars then
        return str
    end
    
    return M.sub(str, 1, max_chars)
end

--============================================================================
-- 扩展功能
--============================================================================

--- 反转 UTF-8 字符串（按字符反转）
--- @param str string
--- @return string
function M.reverse(str)
    if type(str) ~= "string" then
        return ""
    end
    
    local chars = {}
    for pos, code in utf8.codes(str) do
        table.insert(chars, 1, utf8.char(code))
    end
    
    return table.concat(chars)
end

--- 获取字符串中每个字符的编码点
--- @param str string
--- @return integer[] 编码点数组
function M.codepoints(str)
    if type(str) ~= "string" then
        return {}
    end
    
    local codes = {}
    for pos, code in utf8.codes(str) do
        table.insert(codes, code)
    end
    
    return codes
end

--- 从编码点数组创建字符串
--- @param codes integer[] 编码点数组
--- @return string
function M.from_codepoints(codes)
    if type(codes) ~= "table" then
        return ""
    end
    
    local chars = {}
    for _, code in ipairs(codes) do
        if type(code) == "number" and code >= 0 then
            table.insert(chars, utf8.char(code))
        end
    end
    
    return table.concat(chars)
end

--- 检查字符串是否为有效的 UTF-8
--- @param str string
--- @return boolean
function M.isvalid(str)
    if type(str) ~= "string" then
        return false
    end
    
    return utf8.len(str) ~= nil
end

--- 按字符迭代字符串
--- @param str string
--- @return fun(): integer?, string? 迭代器函数，返回位置和字符
function M.chars(str)
    if type(str) ~= "string" then
        return function() return nil end
    end
    
    local char_pos = 0
    return function()
        for byte_pos, code in utf8.codes(str) do
            char_pos = char_pos + 1
            return char_pos, utf8.char(code)
        end
    end
end

--- 获取指定字符位置的字符
--- @param str string
--- @param char_pos integer 字符位置（1-based）
--- @return string? 字符，如果位置无效则返回 nil
function M.char_at(str, char_pos)
    if type(str) ~= "string" or type(char_pos) ~= "number" then
        return nil
    end
    
    local current_pos = 0
    for pos, code in utf8.codes(str) do
        current_pos = current_pos + 1
        if current_pos == char_pos then
            return utf8.char(code)
        end
    end
    
    return nil
end

--- 查找子字符串的字符位置
--- @param str string 主字符串
--- @param pattern string 要查找的子字符串
--- @param start_char? integer 开始查找的字符位置
--- @return integer? 找到的字符位置，没找到返回 nil
function M.find_char(str, pattern, start_char)
    if type(str) ~= "string" or type(pattern) ~= "string" then
        return nil
    end
    
    start_char = start_char or 1
    local start_byte = utf8.offset(str, start_char) or 1
    
    local byte_pos = str:find(pattern, start_byte, true)
    if not byte_pos then
        return nil
    end
    
    -- 将字节位置转换为字符位置
    local char_pos = 0
    for pos, code in utf8.codes(str) do
        char_pos = char_pos + 1
        if pos >= byte_pos then
            return char_pos
        end
    end
    
    return nil
end

--- 替换字符串中的内容（支持 UTF-8）
--- @param str string 原字符串
--- @param pattern string 要替换的模式
--- @param replacement string 替换内容
--- @param max_count? integer 最大替换次数
--- @return string 替换后的字符串
--- @return integer 替换次数
function M.replace(str, pattern, replacement, max_count)
    if type(str) ~= "string" then
        return "", 0
    end
    
    return str:gsub(pattern, replacement, max_count)
end

--- 按分隔符分割字符串
--- @param str string 要分割的字符串
--- @param delimiter string 分隔符
--- @param max_parts? integer 最大分割部分数
--- @return string[] 分割后的字符串数组
function M.split(str, delimiter, max_parts)
    if type(str) ~= "string" or type(delimiter) ~= "string" then
        return {}
    end
    
    local parts = {}
    local start = 1
    local count = 0
    
    while true do
        if max_parts and count >= max_parts - 1 then
            table.insert(parts, str:sub(start))
            break
        end
        
        local pos = str:find(delimiter, start, true)
        if not pos then
            table.insert(parts, str:sub(start))
            break
        end
        
        table.insert(parts, str:sub(start, pos - 1))
        start = pos + #delimiter
        count = count + 1
    end
    
    return parts
end

--- 去除字符串首尾空白字符（支持 Unicode 空白字符）
--- @param str string
--- @return string
function M.trim(str)
    if type(str) ~= "string" then
        return ""
    end
    
    -- 基本的空白字符处理
    return str:match("^%s*(.-)%s*$") or str
end

--- 填充字符串到指定字符长度
--- @param str string 原字符串
--- @param width integer 目标字符长度
--- @param fill_char? string 填充字符，默认为空格
--- @param align? "left"|"right"|"center" 对齐方式，默认为左对齐
--- @return string
function M.pad(str, width, fill_char, align)
    if type(str) ~= "string" then
        str = ""
    end
    
    fill_char = fill_char or " "
    align = align or "left"
    
    local char_count = utf8.len(str) or 0
    if char_count >= width then
        return str
    end
    
    local pad_count = width - char_count
    
    if align == "right" then
        return string.rep(fill_char, pad_count) .. str
    elseif align == "center" then
        local left_pad = math.floor(pad_count / 2)
        local right_pad = pad_count - left_pad
        return string.rep(fill_char, left_pad) .. str .. string.rep(fill_char, right_pad)
    else -- left
        return str .. string.rep(fill_char, pad_count)
    end
end

--============================================================================
-- 兼容性函数
--============================================================================

--- 创建兼容旧版本的字符长度函数
--- @param str string
--- @return integer
function M.char_count(str)
    return utf8.len(str) or 0
end

--- 创建兼容旧版本的字符截取函数
--- @param str string
--- @param max_chars integer
--- @return string
function M.char_sub(str, max_chars)
    return M.truncate(str, max_chars)
end

return M
