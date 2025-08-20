# STRP 模板引擎

一个功能强大、高性能的 Lua 模板引擎，专为游戏开发和动态内容生成而设计。

## 🌟 特性亮点

- **🔗 深度嵌套支持** - 支持任意深度的变量嵌套和模板组合
- **🎯 智能变量替换** - 支持复杂的对象路径访问和数组索引
- **⚡ 高性能缓存** - 内置 LRU 缓存系统，优化重复渲染性能
- **🛡️ 安全可靠** - 完善的错误处理和递归深度保护
- **🎨 丰富过滤器** - 内置30+种常用过滤器，支持链式调用
- **📦 模块化设计** - 基于 Y3 Class 系统的面向对象架构

## 📦 快速开始

### 安装与引入

```lua
local strp = require 'wl.tools.strp'

-- 创建 STRP 实例
local engine = New 'Strp' ()
```

### 基础用法

```lua
-- 简单变量替换
local result = engine:render("Hello ${name}!", {name = "张三"})
-- 输出: Hello 张三!

-- 对象属性访问
local env = {
    user = {
        name = "李四",
        level = 25
    }
}
local result = engine:render("玩家: ${user.name} (Lv.${user.level})", env)
-- 输出: 玩家: 李四 (Lv.25)
```

## 🔧 核心功能

### 1. 变量替换

#### 基础语法
```lua
-- 字符串变量
"${name}"                    -- 输出变量值
"${user.name}"              -- 对象属性访问
"${items[0]}"               -- 数组索引访问
"${#items}"                 -- 数组长度
```

#### 嵌套变量
```lua
-- 动态索引访问
"${users[${current_index}].name}"

-- 动态键访问  
"${config[${user.theme}].color}"

-- 多层嵌套
"${users[${current_index}].permissions[${role}][0]}"
```

### 2. 过滤器系统

#### 基础过滤器
```lua
-- 颜色渲染
"${name|color:red}"          -- 红色文本
"${level|color:${level_color}}" -- 动态颜色

-- 字符串处理
"${text|upper}"              -- 转大写
"${text|lower}"              -- 转小写
"${text|trim}"               -- 去除空白
"${text|capitalize}"         -- 首字母大写

-- 数值处理
"${price|format:'¥%.2f'}"    -- 格式化金额
"${exp|divide:100}"          -- 除法运算
"${count|default:0}"         -- 默认值
```

#### 过滤器链
```lua
-- 多个过滤器组合
"${level|format:'Lv.%d'|color:gold|upper}"

-- 嵌套参数过滤器
"${user.name|color:${colors[${user.rank}]}}"
```

### 3. 模板注册系统

```lua
-- 注册命名模板
engine:register_template("user_card", "【${type}】${name} Lv.${level}")
engine:register_template("item_display", "${name}(${quality})")

-- 使用注册的模板
local result = engine:render_by_name("user_card", {
    type = "战士",
    name = "勇者",
    level = 20
})
-- 输出: 【战士】勇者 Lv.20
```

### 4. 缓存管理

```lua
-- 获取缓存统计
local stats = engine:get_cache_stats()
print("缓存命中率:", stats.template_cache.hit_rate)

-- 清理缓存
engine:clear_cache()

-- 预热缓存
engine:warm_cache({
    "Hello ${name}!",
    "Level: ${level}",
    "Score: ${score|format:'%d分'}"
})
```

## 🎨 内置过滤器详解

### 字符串处理类
| 过滤器 | 描述 | 示例 |
|--------|------|------|
| `upper` | 转大写 | `${text\|upper}` |
| `lower` | 转小写 | `${text\|lower}` |
| `capitalize` | 首字母大写 | `${text\|capitalize}` |
| `trim` | 去除首尾空白 | `${text\|trim}` |
| `length` | 获取长度 | `${text\|length}` |

### 数值处理类
| 过滤器 | 描述 | 示例 |
|--------|------|------|
| `format` | 格式化 | `${num\|format:'%.2f'}` |
| `divide` | 除法运算 | `${exp\|divide:100}` |
| `tonumber` | 转数字 | `${str\|tonumber}` |
| `default` | 默认值 | `${val\|default:'无'}` |

### 显示效果类
| 过滤器 | 描述 | 示例 |
|--------|------|------|
| `color` | 颜色渲染 | `${text\|color:red}` |
| `substitute` | 替换内容 | `${old\|substitute:${new}}` |

### 日期时间类
| 过滤器 | 描述 | 示例 |
|--------|------|------|
| `date` | 日期格式化 | `${timestamp\|date:'Y-m-d'}` |
| `time_ago` | 相对时间 | `${timestamp\|time_ago}` |
| `duration` | 时长格式化 | `${seconds\|duration}` |

## 🎯 逻辑控制语法

