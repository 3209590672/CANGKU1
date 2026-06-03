--[[
Layer 3 - 游戏逻辑层：飞船控制模块
职责：飞船移动、倾斜视觉、翻滚技能、引擎拖尾
--]]

local Config = require("layer4_content/config")

local Ship = {}
Ship.__index = Ship

--- 创建飞船控制器
---@param scene userdata UrhoX Scene
---@param matCache table MaterialCache实例
---@return table Ship实例
function Ship.new(scene, matCache)
    local self = setmetatable({}, Ship)
    self._scene = scene
    self._matCache = matCache

    -- 状态数据
    self.x = 0.0
    self.y = 0.0
    self.velX = 0.0
    self.velY = 0.0
    self.tiltX = 0.0
    self.tiltZ = 0.0
    self.moveRangeX = 6.0
    self.moveRangeY = 3.2

    -- 翻滚状态
    self.rollActive = false
    self.rollTimer = 0
    self.rollDirection = 0
    self.rollAngle = 0
    self.rollCdLeft = 0
    self.rollCdRight = 0
    self.rollWobbleTimer = 0
    self.rollWobbleDir = 0

    -- 节点引用
    self.node = nil
    self.shieldNode = nil
    self.engineTrails = nil
    self.engineTrailParticles = nil
    self.exhaustSparkBBS = nil
    self.exhaustSparkData = nil

    return self
end

--- 获取飞船半径
function Ship:getRadius()
    return Config.ship.radius
end

--- 获取飞船位置
function Ship:getPosition()
    if self.node then
        return self.node.position
    end
    return Vector3(self.x, self.y, 0)
end

--- 更新飞船移动（每帧调用）
---@param dt number deltaTime
---@param inputH number 水平输入(-1,0,+1)
---@param inputV number 垂直输入(-1,0,+1)
---@param speed number 当前飞行速度
---@param warpActive boolean 是否折跃中
function Ship:update(dt, inputH, inputV, speed, warpActive)
    local cfg = Config.ship
    local accel = cfg.accel
    local decel = cfg.decel
    local moveSpeed = cfg.moveSpeed

    -- 翻滚时锁定水平输入
    local moveX = self.rollActive and 0 or inputH
    local moveY = inputV

    -- 速度平滑
    if moveX ~= 0 then
        self.velX = self.velX + moveX * accel * dt
        self.velX = math.max(-moveSpeed, math.min(moveSpeed, self.velX))
    else
        if self.velX > 0 then
            self.velX = math.max(0, self.velX - decel * dt)
        elseif self.velX < 0 then
            self.velX = math.min(0, self.velX + decel * dt)
        end
    end

    if moveY ~= 0 then
        self.velY = self.velY + moveY * accel * dt
        self.velY = math.max(-moveSpeed, math.min(moveSpeed, self.velY))
    else
        if self.velY > 0 then
            self.velY = math.max(0, self.velY - decel * dt)
        elseif self.velY < 0 then
            self.velY = math.min(0, self.velY + decel * dt)
        end
    end

    -- 更新位置
    self.x = self.x + self.velX * dt
    self.y = self.y + self.velY * dt

    -- 边界限制
    if self.x < -self.moveRangeX then self.x = -self.moveRangeX; self.velX = 0 end
    if self.x > self.moveRangeX then self.x = self.moveRangeX; self.velX = 0 end
    if self.y < -self.moveRangeY then self.y = -self.moveRangeY; self.velY = 0 end
    if self.y > self.moveRangeY then self.y = self.moveRangeY; self.velY = 0 end

    -- 待机微晃动
    local idleFactor = 1.0 - math.min(1.0, (math.abs(self.velX) + math.abs(self.velY)) / moveSpeed)
    local t = time.elapsedTime
    local idleX = math.sin(t * 1.2) * 0.06 * idleFactor
    local idleY = math.sin(t * 0.9 + 1.5) * 0.04 * idleFactor

    -- 应用位置
    if self.node then
        self.node.position = Vector3(self.x + idleX, self.y + idleY, 0)
    end

    -- 倾斜视觉
    local tiltRatioX = self.velX / moveSpeed
    local tiltRatioY = self.velY / moveSpeed
    local targetTiltZ = -tiltRatioX * 30
    local targetTiltX = tiltRatioY * 12
    local lerpSpeed = 6.0 * dt
    self.tiltZ = self.tiltZ + (targetTiltZ - self.tiltZ) * lerpSpeed
    self.tiltX = self.tiltX + (targetTiltX - self.tiltX) * lerpSpeed
    if math.abs(self.tiltZ) < 0.01 then self.tiltZ = 0 end
    if math.abs(self.tiltX) < 0.01 then self.tiltX = 0 end

    -- 翻滚更新
    self:_updateRoll(dt)

    -- 应用旋转
    local finalTiltZ = self.tiltZ + self.rollAngle + self:_getWobbleAngle()
    if self.node then
        self.node.rotation = Quaternion(self.tiltX, 0, finalTiltZ)
    end
