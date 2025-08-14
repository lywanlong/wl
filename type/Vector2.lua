---@class Vector2
---@field x number
---@field y number
---@overload fun(x:number, y:number):self
---@operator add (Vector2):Vector2  加法
---@operator sub (Vector2):Vector2  减法
---@operator mul (Vector2):Vector2  乘法
---@operator div (Vector2):Vector2  除法
---@operator pow (Vector2):Vector2  乘方
---@operator idiv (Vector2):Vector2  取整除
---@operator unm:integer
local M = Class "Vector2"


---@param x number
---@param y number
---@return self
function M:__init(x, y)
    self.x = x
    self.y = y
    return self
end

---@param x number
---@param y number
---@return Vector2
function M.create(x, y)
    return New "Vector2" (x, y)
end

--- 加法
---@param other Vector2
---@return Vector2
function M:__add(other)
    return New "Vector2" (self.x + other.x, self.y + other.y)
end

--- 减法
---@param other Vector2
---@return Vector2
function M:__sub(other)
    return New "Vector2" (self.x - other.x, self.y - other.y)
end

--- 乘法
---@param other Vector2
---@return Vector2
function M:__mul(other)
    return New "Vector2" (self.x * other.x, self.y * other.y)
end

--- 除法
---@param other Vector2
---@return Vector2
function M:__div(other)
    return New "Vector2" (self.x / other.x, self.y / other.y)
end

--- 乘方
---@param other Vector2
---@return Vector2
function M:__pow(other)
    return New "Vector2" (self.x ^ other.x, self.y ^ other.y)
end

--- 取整除
---@param other Vector2
---@return Vector2
function M:__idiv(other)
    return New "Vector2" (self.x // other.x, self.y // other.y)
end

---@return Vector2
function M:__unm()
    return New "Vector2" (-self.x, -self.y)
end

---tostring
---@return string
function M:__tostring()
    return "Vector2(" .. self.x .. ", " .. self.y .. ")"
end
--- 获取向量长度
---@return number
function M:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

--- 获取向量长度的平方
---@return number
function M:lengthSquared()
    return self.x * self.x + self.y * self.y
end

--- 向量标准化
---@return Vector2
function M:normalize()
    local len = self:length()
    if len > 0 then
        return New "Vector2" (self.x / len, self.y / len)
    end
    return New "Vector2" (0, 0)
end

--- 向量点积
---@param other Vector2
---@return number
function M:dot(other)
    return self.x * other.x + self.y * other.y
end

--- 向量叉积
---@param other Vector2
---@return number
function M:cross(other)
    return self.x * other.y - self.y * other.x
end

--- 获取两点之间的距离
---@param other Vector2
---@return number
function M:distance(other)
    return (other - self):length()
end

--- 获取两点之间距离的平方
---@param other Vector2
---@return number
function M:distanceSquared(other)
    return (other - self):lengthSquared()
end
--- 向量旋转（角度）
--- @param deg number
--- @return Vector2
function M:rotateDeg(deg)
    return self:rotate(math.rad(deg))
end
--- 向量旋转（弧度）
---@param rad number
---@return Vector2
function M:rotate(rad)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    return New "Vector2" (
        self.x * cos - self.y * sin,
        self.x * sin + self.y * cos
    )
end

--- 获取向量的角度（弧度）
---@return number
function M:angle()
    return math.atan(self.y, self.x)
end

-- 静态方法

--- 零向量
---@return Vector2
function M.zero()
    return New "Vector2" (0, 0)
end

--- 单位向量
---@param angle number 角度（弧度）
---@return Vector2
function M.fromAngle(angle)
    return New "Vector2" (math.cos(angle), math.sin(angle))
end

--- 线性插值
---@param a Vector2
---@param b Vector2
---@param t number 插值系数 (0-1)
---@return Vector2
function M.lerp(a, b, t)
    t = math.max(0, math.min(1, t))
    return New "Vector2" (
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t
    )
end

return M