STRP 模板引擎支持强大的逻辑控制结构，让你能够创建动态和条件化的模板内容。

### 1. 条件判断 (if/endif)

#### 基础条件判断
```lua
{% if user.level >= 10 %}
恭喜！您已达到高级用户级别！
{% endif %}

-- 带变量的条件
{% if user.vip %}
VIP用户专享特权
{% endif %}
```

#### 复杂条件表达式
```lua
-- 数值比较
{% if player.hp > player.max_hp * 0.5 %}
生命值充足
{% endif %}

-- 字符串比较
{% if user.rank == "admin" %}
管理员功能
{% endif %}

-- 组合条件
{% if user.level >= 20 and user.vip %}
高级VIP用户福利
{% endif %}
```

### 2. 循环结构

#### for-in 数组循环
```lua
-- 遍历数组
{% for item in inventory %}
物品: ${item.name} x${item.count}
{% endfor %}

-- 遍历玩家列表
{% for player in players %}
${player.name} - Lv.${player.level}
{% endfor %}
```

#### for-in 键值对循环
```lua
-- 遍历属性表
{% for key, value in player.stats %}
${key}: ${value}
{% endfor %}

-- 遍历配置项
{% for setting, val in config %}
${setting} = ${val}
{% endfor %}
```

#### 循环中的特殊应用
```lua
-- 生成技能列表
{% for skill in player.skills %}
【${skill.type}】${skill.name}
伤害: ${skill.damage} | 冷却: ${skill.cooldown}s
{% endfor %}

-- 生成排行榜
{% for rank, player in leaderboard %}
第${rank}名: ${player.name} (${player.score}分)
{% endfor %}
```

### 3. while 循环

#### 基础 while 循环
```lua
-- 计数循环
{% while count < 5 %}
第${count}次循环
{% endwhile %}

-- 条件循环
{% while player.exp >= next_level_exp %}
玩家升级了！当前等级: ${player.level}
{% endwhile %}
```

### 4. 作用域控制 (with)

#### 简化变量访问
```lua
-- 使用 with 简化深层对象访问
{% with player.inventory.weapon as weapon %}
武器名称: ${weapon.name}
武器类型: ${weapon.type}
攻击力: ${weapon.damage}
{% endwith %}

-- 另一种语法形式
{% with weapon = player.inventory.weapon %}
武器描述: ${weapon.description}
耐久度: ${weapon.durability}/${weapon.max_durability}
{% endwith %}
```

#### 临时变量计算
```lua
{% with total_damage = player.base_damage + weapon.damage %}
总攻击力: ${total_damage}
暴击伤害: ${total_damage * 1.5}
{% endwith %}
```

### 5. 选择结构 (switch/case)

#### 基础选择结构
```lua
{% switch player.class %}
{% case "warrior" %}
⚔️ 战士 - 近战物理职业
技能: 冲锋、盾击、战吼
{% case "mage" %}
🔮 法师 - 远程魔法职业  
技能: 火球术、冰霜箭、传送
{% case "archer" %}
🏹 弓箭手 - 远程物理职业
技能: 多重射击、陷阱、鹰眼
{% default %}
🤷 未知职业
{% endswitch %}
```

#### 动态选择
```lua
{% switch item.rarity %}
{% case "common" %}
品质: ${item.name|color:white}
{% case "rare" %}
品质: ${item.name|color:blue}
{% case "epic" %}
品质: ${item.name|color:purple}
{% case "legendary" %}
品质: ${item.name|color:orange}
{% default %}
品质: ${item.name}
{% endswitch %}
```

### 6. 错误处理 (try/catch)

#### 基础错误处理
```lua
{% try %}
玩家数据: ${player.stats.unknown_stat}
{% catch error %}
数据加载失败: ${error}
{% endtry %}
```

#### 安全的属性访问
```lua
{% try %}
装备信息: ${player.equipment.armor.defense}
{% catch %}
未装备护甲
{% endtry %}
```

### 7. 宏定义 (macro)

#### 无参数宏
```lua
{% macro signature %}
————————————————
游戏版本: v1.0.0
开发团队: XYZ Studio
{% endmacro %}

-- 使用宏
${signature()}
```

#### 带参数宏
```lua
{% macro damage_display(damage, type, critical=false) %}
{% if critical %}
💥 暴击！造成 ${damage|color:red} 点${type}伤害
{% else %}
⚔️ 造成 ${damage} 点${type}伤害
{% endif %}
{% endmacro %}

-- 使用带参数的宏
${damage_display(150, "物理", true)}
${damage_display(80, "魔法")}
```

