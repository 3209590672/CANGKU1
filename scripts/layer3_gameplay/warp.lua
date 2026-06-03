--[[
Layer 3 - 游戏逻辑层：折跃系统模块
职责：折跃能量收集、充能、折跃激活
--]]

local Config = require("layer4_content/config")

local Warp = {}
Warp.__index = Warp

--- 创建折跃系统
---@return table Warp实例
function Warp.new()
    local self = setmetatable({}, Warp)
    local cfg = Config.warp
    self.energy = 0                 -- 当前能量（水晶数）
    self.maxEnergy = cfg.maxEnergy
    self.charging = false           -- 正在长按充能
    self.chargeTimer = 0
    self.chargeTime = cfg.chargeTime
    self.active = false             -- 折跃是否激活
    self.timer = 0
    self.duration = cfg.duration
    self.speed = cfg.speed
    return self
end

--- 更新折跃逻辑
---@param dt number
---@param isChargeKeyDown boolean 是否按住充能键
---@return number|nil 如果折跃激活，返回折跃速度；否则nil
function Warp:update(dt, isChargeKeyDown)
    -- 激活中
    if self.active then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self.active = false
            return nil
        end
        return self.speed
    end

    -- 充能中
    if self.charging then
        if isChargeKeyDown then
            self.chargeTimer = self.chargeTimer - dt
            if self.chargeTimer <= 0 then
                -- 启动折跃
                self.active = true
                self.timer = self.duration
                self.charging = false
                self.energy = 0
                return self.speed
            end
        else
            -- 松开按键取消
            self.charging = false
            self.chargeTimer = 0
        end
        return nil
    end

    -- 能量满时按键开始充能
    if self.energy >= self.maxEnergy and isChargeKeyDown then
        self.charging = true
        self.chargeTimer = self.chargeTime
    end

    return nil
end

--- 收集能量（收集水晶时调用）
function Warp:addEnergy(amount)
    amount = amount or 1
    self.energy = math.min(self.energy + amount, self.maxEnergy)
end

--- 是否满能量
function Warp:isFull()
    return self.energy >= self.maxEnergy
end

--- 是否正在折跃
function Warp:isActive()
    return self.active
end

--- 是否正在充能
function Warp:isCharging()
    return self.charging
end

--- 获取充能进度（0~1）
function Warp:getChargeProgress()
    if not self.charging then return 0 end
    return 1.0 - (self.chargeTimer / self.chargeTime)
end

--- 获取折跃剩余时间
function Warp:getRemaining()
    return self.timer
end

--- 获取能量比（0~1）
function Warp:getEnergyRatio()
    return self.energy / self.maxEnergy
end

--- 重置
function Warp:reset()
    self.energy = 0
    self.charging = false
    self.chargeTimer = 0
    self.active = false
    self.timer = 0
end

return Warp
