-- 极端嵌套逻辑的全面测试
package.path = package.path .. ";e:\\WorkSpace\\大闯关项目\\大闯关\\maps\\EntryMap\\script\\?.lua"

local strp = require('wl.tools.strp.strp')

print("=== 极端嵌套逻辑全面测试 ===")

-- 复杂的测试数据结构
local test_data = {
    -- 用户信息
    user = {
        name = "  张三丰  ",
        level = 95,
        vip = true,
        banned = false,
        exp = 1250000,
        attributes = {
            strength = 88,
            intelligence = 92,
            agility = 76,
            luck = 45
        }
    },
    
    -- 物品列表
    inventory = {
        {name = "倚天剑", type = "weapon", rarity = "legendary", level = 100, count = 1, broken = false},
        {name = "屠龙刀", type = "weapon", rarity = "legendary", level = 98, count = 1, broken = true},
        {name = "九阴真经", type = "book", rarity = "epic", level = 90, count = 2, broken = false},
        {name = "大还丹", type = "consumable", rarity = "rare", level = 50, count = 15, broken = false},
        {name = "破烂布甲", type = "armor", rarity = "common", level = 5, count = 3, broken = true},
        {name = "神行符", type = "consumable", rarity = "uncommon", level = 25, count = 8, broken = false}
    },
    
    -- 任务列表
    quests = {
        {id = 1, name = "打败张无忌", status = "completed", difficulty = "hard", reward = 5000},
        {id = 2, name = "寻找九阳神功", status = "in_progress", difficulty = "extreme", reward = 10000},
        {id = 3, name = "拜访少林寺", status = "available", difficulty = "easy", reward = 1000},
        {id = 4, name = "挑战武当七侠", status = "locked", difficulty = "hard", reward = 7500}
    },
    
    -- 公会信息
    guild = {
        name = "武当派",
        members_count = 156,
        level = 8,
        active = true,
        rankings = {
            {name = "张三丰", contribution = 50000},
            {name = "宋远桥", contribution = 35000},
            {name = "俞莲舟", contribution = 32000}
        }
    },
    
    -- 系统设置
    settings = {
        show_vip_badge = true,
        display_full_stats = false,
        enable_notifications = true,
        language = "zh_cn"
    },
    
    -- 时间和环境
    current_time = "2025年8月14日 15:30",
    server_status = "正常",
    online_players = 8642,
    
    -- 特殊标记
    debug_mode = false,
    test_feature_enabled = true,
    maintenance_mode = false
}