#### 复杂宏示例
```lua
{% macro player_card(player, show_stats=true) %}
【${player.class}】${player.name} 
等级: ${player.level} | 经验: ${player.exp}/${player.next_level_exp}
{% if show_stats %}
属性: 攻击${player.attack} 防御${player.defense} 敏捷${player.agility}
{% endif %}
{% endmacro %}

-- 使用复杂宏
${player_card(current_player)}
${player_card(enemy_player, false)}
```

### 8. 逻辑结构组合应用

#### 游戏战斗日志模板
```lua
{% for action in battle_log %}
{% switch action.type %}
{% case "attack" %}
${action.attacker.name} 攻击 ${action.target.name}
{% if action.critical %}
💥 暴击！造成 ${action.damage|color:red} 伤害
{% else %}
⚔️ 造成 ${action.damage} 伤害  
{% endif %}

{% case "heal" %}
${action.caster.name} 治疗 ${action.target.name}
💚 恢复 ${action.amount|color:green} 生命值

{% case "skill" %}
${action.caster.name} 使用技能【${action.skill.name}】
{% if action.targets %}
{% for target in action.targets %}
对 ${target.name} 造成 ${target.damage} 伤害
{% endfor %}
{% endif %}

{% endswitch %}
{% endfor %}
```

#### 物品详情模板
```lua
{% with item as current_item %}
📦 ${current_item.name}

{% switch current_item.type %}
{% case "weapon" %}
⚔️ 武器类型: ${current_item.weapon_type}
💪 攻击力: ${current_item.damage}
{% if current_item.enchants %}
🔮 附魔效果:
{% for enchant in current_item.enchants %}
  • ${enchant.name}: ${enchant.description}
{% endfor %}
{% endif %}

{% case "armor" %}
🛡️ 护甲类型: ${current_item.armor_type}  
🛡️ 防御力: ${current_item.defense}

{% case "consumable" %}
🧪 消耗品
📝 效果: ${current_item.effect}
{% if current_item.duration %}
⏱️ 持续时间: ${current_item.duration}秒
{% endif %}

{% endswitch %}

💰 价值: ${current_item.value} 金币
{% if current_item.description %}
📖 描述: ${current_item.description}
{% endif %}
{% endwith %}
```

### 9. 性能提示

#### 循环优化
```lua
-- ✅ 推荐：预先计算条件
{% with players_count = #players %}
{% if players_count > 0 %}
在线玩家 (${players_count}):
{% for player in players %}
${player.name}
{% endfor %}
{% endif %}
{% endwith %}

-- ❌ 避免：在循环中重复计算
{% for player in players %}
{% if #players > 10 %}  <!-- 每次循环都计算 -->
${player.name}
{% endif %}
{% endfor %}
```

#### 嵌套控制
```lua
-- 合理控制嵌套深度，避免过深的结构
{% if user.is_admin %}
  {% for section in admin_sections %}
    {% switch section.type %}
    {% case "users" %}
      <!-- 用户管理内容 -->
    {% case "settings" %}  
      <!-- 设置管理内容 -->
    {% endswitch %}
  {% endfor %}
{% endif %}
```

## 🔍 高级用法

### 复杂嵌套场景

```lua
-- 游戏角色信息卡片
local template = [[
【${type}】${name} Lv.${level}
装备: ${inventory.weapon.name|color:${quality_colors[${inventory.weapon.quality}]}}
属性: 攻击力 ${stats.attack|format:'%d'} | 防御力 ${stats.defense|format:'%d'}
]]

local env = {
    type = "法师",
    name = "艾莉丝",
    level = 35,
    inventory = {
        weapon = {
            name = "法杖",
            quality = "epic"
        }
    },
    stats = {
        attack = 245,
        defense = 128
    },
    quality_colors = {
        common = "#FFFFFF",
        rare = "#0080FF", 
        epic = "#8000FF"
    }
}

local result = engine:render(template, env)
```

### 动态内容生成

```lua
-- 战斗结果模板
local battle_template = [[
🏆 战斗胜利!
${winner.name} 击败了 ${loser.name}
获得经验: ${rewards.exp|format:'%d'}
获得金币: ${rewards.gold|format:'%d'}
${#rewards.items > 0 and '掉落物品:' or ''}${rewards.items[0].name|default:''}
]]

-- 商店物品展示
local shop_template = [[
📦 ${item.name}
💰 价格: ${item.price|format:'%d金币'}
📊 评级: ${item.rating|color:${rating_colors[${item.rating}]}}
📝 ${item.description|default:'暂无描述'}
]]
```

## ⚙️ 配置选项

```lua
-- 创建带配置的实例
local engine = New 'Strp' {
    cache = true,                    -- 启用缓存
    recursive = true,                -- 启用递归渲染
    max_recursive_depth = 10,        -- 最大递归深度
    debug = false,                   -- 调试模式
    autoescape = false,              -- 自动HTML转义
    error_handling = "strict"        -- 错误处理策略: "strict"|"ignore"|"replace"
}
```

