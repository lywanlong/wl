require "y3"

-- 万龙全局方法类
---@class Wl
wl = {}

wl.version = 250813

--- 向量类
Vector2 = require 'wl.type.Vector2'.create

--- 引力场
wl.force_field = require 'wl.object.runtime_object.force_field'
