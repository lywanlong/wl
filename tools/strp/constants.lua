--============================================================================
-- 模板引擎常量定义
--============================================================================

---@class StrpConstants
local M = {}

--- 开启新块的关键字
---@type table<string, boolean>
M.BLOCK_KEYWORDS = {
    ["if"] = true,     -- 条件判断
    ["for"] = true,    -- 循环
    ["while"] = true,  -- 循环
    ["unless"] = true, -- 反向条件
    ["switch"] = true, -- 选择语句
    ["with"] = true,   -- 作用域
    ["macro"] = true,  -- 宏定义
}

--- 结束块的关键字
---@type table<string, boolean>
M.END_KEYWORDS = {
    ["end"] = true,      -- 通用结束
    ["endif"] = true,    -- 条件结束
    ["endfor"] = true,   -- 循环结束
    ["endwhile"] = true, -- 循环结束
    ["endunless"] = true,-- 反向条件结束
    ["endswitch"] = true,-- 选择语句结束
    ["endwith"] = true,  -- 作用域结束
    ["endmacro"] = true, -- 宏定义结束
}

--- 最大缓存大小
M.MAX_CACHE_SIZE = 100

return M