## 🚀 性能优化建议

### 1. 合理使用缓存
```lua
-- 频繁使用的模板启用缓存
local result = engine:render_cached(template, env)

-- 一次性使用的模板禁用缓存
local result = engine:render_direct(template, env)
```

### 2. 预注册常用模板
```lua
-- 预注册减少重复编译
engine:register_template("damage_text", "${damage|color:red}dmg")
engine:register_template("heal_text", "+${heal|color:green}hp")
```

### 3. 批量预热
```lua
-- 游戏启动时预热常用模板
engine:warm_cache({
    "Level ${level} ${class}",
    "HP: ${hp}/${max_hp}",
    "MP: ${mp}/${max_mp}"
})
```

## 🛡️ 错误处理

### 错误处理策略
```lua
-- 严格模式 - 遇到错误立即抛出异常
local engine = New 'Strp' {error_handling = "strict"}

-- 忽略模式 - 错误位置返回空字符串
local engine = New 'Strp' {error_handling = "ignore"}

-- 替换模式 - 显示错误信息
local engine = New 'Strp' {error_handling = "replace"}
```

### 常见错误及解决方案

| 错误类型 | 原因 | 解决方案 |
|----------|------|----------|
| 变量不存在 | `${undefined_var}` | 使用 `default` 过滤器 |
| 深度嵌套 | 递归层数过多 | 检查模板循环引用 |
| 过滤器不存在 | 使用未定义过滤器 | 检查过滤器名称拼写 |
| 数组越界 | 索引超出范围 | 添加边界检查 |

## 📈 性能监控

```lua
-- 获取详细统计信息
local stats = engine:get_cache_stats()
print("模板缓存:")
print("- 命中率:", stats.template_cache.hit_rate)
print("- 缓存大小:", stats.template_cache.size)
print("- 总请求:", stats.template_cache.total_requests)

-- 健康检查
local health = engine:health_check()
if health.memory_warning then
    print("⚠️ 内存使用过高:", health.memory_usage)
end
```

## 🔧 扩展开发

### 自定义过滤器
```lua
local filters = require 'wl.tools.strp.filters'

-- 添加自定义过滤器
filters.add_filter('currency', function(amount, currency_type)
    local symbols = {
        gold = "💰",
        diamond = "💎",
        coin = "🪙"
    }
    return (symbols[currency_type] or "") .. tostring(amount)
end)

-- 使用自定义过滤器
local result = engine:render("余额: ${balance|currency:'gold'}", {balance = 1000})
-- 输出: 余额: 💰1000
```

## 📋 最佳实践

### 1. 模板组织
```lua
-- 按功能分类注册模板
engine:register_template("ui.player_name", "${name|color:${name_color}}")
engine:register_template("ui.health_bar", "❤️ ${hp}/${max_hp}")
engine:register_template("ui.mana_bar", "💙 ${mp}/${max_mp}")

-- 组合使用
local ui_template = "${ui.player_name} ${ui.health_bar} ${ui.mana_bar}"
```

### 2. 数据结构设计
```lua
-- 推荐的环境变量结构
local env = {
    player = {
        name = "勇者",
        level = 20,
        stats = {hp = 100, max_hp = 100, mp = 50, max_mp = 50}
    },
    ui = {
        colors = {primary = "#FF6B6B", secondary = "#4ECDC4"},
        themes = {current = "dark"}
    },
    game = {
        time = os.time(),
        weather = "sunny"
    }
}
```

### 3. 性能优化
```lua
-- 避免在循环中创建新实例
local engine = New 'Strp' ()  -- 复用实例

-- 批量处理
local templates = {
    "Player: ${name}",
    "Level: ${level}",
    "Score: ${score}"
}
engine:warm_cache(templates)  -- 预热缓存
```

## 📚 API 参考

### 核心方法
- `engine:render(template, env, options)` - 渲染模板
- `engine:render_by_name(name, env, options)` - 按名称渲染
- `engine:register_template(name, template)` - 注册模板
- `engine:clear_cache()` - 清理缓存
- `engine:get_cache_stats()` - 获取统计信息

### 工具方法
- `engine:warm_cache(templates, options)` - 预热缓存
- `engine:health_check()` - 健康检查
- `engine:get_version()` - 获取版本
- `engine:list_templates()` - 列出注册的模板

## 🏷️ 版本信息

- **当前版本**: 2.1.0
- **兼容性**: Lua 5.1+, Y3 编辑器
- **依赖**: Y3 Class 系统, UTF-8 扩展库

## 📄 许可证

本项目遵循 MIT 许可证开源协议。

---

**STRP 模板引擎** - 让动态内容生成变得简单而强大！ 🚀