end

--- 触发翻滚
---@param direction number 1=右(E), -1=左(Q)
---@return boolean 是否成功触发
function Ship:triggerRoll(direction)
    if self.rollActive then return false end
    local cfg = Config.roll
    if direction == -1 and self.rollCdLeft > 0 then return false end
    if direction == 1 and self.rollCdRight > 0 then return false end

    self.rollActive = true
    self.rollTimer = cfg.duration
    self.rollDirection = direction
    self.rollAngle = 0
    if direction == -1 then
        self.rollCdLeft = cfg.cooldown
    else
        self.rollCdRight = cfg.cooldown
    end
    return true
end

--- 重置飞船状态
function Ship:reset()
    self.x = 0
    self.y = 0
    self.velX = 0
    self.velY = 0
    self.tiltX = 0
    self.tiltZ = 0
    self.rollActive = false
    self.rollTimer = 0
    self.rollAngle = 0
    self.rollCdLeft = 0
    self.rollCdRight = 0
    self.rollWobbleTimer = 0
    if self.node then
        self.node.position = Vector3(0, 0, 0)
        self.node.rotation = Quaternion(0, 0, 0)
        self.node:SetEnabled(true)
    end
end

--- 是否处于翻滚无敌状态
function Ship:isRolling()
    return self.rollActive
end

-- ========== 内部方法 ==========

function Ship:_updateRoll(dt)
    local cfg = Config.roll
    -- CD计时
    if self.rollCdLeft > 0 then self.rollCdLeft = self.rollCdLeft - dt end
    if self.rollCdRight > 0 then self.rollCdRight = self.rollCdRight - dt end

    if self.rollActive then
        self.rollTimer = self.rollTimer - dt
        if self.rollTimer <= 0 then
            self.rollActive = false
            self.rollAngle = 0
            self.rollWobbleTimer = cfg.wobbleDuration
            self.rollWobbleDir = self.rollDirection
        else
            self.rollAngle = (1.0 - self.rollTimer / cfg.duration) * 360.0 * self.rollDirection
            -- 翻滚位移
            self.x = self.x + self.rollDirection * 8.0 * dt
        end
    end
end

function Ship:_getWobbleAngle()
    if self.rollWobbleTimer <= 0 then return 0 end
    local cfg = Config.roll
    self.rollWobbleTimer = self.rollWobbleTimer - (1.0/60.0) -- 近似dt
    if self.rollWobbleTimer <= 0 then
        self.rollWobbleTimer = 0
        return 0
    end
    local decay = self.rollWobbleTimer / cfg.wobbleDuration
    local elapsed = cfg.wobbleDuration - self.rollWobbleTimer
    return math.sin(elapsed * 14.0) * decay * decay * 24.0 * self.rollWobbleDir
end

return Ship
