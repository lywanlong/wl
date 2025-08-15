# STRP - 高性能模板引擎 v2.1

STRP (String Template Replacement Parser) 是一个功能完整的 Lua 模板引擎，采用 Jinja 风格语法，经过深度优化，具备生产级性能和安全性。

## ✨ 核心特性

- 🎯 **功能完整**: 支持变量、嵌套模板、过滤器链等所有主流模板特性
- 🚀 **高性能**: 智能缓存系统、预编译优化、LRU淘汰策略
- 🔒 **安全可靠**: XSS防护、表达式沙箱、类型检查、错误隔离
- 🌍 **中文友好**: 完整的 UTF-8 支持，中文变量名和内容无障碍
- 🔧 **易扩展**: 模块化架构，50+ 内置过滤器，插件式过滤器系统
- 📚 **文档完善**: 详细的代码注释、类型标注、使用示例
- ✨ **嵌套模板**: 支持 `${variable|filter:${dynamic_param}}` 动态参数语法

## 📋 目录

- [快速开始](#快速开始)
- [基本语法](#基本语法)
- [嵌套模板](#嵌套模板)
- [变量系统](#变量系统)
- [过滤器系统](#过滤器系统)
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
├── handlers.lua         # 控制结构，宏系统
├── filters.lua          # 过滤器库，50+过滤器
└── README.md           # 完整文档
```

### 基本使用

```lua
local strp = require('wl.tools.strp.strp')

-- 简单变量替换
local result = strp.render("Hello, ${name}!", {name = "张三"})
print(result)  -- 输出: Hello, 张三!

-- 使用过滤器
local result = strp.render("${message|upper}", {message = "hello world"})
print(result)  -- 输出: HELLO WORLD

-- 嵌套模板（v2.1新特性）
local data = {
    user_name = nil,
    default_name = "匿名用户",
    star_level = 2,
    star_level_attrs = {
        [1] = {damage = 100, color = "#CCCCCC"},
        [2] = {damage = 200, color = "#FF8800"}
    }
}

local template = "${user_name|default:${default_name}}"
local result = strp.render(template, data)
print(result)  -- 输出: 匿名用户

-- 复杂嵌套模板
local skill_template = "造成 ${star_level_attrs[star_level].damage|color:${star_level_attrs[star_level].color}} 点伤害"
local result = strp.render(skill_template, data)
print(result)  -- 输出: 造成 #FF8800200#E 点伤害
```

## 🎯 嵌套模板

### 基本语法

嵌套模板允许在过滤器参数中使用动态变量：

```lua
${variable|filter:${dynamic_parameter}}
```

### 支持的嵌套类型

#### 1. 默认值嵌套
```lua
-- 基础用法
${user_name|default:${fallback_name}}

-- 数组索引嵌套
${items[current_index]|default:${items[fallback_index]}}

-- 对象属性嵌套
${user.avatar|default:${config.default_avatar}}
```

#### 2. 过滤器链嵌套
```lua
-- 动态颜色
${damage|color:${rarity_colors[item_rarity]}}

-- 动态格式化
${value|format:${templates[template_type]}}

-- 多级嵌套
${text|translate:${user.language}|color:${themes[user.theme].text_color}}
```

#### 3. 复杂表达式嵌套
```lua
-- 游戏技能描述
local template = [[
技能等级：${star_level} 星
触发概率：${attrs[star_level].prob|default:${attrs[fallback_level].prob}}%
造成伤害：${attrs[star_level].damage|color:${attrs[star_level].color}}点
]]

local data = {
    star_level = 3,
    fallback_level = 1,
    attrs = {
        [1] = {prob = 10, damage = 100, color = "#CCCCCC"},
        [2] = {prob = 20, damage = 200, color = "#00FF00"},
        [3] = {prob = 30, damage = 300, color = "#FF0000"}
    }
}

local result = strp.render(template, data)
```

## 🔧 变量系统

### 简单变量
```lua
local data = {name = "张三", age = 25}
local template = "姓名：${name}，年龄：${age}"
```

### 嵌套对象
```lua
local data = {
    user = {
        profile = {
            name = "张三",
            email = "zhangsan@example.com"
        }
    }
}
local template = "用户：${user.profile.name} (${user.profile.email})"
```

### 数组访问
```lua
local data = {
    items = {"苹果", "香蕉", "橙子"},
    index = 1
}
local template = "第一个水果：${items[0]}，当前水果：${items[index]}"
```

## 🎨 过滤器系统

### 默认值过滤器
```lua
-- 通用默认值
${value|default:"默认值"}

-- 仅当nil时使用默认值
${value|default_if_nil:"默认值"}

-- 仅当空字符串时使用默认值
${value|default_if_empty:"默认值"}

-- 嵌套默认值
${primary_value|default:${secondary_value}|default:"最终默认值"}
```

### 字符串处理
```lua
-- 大小写转换
${text|upper}              -- 转为大写
${text|lower}              -- 转为小写
${text|title}              -- 标题格式

-- 字符串操作
${text|trim}               -- 去除首尾空格
${text|length}             -- 获取长度
${text|reverse}            -- 反转字符串
${text|substring:0:10}     -- 截取子字符串
```

### 数字处理
```lua
-- 数学运算
${number|add:10}           -- 加法
${number|subtract:5}       -- 减法
${number|multiply:2}       -- 乘法
${number|divide:3}         -- 除法

-- 格式化
${number|format:"%.2f"}    -- 格式化为2位小数
${number|currency}         -- 货币格式
${number|percentage}       -- 百分比格式
```

### 集合处理
```lua
-- 数组操作
${array|length}            -- 数组长度
${array|join:","}          -- 连接数组
${array|sort}              -- 排序
${array|reverse}           -- 反转
${array|first}             -- 第一个元素
${array|last}              -- 最后一个元素
```

### 日期时间
```lua
-- 日期格式化
${timestamp|date:"%Y-%m-%d"}          -- 格式化日期
${timestamp|time:"%H:%M:%S"}          -- 格式化时间
${timestamp|datetime:"%Y-%m-%d %H:%M"} -- 日期时间
${timestamp|relative}                  -- 相对时间 (1小时前)
```

### 安全处理
```lua
-- HTML转义
${html_content|escape}     -- HTML实体编码
${html_content|safe}       -- 标记为安全（跳过转义）

-- URL处理
${url|urlencode}           -- URL编码
${url|urldecode}           -- URL解码
```

### 自定义过滤器
```lua
-- 在 filters.lua 中添加自定义过滤器
local function custom_filter(value, arg1, arg2)
    -- 自定义逻辑
    return processed_value
end

-- 注册过滤器
filters.register("custom", custom_filter)

-- 使用自定义过滤器
${value|custom:arg1:arg2}
```

## 🚀 性能优化

### 缓存策略

#### 模板缓存
```lua
-- 启用缓存（默认）
local result = strp.render_cached(template, data)

-- 禁用缓存
local result = strp.render(template, data, {cache = false})

-- 预热缓存
strp.warm_cache({"template1", "template2", "template3"})

-- 清空缓存
strp.clear_cache()
```

#### 缓存统计
```lua
local stats = strp.get_cache_stats()
print("缓存命中率:", stats.template_cache.hit_rate)
print("缓存大小:", stats.template_cache.size)
print("内存使用:", stats.memory_usage, "MB")
```

### 批处理优化
```lua
-- 批量处理多个模板
local templates = {"template1", "template2", "template3"}
local data_list = {data1, data2, data3}

local results = {}
for i, template in ipairs(templates) do
    results[i] = strp.render_cached(template, data_list[i])
end
```

### 内存管理
```lua
-- 检查内存使用
local health = strp.health_check()
if health.memory_warning then
    print("内存使用过高:", health.memory_usage, "MB")
    strp.clear_cache()  -- 清理缓存释放内存
end
```

## 🔒 安全机制

### XSS防护
```lua
-- 自动转义HTML（默认启用）
local result = strp.render("${user_input}", {user_input = "<script>alert('xss')</script>"})
-- 输出: &lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;

-- 禁用自动转义
local result = strp.render(template, data, {autoescape = false})

-- 手动转义
${user_input|escape}
```

### 表达式沙箱
```lua
-- 安全的表达式求值
${math.max(a, b)}          -- 允许：数学函数
${string.upper(text)}      -- 允许：字符串函数
${os.execute("rm -rf /")}  -- 禁止：危险系统调用

-- 自定义安全策略
local options = {
    security = {
        enable_sandbox = true,
        allowed_functions = {"math.abs", "string.len"},
        forbidden_functions = {"os.execute", "io.open"}
    }
}
```

### 输入验证
```lua
-- 变量名验证
local valid, error = utils.validate_variable_name("user_name")  -- true
local valid, error = utils.validate_variable_name("123invalid") -- false

-- 模板大小限制
-- 超过1MB的模板会被拒绝

-- 输出大小限制
-- 超过10MB的输出会被截断
```

## 📚 API参考

### 主要方法

#### strp.render(template, env, options)
渲染模板（无缓存）

**参数：**
- `template` (string): 模板字符串
- `env` (table): 环境变量
- `options` (table, 可选): 渲染选项

**返回：**
- `string`: 渲染结果

#### strp.render_cached(template, env, options)
渲染模板（带缓存，推荐）

**参数：**
- `template` (string): 模板字符串
- `env` (table): 环境变量
- `options` (table, 可选): 渲染选项

**返回：**
- `string`: 渲染结果

#### strp.compile(template, options)
编译模板为函数

**参数：**
- `template` (string): 模板字符串
- `options` (table, 可选): 编译选项

**返回：**
- `function`: 编译后的模板函数
- `string`: 错误信息（如果有）

### 工具方法

#### strp.clear_cache()
清空所有缓存

#### strp.get_cache_stats()
获取缓存统计信息

**返回：**
- `table`: 包含缓存统计的表

#### strp.get_version()
获取版本信息

**返回：**
- `string`: 版本号

#### strp.health_check()
系统健康检查

**返回：**
- `table`: 健康状态信息

### 配置选项

```lua
local options = {
    -- 基本选项
    cache = true,              -- 启用缓存
    debug = false,             -- 调试模式
    strict = false,            -- 严格模式
    autoescape = true,         -- 自动转义HTML
    
    -- 错误处理
    error_handling = "strict", -- "strict" | "ignore" | "replace"
    undefined_behavior = "error", -- "error" | "empty" | "keep"
    
    -- 格式化
    encoding = "utf-8",        -- 字符编码
    output_format = "string",  -- "string" | "table"
    preserve_whitespace = false, -- 保留空白字符
}
```

## 🏗️ 架构设计

### 模块结构

```
┌─────────────────┐
│   strp.lua      │  主API接口，缓存管理
├─────────────────┤
│ constants.lua   │  配置常量，性能参数
│   utils.lua     │  工具函数，安全操作
│  parser.lua     │  语法解析，变量处理
│   handlers.lua  │  控制结构，宏系统
│   filters.lua   │  过滤器库
└─────────────────┘
```

### 处理流程

```
输入模板 → 语法解析 → 变量替换 → 过滤器处理 → 输出结果
    ↓         ↓         ↓           ↓           ↓
  验证检查   块结构     嵌套展开    链式调用    安全转义
```

### 缓存架构

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 模板缓存    │    │ 解析缓存    │    │ 过滤器缓存  │
│ Template    │    │ Parser      │    │ Filter      │
│ Cache       │    │ Cache       │    │ Cache       │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └─────────┬─────────┴─────────┬─────────┘
                 │                   │
           ┌─────────────┐    ┌─────────────┐
           │ LRU淘汰算法  │    │ 统计监控    │
           │ LRU Eviction│    │ Statistics  │
           └─────────────┘    └─────────────┘
```

## 💡 最佳实践

### 性能优化建议

1. **使用缓存版本**
   ```lua
   -- 推荐：使用缓存版本
   local result = strp.render_cached(template, data)
   
   -- 避免：频繁使用无缓存版本
   local result = strp.render(template, data)
   ```

2. **预编译模板**
   ```lua
   -- 预编译常用模板
   local compiled = strp.compile(template)
   
   -- 重复使用编译后的模板
   local result1 = compiled(data1)
   local result2 = compiled(data2)
   ```

3. **批量处理**
   ```lua
   -- 预热缓存
   strp.warm_cache(common_templates)
   
   -- 批量渲染
   local results = {}
   for i, item in ipairs(items) do
       results[i] = strp.render_cached(template, item)
   end
   ```

### 安全最佳实践

1. **输入验证**
   ```lua
   -- 验证用户输入
   local function safe_render(template, user_data)
       -- 清理用户数据
       local clean_data = sanitize_user_input(user_data)
       return strp.render_cached(template, clean_data, {
           autoescape = true,
           error_handling = "replace"
       })
   end
   ```

2. **权限控制**
   ```lua
   -- 限制可访问的数据
   local safe_env = {
       user = {name = user.name, id = user.id},
       -- 不暴露敏感信息
   }
   ```

### 调试技巧

1. **启用调试模式**
   ```lua
   local result = strp.render(template, data, {
       debug = true,
       error_handling = "replace"
   })
   ```

2. **健康监控**
   ```lua
   -- 定期检查系统状态
   local health = strp.health_check()
   if health.memory_warning then
       -- 清理缓存或扩容
   end
   ```

3. **缓存分析**
   ```lua
   local stats = strp.get_cache_stats()
   if stats.template_cache.hit_rate < 0.8 then
       -- 优化模板设计或缓存策略
   end
   ```

## 🔄 版本升级指南

### 从v2.0升级到v2.1

#### 新增功能
- ✨ 嵌套模板语法支持
- 🚀 改进的缓存系统
- 🔒 增强的安全机制
- 📊 详细的性能监控

#### 兼容性
- ✅ 完全向后兼容
- ✅ 现有API无变化
- ✅ 配置选项保持一致

#### 推荐升级步骤
1. 更新模块文件
2. 测试现有功能
3. 逐步使用新特性
4. 优化性能配置

## 🤝 贡献指南

我们欢迎社区贡献！请遵循以下步骤：

1. Fork 项目
2. 创建特性分支
3. 编写测试用例
4. 提交Pull Request

### 开发环境设置

```bash
# 克隆项目
git clone https://github.com/your-repo/strp.git

# 运行测试
lua test_all.lua

# 性能测试
lua benchmark.lua
```

## 📄 许可证

MIT License - 详见 LICENSE 文件

## 🙏 致谢

感谢所有贡献者和社区成员的支持！

---

**STRP v2.1** - 让模板渲染更简单、更安全、更高效！

如有问题或建议，请提交 Issue 或联系维护者。
