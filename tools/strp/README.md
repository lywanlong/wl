# STRP - 高性能模板引擎

STRP (String Template Replacement Parser) 是一个功能完整的 Lua 模板引擎，采用 Jinja 风格语法，经过深度优化，具备生产级性能和安全性。

## ✨ 核心特性

- 🎯 **功能完整**: 支持变量、控制结构、宏定义、过滤器等所有主流模板特性
- 🚀 **高性能**: 智能缓存系统、预编译优化、LRU淘汰策略
- 🔒 **安全可靠**: XSS防护、表达式沙箱、类型检查、错误隔离
- 🌍 **中文友好**: 完整的 UTF-8 支持，中文变量名和内容无障碍
- 🔧 **易扩展**: 模块化架构，50+ 内置过滤器，插件式过滤器系统
- 📚 **文档完善**: 详细的代码注释、类型标注、使用示例

## 📋 目录

- [快速开始](#快速开始)
- [基本语法](#基本语法)
- [变量系统](#变量系统)
- [控制结构](#控制结构)
- [宏系统](#宏系统)
- [过滤器库](#过滤器库)
- [性能优化](#性能优化)
- [安全机制](#安全机制)
- [API参考](#api参考)
- [架构设计](#架构设计)
- [最佳实践](#最佳实践)

## 🚀 快速开始

### 文件结构

```
wl/tools/strp/
├── strp.lua          # 主API接口，缓存管理
├── constants.lua     # 配置常量，性能参数
├── utils.lua         # 工具函数，安全操作
├── parser.lua        # 语法解析，变量处理
├── handlers.lua      # 控制结构，宏系统
└── filters.lua       # 过滤器库，50+过滤器
```

### 基本使用

```lua
local strp = require('wl.tools.strp.strp')

-- 简单变量替换
local result = strp.render("Hello, ${name}!", {name = "张三"})
print(result)  -- 输出: Hello, 张三!

-- 过滤器处理
local result = strp.render("${date|date('%Y-%m-%d')}", {date = os.time()})
print(result)  -- 输出: 2025-08-15

-- 高性能缓存渲染
local result = strp.render_cached(template, data, {cache_key = "my_template"})
```

##  基本语法

STRP 使用简洁直观的模板语法：

| 语法 | 示例 | 说明 |
|------|------|------|
| 变量 | `${variable}` | 变量替换 |
| 过滤器 | `${value|filter}` 或 `${value:filter}` | 过滤器处理 |
| 条件 | `{% if condition %}...{% endif %}` | 条件判断 |
| 循环 | `{% for item in list %}...{% endfor %}` | 循环结构 |
| 宏定义 | `{% macro name(args) %}...{% endmacro %}` | 可复用代码块 |
| 宏调用 | `{{macro_name(args)}}` | 调用已定义的宏 |
| 错误处理 | `{% try %}...{% catch %}...{% endtry %}` | 异常捕获 |
| 开关语句 | `{% switch value %}...{% endswitch %}` | 多分支选择 |
| 注释 | `{# 这是注释 #}` | 模板注释 |

## 🔧 变量系统

### 基本变量替换

```lua
local data = {
    name = "张三",
    age = 25,
    city = "北京"
}

local template = [[
姓名: ${name}
年龄: ${age}
城市: ${city}
]]

local result = strp.render(template, data)
```

### 复杂对象访问

```lua
local data = {
    user = {
        profile = {
            name = "李四",
            email = "lisi@example.com",
            settings = {
                theme = "dark",
                language = "zh-CN"
            }
        },
        permissions = {"read", "write"}
    }
}

-- 嵌套属性访问
local template = "用户: ${user.profile.name}, 主题: ${user.profile.settings.theme}"

-- 数组访问
local template2 = "权限: ${user.permissions.1}, ${user.permissions.2}"
```

### 过滤器链处理

```lua
-- 双语法支持：冒号或管道符
local template1 = "${text|upper|length}"     -- 管道符语法
local template2 = "${text:upper:length}"     -- 冒号语法

-- 带参数的过滤器
local template3 = "${date|date('%Y-%m-%d')}" -- 日期格式化
local template4 = "${number|round(2)}"       -- 四舍五入到2位小数
```

## 🎛️ 控制结构

### 条件判断

```lua
-- 基本条件
{% if user.vip %}
欢迎 VIP 用户！
{% else %}
欢迎普通用户！
{% endif %}

-- 多重条件
{% if score >= 90 %}
优秀
{% elif score >= 80 %}
良好
{% elif score >= 60 %}
及格
{% else %}
不及格
{% endif %}
```

### 循环结构

```lua
-- for 循环
{% for item in items %}
- ${item|upper}
{% endfor %}

-- while 循环
{% while count < 10 %}
计数: ${count}
{% endwhile %}

-- 循环变量
{% for item in items %}
索引: ${loop.index}, 值: ${item}
{% endfor %}
```

### 作用域控制

```lua
-- with 语句创建局部作用域
{% with user.profile as profile %}
姓名: ${profile.name}
邮箱: ${profile.email}
{% endwith %}
```

### 错误处理

```lua
-- try-catch 异常处理
{% try %}
    ${risky_operation}
{% catch error %}
    错误: ${error}
{% endtry %}
```

### 开关语句

```lua
-- switch 多分支选择
{% switch user.role %}
    {% case "admin" %}
        管理员权限
    {% case "moderator" %}
        版主权限
    {% case "user" %}
        普通用户权限
    {% default %}
        访客权限
{% endswitch %}
```

## 🎯 宏系统

宏是可复用的代码块，支持参数传递和作用域隔离。

### 宏定义

```lua
-- 基本宏定义
{% macro greet(name) %}
Hello, ${name}!
{% endmacro %}

-- 带多个参数的宏
{% macro user_card(title, name, email) %}
<div class="user-card">
    <h3>${title} ${name}</h3>
    <p>邮箱: ${email}</p>
</div>
{% endmacro %}

-- 带默认值的宏
{% macro button(text, type) %}
<button class="${type or 'primary'}">${text}</button>
{% endmacro %}
```

### 宏调用

```lua
-- 调用宏
{{greet("张三")}}

-- 带多个参数调用
{{user_card("先生", "李四", "lisi@example.com")}}

-- 嵌套在模板中
{% for user in users %}
    {{user_card(user.title, user.name, user.email)}}
{% endfor %}
```

### 宏的高级特性

```lua
-- 宏内部可以使用局部变量
{% macro format_list(items, prefix) %}
    {% for item in items %}
        ${prefix}: ${item}
    {% endfor %}
{% endmacro %}

-- 宏可以调用其他宏
{% macro simple_greet(name) %}
Hello ${name}!
{% endmacro %}

{% macro formal_greet(title, name) %}
{{simple_greet(title + " " + name)}}
{% endmacro %}
```

## 🔧 过滤器库

STRP 内置了50+个过滤器，涵盖文本处理、数学运算、日期时间、数组操作等各个方面。

### 文本处理过滤器

```lua
-- 大小写转换
${text|upper}          -- 转大写
${text|lower}          -- 转小写  
${text|title}          -- 标题格式
${text|capitalize}     -- 首字母大写

-- 字符串操作
${text|trim}           -- 去除首尾空格
${text|length}         -- 获取长度
${text|reverse}        -- 反转字符串
${text|replace("old", "new")} -- 替换文本

-- 字符串分割和连接
${"a,b,c"|split(",")}  -- 分割字符串
${items|join(", ")}    -- 连接数组
```

### 数学运算过滤器

```lua
-- 基本运算
${number|add(10)}      -- 加法
${number|sub(5)}       -- 减法
${number|mul(2)}       -- 乘法
${number|div(3)}       -- 除法
${number|mod(7)}       -- 取模

-- 数学函数
${number|abs}          -- 绝对值
${number|round(2)}     -- 四舍五入到2位小数
${number|floor}        -- 向下取整
${number|ceil}         -- 向上取整
```

### 日期时间过滤器

```lua
-- 日期格式化（支持标准strftime格式）
${timestamp|date('%Y-%m-%d')}        -- 2025-08-15
${timestamp|date('%Y年%m月%d日')}     -- 2025年08月15日
${timestamp|date('Y-m-d H:i:s')}     -- 自定义格式

-- 时间运算
${timestamp|add_days(7)}   -- 增加7天
${timestamp|add_hours(2)}  -- 增加2小时
${timestamp|format_ago}    -- "2小时前"格式
```

### 数组和集合过滤器

```lua
-- 数组操作
${array|length}        -- 数组长度
${array|first}         -- 第一个元素
${array|last}          -- 最后一个元素
${array|sort}          -- 排序
${array|reverse}       -- 反转
${array|unique}        -- 去重

-- 数学统计
${numbers|sum}         -- 求和
${numbers|avg}         -- 平均值
${numbers|max}         -- 最大值
${numbers|min}         -- 最小值

-- 数组筛选
${array|slice(1, 3)}   -- 切片操作
${array|filter_by("active", true)} -- 按属性筛选
```

### 类型转换过滤器

```lua
-- 类型转换
${value|string}        -- 转字符串
${value|int}           -- 转整数
${value|float}         -- 转浮点数
${value|bool}          -- 转布尔值

-- 默认值处理
${value|default("N/A")} -- 设置默认值
${value|default_if_empty("空值")} -- 空值时的默认值
```

### 游戏特定过滤器

```lua

-- 进度条显示
${value|progress_bar(max, 30)} -- 进度条

```


支持的比较操作符：
- `>`, `<`, `>=`, `<=` - 数值比较
- `==`, `~=` - 相等/不相等
- `and`, `or`, `not` - 逻辑操作

## 🔄 循环结构

### 数组循环

```lua
local data = {
    fruits = {"苹果", "香蕉", "橙子"}
}

local template = [[
水果列表:
{% for fruit in fruits %}
- ${fruit}
{% endfor %}
]]
```

### 键值对循环

```lua
local data = {
    scores = {
        math = 95,
        english = 88,
        science = 92
    }
}

local template = [[
成绩单:
{% for subject, score in scores %}
${subject}: ${score}分
{% endfor %}
]]
```

### 嵌套循环

```lua
{% for category in categories %}
  ${category.name}:
  {% for item in category.items %}
    - ${item.name}: ${item.price}元
  {% endfor %}
{% endfor %}
```

## 🔀 选择语句

选择语句（switch）提供了更清晰的多分支逻辑处理方式，特别适用于基于单个变量值的多种情况判断。

### 基本选择语句

```lua
{% switch status %}
{% case "active" %}
用户状态：✅ 活跃
{% case "inactive" %}
用户状态：❌ 非活跃
{% case "banned" %}
用户状态：🚫 已封禁
{% default %}
用户状态：❓ 未知
{% endswitch %}
```

### 数字匹配

```lua
{% switch level %}
{% case 1 %}
等级：🌱 新手
{% case 2 %}
等级：🌿 初级
{% case 3 %}
等级：🌳 中级
{% case 4 %}
等级：🏆 高级
{% case 5 %}
等级：👑 专家
{% default %}
等级：🚀 超神
{% endswitch %}
```

### 类型智能转换

STRP 的 switch 语句支持智能类型转换：

```lua
{% switch id %}
{% case "001" %}特殊用户
{% case 123 %}数字ID用户
{% case "admin" %}管理员
{% default %}普通用户
{% endswitch %}
```

以下值会被认为相等：
- 数字 `123` 和字符串 `"123"`
- 布尔值 `true` 和字符串 `"true"`
- 数字 `1` 和字符串 `"1"`

### 嵌套选择语句

```lua
{% switch category %}
{% case "food" %}
  {% switch type %}
  {% case "fruit" %}🍎 水果类
  {% case "vegetable" %}🥬 蔬菜类
  {% default %}🍽️ 其他食物
  {% endswitch %}
{% case "drink" %}
  {% switch type %}
  {% case "coffee" %}☕ 咖啡
  {% case "tea" %}🍵 茶类
  {% default %}🥤 其他饮品
  {% endswitch %}
{% default %}
❓ 未知分类
{% endswitch %}
```

### 对象属性匹配

```lua
{% switch user.role %}
{% case "admin" %}
👤 管理员 - 拥有全部权限
{% case "moderator" %}
🛡️ 版主 - 拥有管理权限
{% case "user" %}
👥 普通用户 - 基本权限
{% default %}
👻 访客 - 只读权限
{% endswitch %}
```

### 无默认分支

```lua
{% switch color %}
{% case "red" %}🔴 红色
{% case "blue" %}🔵 蓝色
{% case "green" %}🟢 绿色
{% endswitch %}
```

如果没有匹配的分支且无 default，将输出空字符串。

### 性能优势

- **顺序匹配**：按定义顺序匹配，找到就立即返回
- **智能解析**：一次解析所有分支，避免重复扫描
- **嵌套支持**：正确处理嵌套的块结构
- **类型转换**：智能的类型比较，减少模板复杂度

## 🎨 过滤器系统

过滤器用于转换变量的显示格式，使用管道符 `|` 连接。

### 基础过滤器

```lua
${name|upper}                    # 转大写
${name|lower}                    # 转小写
${name|capitalize}               # 首字母大写
${text|trim}                     # 去除首尾空格
${value|default:"默认值"}         # 设置默认值
```

### 字符串过滤器

```lua
${text|length}                   # 字符串长度（UTF-8 字符数）
${text|truncate:10}              # 截取10个字符
${text|replace:old:new}          # 替换文本
${text|reverse}                  # 反转字符串
${text|split:,}                  # 分割字符串
```

### 数字过滤器

```lua
${number|tonumber}               # 转为数字
${number|add:10}                 # 加法运算
${number|mult:2}                 # 乘法运算
${number|format_number}          # 千分位格式化
${value1|max:value2}             # 取最大值
${value1|min:value2}             # 取最小值
```

### 格式化过滤器

```lua
${text|pad_left:20:-}            # 左侧填充
${text|pad_right:20:*}           # 右侧填充
${text|pad_center:25:=}          # 居中填充
${data|json}                     # JSON 格式化
${text|color:red}                # 颜色标记
```

### UTF-8 专用过滤器

```lua
${chinese_text|char_at:3}        # 获取第3个字符
${chinese_text|substr:2:5}       # 提取2-5位置的字符
${text|is_valid_utf8}            # 验证UTF-8格式
```

### 过滤器链式调用

```lua
${user.name|trim|capitalize|pad_center:20:*}
${price|tonumber|mult:1.1|format_number}
${description|truncate:50|upper}
```

## 📄 模板包含

### 基本包含

```lua
{# 主模板 #}
<!DOCTYPE html>
<html>
<head>
    {% include "header.html" %}
</head>
<body>
    {% include "content.html" %}
</body>
</html>
```

### 带变量的包含

```lua
{# 包含模板时会继承当前的变量环境 #}
{% for user in users %}
    {% include "user_card.html" %}
{% endfor %}
```

## ⚡ 缓存系统

STRP 提供智能缓存机制来提升性能。

### 基本缓存使用

```lua
-- 编译并缓存模板
local compiled = strp.compile(template)

-- 多次使用缓存的模板
for i = 1, 1000 do
    local result = compiled(data)
end

-- 或者使用便捷方法
local result = strp.render_cached(template, data)
```

### 缓存管理

```lua
-- 清空缓存
strp.clear_cache()

-- 获取缓存统计
local stats = strp.get_cache_stats()
print("缓存命中率:", stats.hit_rate * 100, "%")
print("缓存大小:", stats.size)
```

### 缓存配置

```lua
-- 缓存会自动管理，默认最大100个模板
-- 超出限制时会自动清理一半缓存（LRU策略）
```

## 🌏 UTF-8 支持

STRP 完全支持 UTF-8 编码，正确处理中文字符。

### 中文字符处理

```lua
local data = {
    chinese_text = "这是一个中文字符串测试"
}

-- 正确按字符数截取，而不是字节数
local template = "${chinese_text|truncate:8}"  
-- 输出: "这是一个中文字符..."

-- 正确计算中文字符数量
local template2 = "字符数: ${chinese_text|length}"
-- 输出: "字符数: 12"
```

### 高级 UTF-8 功能

```lua
${chinese_text|reverse}          # 按字符反转
${chinese_text|char_at:5}        # 获取第5个字符
${chinese_text|substr:3:8}       # 提取3-8位置的字符
${mixed_text|is_valid_utf8}      # 验证UTF-8编码
```

## 🏗️ 模块架构

STRP 采用模块化设计，提供清晰的代码组织和良好的可扩展性。

### 模块结构

```
wl/tools/strp/
├── strp.lua        # 主入口，公共API接口
├── constants.lua   # 常量定义（关键字、配置等）
├── utils.lua       # 核心工具函数（表达式计算、错误处理）
├── parser.lua      # 模板解析器（变量替换、块查找）
├── handlers.lua    # 块处理器（if/for/switch处理逻辑）
└── filters.lua     # 过滤器系统（22+ 过滤器）
```

### 模块职责

#### `constants.lua` - 常量定义
- 块关键字定义（BLOCK_KEYWORDS、END_KEYWORDS）
- 缓存配置常量
- 系统配置参数

#### `utils.lua` - 核心工具
- 表达式安全计算（eval）
- 错误上下文报告（error_with_context）
- 嵌套对象访问（get_env_value）

#### `parser.lua` - 模板解析
- 变量替换逻辑（replace_variables）
- 块结束位置查找（find_block_end）
- 过滤器解析（parse_filters）

#### `handlers.lua` - 块处理器
- 条件处理（handle_if）
- 循环处理（handle_for）
- **选择处理（handle_switch）** - 新增功能
- 包含处理（handle_include）

#### `filters.lua` - 过滤器系统
- 22+ 内置过滤器
- UTF-8 专用过滤器
- 可扩展过滤器注册

### 扩展接口

```lua
-- 添加自定义过滤器
local filters = require 'wl.tools.strp.filters'
filters.add_filter('custom', function(value, arg)
    return value .. "_custom_" .. (arg or "")
end)

-- 使用自定义过滤器
local template = "${name|custom:suffix}"
```

### 设计优势

1. **模块化清晰**：每个模块职责单一，便于维护
2. **常量统一**：避免魔法数字和重复定义
3. **错误集中**：统一的错误处理和上下文报告
4. **性能优化**：独立的解析器和处理器模块
5. **易于扩展**：清晰的接口定义和扩展点

## 📚 API 参考

### 主要函数

#### `strp.render(template, env, options?)`

渲染模板字符串。

**参数:**
- `template` (string): 模板字符串
- `env` (table): 变量环境
- `options` (table, 可选): 渲染选项

**选项:**
- `trim_whitespace` (boolean): 是否压缩空白字符

**返回值:**
- (string): 渲染结果

```lua
local result = strp.render(template, data, {
    trim_whitespace = true
})
```

#### `strp.compile(template)`

编译模板为可重用函数。

**参数:**
- `template` (string): 模板字符串

**返回值:**
- (function): 编译后的模板函数

```lua
local compiled = strp.compile(template)
local result = compiled(data)
```

#### `strp.render_cached(template, env, options?)`

使用缓存渲染模板。

**参数:**
- `template` (string): 模板字符串
- `env` (table): 变量环境
- `options` (table, 可选): 渲染选项

**返回值:**
- (string): 渲染结果

#### `strp.clear_cache()`

清空模板缓存。

#### `strp.get_cache_stats()`

获取缓存统计信息。

**返回值:**
- (table): 统计信息
  - `hits` (number): 缓存命中次数
  - `misses` (number): 缓存未命中次数
  - `size` (number): 当前缓存大小
  - `hit_rate` (number): 命中率 (0-1)

## 🔥 高级用法

### 自定义过滤器

```lua
local filters = require('wl.tools.strp.filters')

-- 添加自定义过滤器
filters.add_filter('to_currency', function(value)
    local num = tonumber(value) or 0
    return string.format("¥%.2f", num)
end)

-- 使用自定义过滤器
local template = "价格: ${price|to_currency}"
```

### 复杂嵌套逻辑

```lua
local template = [[
{% for category in categories %}
  ${category.name}:
  {% for item in category.items %}
    {% if item.available %}
      {% if item.discount > 0 %}
        - ${item.name}: ￥${item.price|mult:item.discount|format_number} (原价: ￥${item.price})
      {% else %}
        - ${item.name}: ￥${item.price|format_number}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endfor %}
]]
```

### Switch 高级用法

#### 状态机模式

```lua
local template = [[
订单状态: {% switch order.status %}
{% case "pending" %}
  📋 待处理 - 预计处理时间: ${order.estimated_time}
  {% if order.urgent %}🚨 紧急订单{% endif %}
{% case "processing" %}
  ⚙️ 处理中 - 进度: ${order.progress}%
  {% switch order.stage %}
  {% case "validate" %}正在验证订单信息
  {% case "prepare" %}正在准备商品
  {% case "package" %}正在打包
  {% default %}处理阶段未知
  {% endswitch %}
{% case "shipped" %}
  🚚 已发货 - 快递单号: ${order.tracking_number}
  预计送达: ${order.delivery_date}
{% case "delivered" %}
  ✅ 已送达 - ${order.delivery_date}
  {% if order.rating %}用户评分: ${"★"|repeat:order.rating}{% endif %}
{% case "cancelled" %}
  ❌ 已取消 - 原因: ${order.cancel_reason}
  退款状态: {% switch order.refund_status %}
  {% case "pending" %}处理中
  {% case "completed" %}已完成
  {% default %}未知
  {% endswitch %}
{% default %}
  ❓ 状态未知
{% endswitch %}
]]
```

#### 多维度分类

```lua
local template = [[
{% switch user.region %}
{% case "north" %}
  {% switch user.level %}
  {% case "vip" %}北方VIP用户专享服务
  {% case "premium" %}北方高级用户
  {% default %}北方普通用户
  {% endswitch %}
{% case "south" %}
  {% switch user.level %}
  {% case "vip" %}南方VIP用户专享服务
  {% case "premium" %}南方高级用户
  {% default %}南方普通用户
  {% endswitch %}
{% default %}
  全国通用服务
{% endswitch %}
]]
```

#### 动态内容生成

```lua
local template = [[
{% for notification in notifications %}
  {% switch notification.type %}
  {% case "message" %}
    💬 新消息: ${notification.content} - 来自 ${notification.sender}
  {% case "system" %}
    🔔 系统通知: ${notification.content}
  {% case "warning" %}
    ⚠️ 警告: ${notification.content}
  {% case "error" %}
    ❌ 错误: ${notification.content}
  {% case "success" %}
    ✅ 成功: ${notification.content}
  {% default %}
    📋 通知: ${notification.content}
  {% endswitch %}
  <small>${notification.timestamp}</small>
  ---
{% endfor %}
]]
```

### 条件式包含

```lua
{% if user.is_admin %}
  {% include "admin_panel.html" %}
{% elif user.is_vip %}
  {% include "vip_panel.html" %}
{% else %}
  {% include "user_panel.html" %}
{% endif %}
```

### 错误处理

```lua
local success, result = pcall(strp.render, template, data)
if not success then
    print("模板渲染错误:", result)
else
    print("渲染成功:", result)
end
```

## ⚡ 性能优化

### 缓存策略

```lua
-- 对于重复使用的模板，使用编译缓存
local compiled_templates = {}

local function get_compiled_template(template_name, template_content)
    if not compiled_templates[template_name] then
        compiled_templates[template_name] = strp.compile(template_content)
    end
    return compiled_templates[template_name]
end
```

### 批量渲染

```lua
-- 批量渲染时使用缓存
local template = "用户: ${name}, 等级: ${level}"
local compiled = strp.compile(template)

for _, user in ipairs(users) do
    local result = compiled(user)
    -- 处理结果...
end
```

### 性能测试

```lua
-- 性能对比测试
local iterations = 1000
local template = "复杂模板内容..."

-- 不使用缓存
local start_time = os.clock()
for i = 1, iterations do
    strp.render(template, data)
end
local no_cache_time = os.clock() - start_time

-- 使用缓存
start_time = os.clock()
for i = 1, iterations do
    strp.render_cached(template, data)
end
local cache_time = os.clock() - start_time

print(string.format("性能提升: %.1f%%", 
    (no_cache_time - cache_time) / no_cache_time * 100))
```

### Switch 性能优化

Switch 语句经过专门优化，具有以下性能特性：

#### 智能解析策略
```lua
-- ✅ 推荐：Switch 比多重 if-elif 更高效
{% switch status %}
{% case "A" %}处理A{% case "B" %}处理B{% case "C" %}处理C
{% default %}默认处理
{% endswitch %}

-- ❌ 避免：多重嵌套的 if-elif
{% if status == "A" %}处理A
{% elif status == "B" %}处理B  
{% elif status == "C" %}处理C
{% else %}默认处理
{% endif %}
```

#### 性能特点
- **顺序匹配**：找到匹配项立即返回，不继续检查后续分支
- **一次解析**：预解析所有分支，避免重复扫描
- **智能转换**：优化的类型比较算法
- **嵌套支持**：正确处理深层嵌套，无性能损失

#### 最佳实践
```lua
-- ✅ 将最常匹配的case放在前面
{% switch user_type %}
{% case "normal" %}普通用户处理 {# 80%的情况 #}
{% case "vip" %}VIP用户处理 {# 15%的情况 #}
{% case "admin" %}管理员处理 {# 5%的情况 #}
{% endswitch %}

-- ✅ 避免在case值中使用复杂表达式
{% switch status %}
{% case "active" %}激活状态
{% case "inactive" %}非激活状态
{% endswitch %}
```

## 🐛 常见问题

### Q: 为什么中文字符截取不正确？
A: 确保使用了UTF-8扩展库，使用 `truncate` 过滤器而不是Lua原生的 `string.sub`。

### Q: 模板渲染速度慢怎么办？
A: 使用 `strp.compile()` 或 `strp.render_cached()` 来启用缓存机制。

### Q: Switch语句中数字"1"和字符串"1"会匹配吗？
A: 是的，STRP的switch支持智能类型转换。数字1会匹配字符串"1"，布尔值true会匹配字符串"true"。

### Q: Switch语句中可以有多个default分支吗？
A: 不可以，每个switch块只能有一个default分支，否则会报错。

### Q: Switch嵌套有深度限制吗？
A: 没有硬性限制，但建议合理设计嵌套层级以保证代码可读性。

### Q: 如何调试模板错误？
A: STRP 会提供详细的错误信息，包括错误位置和上下文。

### Q: 可以在模板中执行任意Lua代码吗？
A: 出于安全考虑，只支持有限的表达式，不能执行任意代码。

### Q: Switch性能如何？
## 🚀 性能优化

### 智能缓存系统

STRP 内置了高效的缓存机制，显著提升重复渲染的性能。

```lua
-- 使用缓存渲染（推荐）
local result = strp.render_cached(template, data, {cache_key = "user_template"})

-- 手动编译（适用于大量重复渲染）
local compiled = strp.compile(template)
for i = 1, 1000 do
    local result = compiled(data)
end

-- 缓存统计
local stats = strp.get_cache_stats()
print("缓存命中率:", stats.hit_rate * 100, "%")
```

### 性能最佳实践

```lua
-- ✅ 推荐：使用switch而不是多重if-elif
{% switch status %}
{% case "active" %}活跃{% case "inactive" %}非活跃
{% default %}未知
{% endswitch %}

-- ❌ 避免：多重嵌套if
{% if status == "active" %}活跃
{% elif status == "inactive" %}非活跃
{% else %}未知{% endif %}

-- ✅ 推荐：过滤器链
${text|trim|upper|truncate(20)}

-- ❌ 避免：多次变量调用
${text|trim} ${text|upper} ${text|truncate(20)}
```

## 🔒 安全机制

STRP 内置了多层安全防护，确保模板渲染的安全性。

### XSS 防护

```lua
-- 自动HTML转义
${user_input|escape_html}    -- <script> -> &lt;script&gt;

-- XML转义
${xml_data|escape_xml}       -- 防止XML注入
```

### 表达式沙箱

```lua
-- 安全的表达式求值
${math.sqrt(16)}             -- 允许安全的数学计算
${os.execute("rm -rf /")}    -- 自动阻止危险操作
```

### 类型安全

```lua
-- 自动类型检查和转换
${number|add(5)}             -- 自动转换为数字
${array|length}              -- 类型验证，防止错误
```

### 错误隔离

```lua
-- 优雅的错误处理
{% try %}
    ${risky_operation}
{% catch error %}
    安全降级: ${error}
{% endtry %}
```

## � API 参考

### 主要函数

#### `strp.render(template, env, options?)`

**基本渲染函数**

```lua
local result = strp.render(template, data, options)
```

**参数:**
- `template` (string): 模板字符串
- `env` (table): 变量环境
- `options` (table, 可选): 渲染选项
  - `cache_key` (string): 缓存键名
  - `trim_blocks` (boolean): 是否去除块标签的空白

**返回值:**
- (string): 渲染结果

#### `strp.render_cached(template, env, options?)`

**缓存渲染函数**

```lua
local result = strp.render_cached(template, data, {cache_key = "my_template"})
```

高性能渲染，自动管理模板缓存。

#### `strp.compile(template, options?)`

**模板编译函数**

```lua
local compiled = strp.compile(template)
local result = compiled(data)
```

预编译模板为可重用函数，适合大量重复渲染。

#### `strp.clear_cache()`

**清空缓存**

```lua
strp.clear_cache()
```

清空所有模板缓存，释放内存。

#### `strp.get_cache_stats()`

**获取缓存统计**

```lua
local stats = strp.get_cache_stats()
-- stats.hits: 缓存命中次数
-- stats.misses: 缓存未命中次数  
-- stats.hit_rate: 命中率 (0-1)
-- stats.size: 当前缓存大小
```

### 过滤器 API

#### `filters.add_filter(name, func)`

**添加自定义过滤器**

```lua
local filters = require 'wl.tools.strp.filters'

filters.add_filter('currency', function(value, symbol)
    local num = tonumber(value) or 0
    return (symbol or "$") .. string.format("%.2f", num)
end)

-- 使用: ${price|currency("¥")}
```

## 🏗️ 架构设计

### 模块职责

```lua
-- 主API接口
strp.lua                -- 公共API，缓存管理，性能优化

-- 核心解析
parser.lua              -- 语法解析，变量替换，过滤器处理
handlers.lua            -- 控制结构处理，宏系统

-- 基础设施  
utils.lua               -- 工具函数，安全操作，错误处理
constants.lua           -- 配置常量，关键字定义
filters.lua             -- 50+过滤器库，类型转换
```

### 设计特点

- **模块化**: 职责分离，便于维护和扩展
- **安全性**: 多层防护，沙箱执行，类型检查
- **性能**: 智能缓存，预编译，LRU淘汰
- **可扩展**: 插件式过滤器，清晰的扩展接口

## 🎯 最佳实践

### 模板组织

```lua
-- ✅ 推荐：模块化模板
-- header.strp
<header>
    <h1>${title}</h1>
    <nav>{{navigation_menu()}}</nav>
</header>

-- main.strp  
{% include "header.strp" %}
<main>
    ${content}
</main>

-- ❌ 避免：单个巨大模板
```

### 数据准备

```lua
-- ✅ 推荐：结构化数据
local data = {
    user = {
        profile = {name = "张三", level = 5},
        stats = {hp = 100, mp = 50}
    },
    items = {
        {name = "剑", type = "weapon"},
        {name = "盾", type = "armor"}
    }
}

-- ❌ 避免：扁平化数据
local data = {
    user_name = "张三",
    user_level = 5,
    user_hp = 100,
    -- ...
}
```

### 错误处理

```lua
-- ✅ 推荐：优雅降级
{% try %}
    ${complex_operation}
{% catch error %}
    <span class="error">操作失败</span>
{% endtry %}

-- ✅ 推荐：默认值
${user.name|default("匿名用户")}
${user.avatar|default("/images/default.png")}
```

### 性能优化

```lua
-- ✅ 推荐：批量渲染
local compiled = strp.compile(template)
for _, item in ipairs(large_dataset) do
    local result = compiled(item)
    -- 处理结果
end

-- ✅ 推荐：缓存热点模板
local hot_templates = {
    user_card = strp.compile(user_card_template),
    item_tooltip = strp.compile(tooltip_template)
}
```

## 🔗 生态系统

### 相关工具

- **Y3引擎**: 游戏开发平台
- **Lua Table Visualizer**: 数据可视化工具
- **热重载系统**: 开发时实时更新

### 集成示例

```lua
-- 与Y3引擎集成
local strp = require 'wl.tools.strp.strp'

-- 角色信息模板
local character_template = [[
角色: ${name} (${class})
等级: ${level} | 经验: ${exp}/${max_exp}
生命: ${hp|health_bar(max_hp, 20)}
技能: {% for skill in skills %}${skill.name}(${skill.level}) {% endfor %}
]]

-- 渲染角色信息
local character_info = strp.render(character_template, player_data)
```

## 📋 更新日志

### v3.0.0 (当前版本) - 深度优化版
- 🎯 **新增**: 完整的宏系统，支持参数传递和作用域隔离
- 🔧 **新增**: 50+过滤器库，涵盖各个使用场景
- 🚀 **优化**: 智能缓存系统，LRU淘汰策略，性能大幅提升
- 🔒 **增强**: 多层安全机制，XSS防护，表达式沙箱
- 📚 **重写**: 完整的代码文档化，类型标注，易于维护
- 🏗️ **架构**: 模块化重构，职责清晰分离

### v2.1.0 
- ✨ **新增**: Switch选择语句支持
- ✨ **新增**: 智能类型转换
- 🏗️ **重构**: 模块化架构
- ⚡ **优化**: Switch性能优化

### v2.0.0
- ✨ 完整的UTF-8中文支持
- ⚡ 智能缓存机制  
- 🎨 22+ 过滤器系统
- 🔧 错误处理改进

## 📄 许可证

MIT License - 自由使用，保留版权信息

## 🤝 贡献指南

欢迎提交问题报告和功能请求！

### 开发环境

```bash
# 运行测试
lua test_strp_final.lua

# 性能测试  
lua benchmark.lua
```

### 贡献类型

- 🐛 Bug修复
- ✨ 新功能开发
- 📚 文档改进
- ⚡ 性能优化
- 🔧 新过滤器

---

**STRP** - 高性能、全功能的Lua模板引擎 🚀

为Y3游戏引擎提供强大的模板处理能力，让动态内容生成变得简单而高效！