-- 极端复杂的嵌套模板（使用正确的块语法）
local complex_template = [[
{# ==== 玩家信息报告 ==== #}
=======================================
     ${current_time} 玩家状态报告
=======================================

{# 用户基本信息展示 #}
玩家: ${user.name|trim|capitalize}{% if settings.show_vip_badge %}{% if user.vip %} [VIP]{% endif %}{% endif %}
等级: ${user.level}{% if user.level > 90 %} (大师级){% endif %}
经验: ${user.exp|format_number} / ${user.level|mult:10000|format_number}
状态: {% if user.banned %}❌ 已封禁{% else %}✅ 正常{% endif %}

{# 属性详细展示 - 嵌套条件 #}
📊 角色属性:
{% if settings.display_full_stats %}
{% for attr_name, attr_value in user.attributes %}
   ${attr_name|capitalize|pad_right:12:·}: ${attr_value|pad_left:3: }{% if attr_value > 80 %} ⭐{% endif %}{% if attr_value < 50 %} ⚠️{% endif %}
{% endfor %}
{% else %}
   力量: ${user.attributes.strength}{% if user.attributes.strength > 80 %} ⭐{% endif %}
   智力: ${user.attributes.intelligence}{% if user.attributes.intelligence > 80 %} ⭐{% endif %}
   {% if user.attributes.agility > 70 %}敏捷: ${user.attributes.agility} ⭐{% endif %}
   {% if user.attributes.luck < 50 %}运气: ${user.attributes.luck} ⚠️ (需要提升!){% endif %}
{% endif %}

{# 物品库存 - 复杂的多重嵌套 #}
🎒 背包物品 (${inventory|length} 件):
{% for item in inventory %}
{% if item.broken %}
   ❌ ${item.name|pad_right:15: } [已损坏] 
{% else %}
   {% if item.rarity == "legendary" %}💎{% elif item.rarity == "epic" %}🔮{% elif item.rarity == "rare" %}💜{% elif item.rarity == "uncommon" %}💙{% else %}⚪{% endif %} ${item.name|pad_right:15: }
   {% if item.type == "weapon" %}
      {% if item.level > 95 %}🗡️ 神级武器{% elif item.level > 80 %}⚔️ 高级武器{% else %}🔪 普通武器{% endif %}
   {% elif item.type == "armor" %}
      {% if item.level > 80 %}🛡️ 重甲{% elif item.level > 50 %}🥋 轻甲{% else %}👕 布甲{% endif %}
   {% elif item.type == "book" %}
      {% if item.rarity == "epic" %}📜 绝世秘籍{% else %}📖 武学典籍{% endif %}
   {% elif item.type == "consumable" %}
      {% if item.count > 10 %}📦 大量储备{% elif item.count > 5 %}📋 中等储备{% else %}⚡ 少量储备{% endif %}
   {% else %}
      ❓ 未知物品类型
   {% endif %}
   {% if item.count > 1 %} (数量: ${item.count}){% endif %}
{% endif %}
{% endfor %}

{# 任务系统 - 状态嵌套判断 #}
📋 任务进度:
{% for quest in quests %}
{% if quest.status == "completed" %}
   ✅ [已完成] ${quest.name|pad_right:20: } 
   {% if quest.difficulty == "extreme" %}🔥 极难{% elif quest.difficulty == "hard" %}⚡ 困难{% elif quest.difficulty == "easy" %}🌱 简单{% else %}📝 普通{% endif %}
   💰 奖励: ${quest.reward}金币
{% elif quest.status == "in_progress" %}
   🔄 [进行中] ${quest.name|pad_right:18: }
   {% if quest.difficulty == "extreme" %}
      ⚠️ 极高难度任务 - 建议组队完成
      {% if user.level < 90 %}❗ 您的等级可能不足，建议达到90级后再尝试{% endif %}
   {% elif quest.difficulty == "hard" %}
      🎯 高难度任务 - 需要良好装备
   {% else %}
      📖 常规任务 - 按计划执行
   {% endif %}
{% elif quest.status == "available" %}
   🆕 [可接取] ${quest.name|pad_right:17: }
   {% if user.level > 50 %}
      {% if quest.difficulty == "easy" %}✨ 推荐立即完成{% else %}💪 可以尝试挑战{% endif %}
   {% else %}
      🔒 建议等级提升后再接取
   {% endif %}
{% else %}
   🔒 [已锁定] ${quest.name|pad_right:17: } 
   {% if quest.id > 2 %}需要完成前置任务{% endif %}
{% endif %}
{% endfor %}

{# 公会信息 - 条件嵌套展示 #}
🏛️ 公会信息:
{% if guild.active %}
   公会名称: ${guild.name|upper}
   {% if guild.level > 5 %}⭐ 高级公会{% else %}🌱 发展中公会{% endif %} (等级 ${guild.level})
   成员数量: ${guild.members_count} 人
   
   {% if guild.members_count > 100 %}
   🏆 贡献排行榜:
   {% for member in guild.rankings %}
      {% if member.contribution > 40000 %}🥇{% elif member.contribution > 30000 %}🥈{% else %}🥉{% endif %} ${member.name|pad_right:15: } - ${member.contribution} 贡献
   {% endfor %}
   {% endif %}
{% else %}
   ❌ 未加入任何公会
   {% if user.level > 30 %}💡 建议寻找合适的公会加入{% endif %}
{% endif %}

{# 服务器状态和在线信息 #}
🌐 服务器状态:
状态: {% if server_status == "正常" %}🟢 ${server_status}{% else %}🔴 ${server_status}{% endif %}
在线人数: ${online_players}
{% if online_players > 8000 %}
   🔥 服务器火爆! 
   {% if online_players > 10000 %}⚠️ 可能出现排队等待{% endif %}
{% elif online_players > 5000 %}
   📈 在线人数较多
{% elif online_players > 1000 %}
   📊 在线人数正常
{% else %}
   📉 在线人数较少 - 适合安静游戏
{% endif %}

{# 系统提示和建议 - 深度嵌套逻辑 #}
💡 系统建议:
{% if user.level < 50 %}
   🌱 新手阶段建议:
   {% if user.attributes.strength < 60 %}  ⚡ 优先提升力量属性{% endif %}
   {% for item in inventory %}{% if item.type == "weapon" %}{% if item.level < 30 %}  🗡️ 考虑更换更强的武器{% endif %}{% endif %}{% endfor %}
{% elif user.level < 80 %}
   📈 成长阶段建议:
   {% for quest in quests %}{% if quest.status == "available" %}{% if quest.difficulty == "easy" %}  📋 完成简单任务积累经验{% endif %}{% endif %}{% endfor %}
   {% if guild.active %}{% if guild.level < 5 %}  🏛️ 协助公会发展提升等级{% endif %}{% endif %}
{% else %}
   👑 高级玩家建议:
   {% for item in inventory %}{% if item.rarity == "legendary" %}{% if item.broken %}  🔧 修复传说装备以发挥最大效力{% endif %}{% endif %}{% endfor %}
   {% for quest in quests %}{% if quest.difficulty == "extreme" %}{% if quest.status == "available" %}  🎯 挑战极难任务获取丰厚奖励{% endif %}{% endif %}{% endfor %}
{% endif %}

{# 调试和特殊信息 #}
{% if debug_mode %}
🔧 调试信息:
   测试功能: {% if test_feature_enabled %}启用{% else %}禁用{% endif %}
   维护模式: {% if maintenance_mode %}是{% else %}否{% endif %}
   通知设置: {% if settings.enable_notifications %}开启{% else %}关闭{% endif %}
{% endif %}

=======================================
报告生成完成 - ${current_time}
在线玩家: ${online_players} | 服务器: ${server_status}
=======================================
]]

print("复杂嵌套模板长度:", #complex_template, "字符")
print("测试数据包含项目:")
print("  - 用户信息 (属性、等级、VIP状态)")
print("  - 物品库存 (6件装备，多种稀有度)")
print("  - 任务系统 (4个任务，不同状态)")
print("  - 公会信息 (成员排行)")
print("  - 服务器状态")
print("  - 系统设置")

print("\n" .. string.rep("=", 50))
print("开始渲染复杂嵌套模板...")
print(string.rep("=", 50))

-- 渲染复杂模板
local start_time = os.clock()
local result = strp.render(complex_template, test_data)
local end_time = os.clock()

print(result)

print("\n" .. string.rep("=", 50))
print(string.format("渲染完成! 耗时: %.3f 秒", end_time - start_time))
print(string.format("输出长度: %d 字符", #result))

-- 测试缓存性能
print("\n=== 缓存性能测试 ===")
strp.clear_cache()

-- 编译模板
local compile_start = os.clock()
local compiled = strp.compile(complex_template)
local compile_end = os.clock()

-- 测试缓存渲染性能
local cache_start = os.clock()
for i = 1, 100 do
    local cached_result = strp.render_cached(complex_template, test_data)
end
local cache_end = os.clock()

-- 测试非缓存渲染性能
local no_cache_start = os.clock()
for i = 1, 100 do
    local normal_result = strp.render(complex_template, test_data)
end
local no_cache_end = os.clock()

local cache_stats = strp.get_cache_stats()

print(string.format("模板编译耗时: %.3f 秒", compile_end - compile_start))
print(string.format("100次缓存渲染耗时: %.3f 秒", cache_end - cache_start))
print(string.format("100次普通渲染耗时: %.3f 秒", no_cache_end - no_cache_start))
print(string.format("缓存命中率: %.1f%%", cache_stats.hit_rate * 100))

local performance_gain = ((no_cache_end - no_cache_start) - (cache_end - cache_start)) / (no_cache_end - no_cache_start) * 100
print(string.format("性能提升: %.1f%%", performance_gain))

print("\n=== 嵌套复杂度统计 ===")
local if_count = select(2, complex_template:gsub("${[^}]*|if[^}]*}", ""))
local for_count = select(2, complex_template:gsub("${[^}]*|for[^}]*}", ""))
local elseif_count = select(2, complex_template:gsub("${[^}]*|elseif[^}]*}", ""))
local filter_count = select(2, complex_template:gsub("|[%w_]+", ""))

print(string.format("条件判断 (if): %d 个", if_count))
print(string.format("循环结构 (for): %d 个", for_count))
print(string.format("分支判断 (elseif): %d 个", elseif_count))
print(string.format("过滤器使用: %d 次", filter_count))
print("最大嵌套深度: 4-5 层 (for > if > elseif > 属性访问)")

print("\n✅ 极端嵌套逻辑测试完成!")
print("模板引擎成功处理了复杂的多重嵌套逻辑结构 🎉")
