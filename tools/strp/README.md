# STRP - 字符串模板引擎

STRP 是一个功能强大的 Lua 字符串模板引擎，支持 Jinja 风格的语法，具备完整的 UTF-8 中文支持、智能缓存机制和丰富的过滤器系统。

## 📋 目录

- [快速开始](#快速开始)
- [基本语法](#基本语法)
- [变量替换](#变量替换)
- [条件判断](#条件判断)
- [循环结构](#循环结构)
- [过滤器系统](#过滤器系统)
- [模板包含](#模板包含)
- [缓存系统](#缓存系统)
- [UTF-8 支持](#utf-8-支持)
- [API 参考](#api-参考)
- [高级用法](#高级用法)
- [性能优化](#性能优化)

## 🚀 快速开始

### 安装

将 `strp` 目录复制到你的项目中，确保包含以下文件：
```
wl/
├── tools/
│   └── strp/
│       ├── strp.lua        # 主模板引擎
│       └── filters.lua     # 过滤器系统
└── util/
    └── utf8.lua           # UTF-8 扩展库
```

### 基本使用

```lua
local strp = require('wl.tools.strp.strp')

-- 简单变量替换
local template = "Hello, ${name}!"
local result = strp.render(template, {name = "张三"})
print(result)  -- 输出: Hello, 张三!
```

## 📝 基本语法

STRP 使用 Jinja 风格的模板语法：

| 语法类型 | 格式 | 说明 |
|---------|------|------|
| 变量 | `${variable}` | 变量替换 |
| 条件 | `{% if condition %}...{% endif %}` | 条件判断 |
| 循环 | `{% for item in list %}...{% endfor %}` | 循环结构 |
| 注释 | `{# 这是注释 #}` | 模板注释 |
| 包含 | `{% include "template.html" %}` | 包含其他模板 |

## 🔧 变量替换

### 基本变量

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

### 对象属性访问

```lua
local data = {
    user = {
        profile = {
            name = "李四",
            email = "lisi@example.com"
        }
    }
}

local template = "用户: ${user.profile.name}, 邮箱: ${user.profile.email}"
```

### 数组访问

```lua
local data = {
    items = {"苹果", "香蕉", "橙子"}
}

local template = "第一个水果: ${items.1}"  -- Lua 数组从1开始
```

## ✅ 条件判断

### 基本条件

```lua
{% if user.vip %}
欢迎 VIP 用户！
{% else %}
欢迎普通用户！
{% endif %}
```

### 多重条件

```lua
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

### 复杂条件

```lua
{% if user.level > 50 and user.vip %}
您是高级 VIP 用户
{% endif %}
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

## 🐛 常见问题

### Q: 为什么中文字符截取不正确？
A: 确保使用了UTF-8扩展库，使用 `truncate` 过滤器而不是Lua原生的 `string.sub`。

### Q: 模板渲染速度慢怎么办？
A: 使用 `strp.compile()` 或 `strp.render_cached()` 来启用缓存机制。

### Q: 如何调试模板错误？
A: STRP 会提供详细的错误信息，包括错误位置和上下文。

### Q: 可以在模板中执行任意Lua代码吗？
A: 出于安全考虑，只支持有限的表达式，不能执行任意代码。

## 🔗 相关资源

- **项目地址**: `wl/tools/strp/`
- **UTF-8库**: `wl/util/utf8.lua`
- **测试文件**: `test_basic_nesting.lua`, `test_extreme_nesting.lua`

## 📄 许可证

MIT License

---

**STRP** - 让模板渲染更简单、更强大！ 🚀
