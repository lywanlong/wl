--- 引力场
---@class ForceField.Options
---@field target Point
---@field speed number      # 牵引速度
---@field direction? number # 朝向
---@field arc? number       # 扇形角度，默认360度
---@field max_speed? number # 最大牵引速度
---@field min_speed? number # 最小牵引速度
---@field accel? number     # 牵引加速度


---@class ForceField
---@overload fun(options: ForceField.Options): self
local M = Class 'ForceField'

---@class ForceField: GCHost
Extends('ForceField', 'GCHost')

---@param options ForceField.Options
---@return self
function M:__init(options)
    self.options = options
    -- self.fake_unit = y3.unit.create_unit(nil, 134280456, self.options.target, 0)
    return self
end

function M:__tostring()
    return string.format("ForceField(%s, %s)"
    , self.options.target, self.options.speed
    )
end

function M:__del()

end

function M:remove()
    Delete(self)
end

---@param options ForceField.Options
---@return ForceField
function M.create(options)
    return New 'ForceField' (options)
end

return M
