--[[
Layer 3 - 游戏逻辑层：飞船控制器
职责：飞船移动（平移/倾斜/翻滚/待机晃动）+ 折跃系统（充能/激活/结束）
依赖：gs(读写飞船状态)、inputMgr(读取输入)、shipNode(设置位置/旋转)、EngineTrails(更新拖尾)
事件：通过 eventBus 发射 warp_begin / warp_end
--]]

local math_sin = math.sin
local math_cos = math.cos
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max
local math_floor = math.floor

local M = {}

-- 依赖注入
---@type table
local gs_ = nil
---@type table
local inputMgr_ = nil
---@type Node
local shipNode_ = nil
---@type table
local EngineTrails_ = nil
---@type table
local eventBus_ = nil

--- 初始化
---@param ctx table { gs, inputMgr, shipNode, EngineTrails, eventBus }
function M.init(ctx)
    gs_ = ctx.gs
    inputMgr_ = ctx.inputMgr
    shipNode_ = ctx.shipNode
    EngineTrails_ = ctx.EngineTrails
    eventBus_ = ctx.eventBus
end

--- 更新飞船移动（每帧调用）
---@param dt number
---@param frameCount number
function M.updateMovement(dt, frameCount)
    local gs = gs_
    local moveX = 0
    local moveY = 0

    if not gs.rollActive then
        moveX = inputMgr_:getHorizontal()
    end
    moveY = inputMgr_:getVertical()

    -- 减速（折跃中不可减速）
    if not gs.warpActive and inputMgr_:isDecelerating() then
        gs.speed = math_max(10.0, gs.speed - 40 * dt)
    end

    -- 加速
    if not gs.warpActive and inputMgr_:isAccelerating() then
        gs.speed = math_min(gs.maxSpeed, gs.speed + 60 * dt)
    end

    -- 速度平滑：有输入时加速，无输入时减速
    if moveX ~= 0 then
        gs.shipVelX = gs.shipVelX + moveX * gs.shipAccel * dt
        gs.shipVelX = math_max(-gs.shipMoveSpeed, math_min(gs.shipMoveSpeed, gs.shipVelX))
    else
        if gs.shipVelX > 0 then
            gs.shipVelX = math_max(0, gs.shipVelX - gs.shipDecel * dt)
        elseif gs.shipVelX < 0 then
            gs.shipVelX = math_min(0, gs.shipVelX + gs.shipDecel * dt)
        end
    end

    if moveY ~= 0 then
        gs.shipVelY = gs.shipVelY + moveY * gs.shipAccel * dt
        gs.shipVelY = math_max(-gs.shipMoveSpeed, math_min(gs.shipMoveSpeed, gs.shipVelY))
    else
        if gs.shipVelY > 0 then
            gs.shipVelY = math_max(0, gs.shipVelY - gs.shipDecel * dt)
        elseif gs.shipVelY < 0 then
            gs.shipVelY = math_min(0, gs.shipVelY + gs.shipDecel * dt)
        end
    end

    -- 更新位置
    gs.shipX = gs.shipX + gs.shipVelX * dt
    gs.shipY = gs.shipY + gs.shipVelY * dt

    -- 限制范围（碰到边缘时清零速度）
    if gs.shipX < -gs.moveRangeX then gs.shipX = -gs.moveRangeX; gs.shipVelX = 0 end
    if gs.shipX > gs.moveRangeX then gs.shipX = gs.moveRangeX; gs.shipVelX = 0 end
    if gs.shipY < -gs.moveRangeY then gs.shipY = -gs.moveRangeY; gs.shipVelY = 0 end
    if gs.shipY > gs.moveRangeY then gs.shipY = gs.moveRangeY; gs.shipVelY = 0 end

    -- 待机微晃动（速度越小晃动越明显）
    local idleFactor = 1.0 - math_min(1.0, (math_abs(gs.shipVelX) + math_abs(gs.shipVelY)) / gs.shipMoveSpeed)
    local elapsed = time.elapsedTime
    local idleOffsetX = math_sin(elapsed * 1.2) * 0.06 * idleFactor
    local idleOffsetY = math_sin(elapsed * 0.9 + 1.5) * 0.04 * idleFactor

    -- 应用位置
    shipNode_.position = Vector3(gs.shipX + idleOffsetX, gs.shipY + idleOffsetY, 0)

    -- 倾斜视觉效果（基于速度比例，更自然）
    local tiltRatioX = gs.shipVelX / gs.shipMoveSpeed
    local tiltRatioY = gs.shipVelY / gs.shipMoveSpeed
    local targetTiltZ = -tiltRatioX * 30
    local targetTiltX = tiltRatioY * 12
    local lerpSpeed = 6.0 * dt
    gs.currentTiltZ = gs.currentTiltZ + (targetTiltZ - gs.currentTiltZ) * lerpSpeed
    gs.currentTiltX = gs.currentTiltX + (targetTiltX - gs.currentTiltX) * lerpSpeed

    if math_abs(gs.currentTiltZ) < 0.01 then gs.currentTiltZ = 0 end
    if math_abs(gs.currentTiltX) < 0.01 then gs.currentTiltX = 0 end

    -- 翻滚冷却更新
    if gs.rollCdLeftTimer > 0 then gs.rollCdLeftTimer = gs.rollCdLeftTimer - dt end
    if gs.rollCdRightTimer > 0 then gs.rollCdRightTimer = gs.rollCdRightTimer - dt end

    -- 翻滚技能：Q/E 触发（需要冷却结束）
    if not gs.rollActive then
        if inputMgr_:isRollLeftPressed() and gs.rollCdLeftTimer <= 0 then
            gs.rollActive = true
            gs.rollTimer = gs.rollDuration
            gs.rollDirection = -1
            gs.rollAngle = 0
            gs.rollCdLeftTimer = gs.rollCd
            eventBus_:emit("roll_start", -1)
        elseif inputMgr_:isRollRightPressed() and gs.rollCdRightTimer <= 0 then
            gs.rollActive = true
            gs.rollTimer = gs.rollDuration
            gs.rollDirection = 1
            gs.rollAngle = 0
            gs.rollCdRightTimer = gs.rollCd
            eventBus_:emit("roll_start", 1)
        end
    end

    -- 翻滚角度更新 + 方向位移
    if gs.rollActive then
        gs.rollTimer = gs.rollTimer - dt
        if gs.rollTimer <= 0 then
            gs.rollActive = false
            gs.rollAngle = 0
            gs.rollWobbleTimer = gs.rollWobbleDuration
            gs.rollWobbleDir = gs.rollDirection
        else
            gs.rollAngle = (1.0 - gs.rollTimer / gs.rollDuration) * 360.0 * gs.rollDirection
            local rollSpeed = 8.0
            gs.shipX = gs.shipX + gs.rollDirection * rollSpeed * dt
        end
    end

    -- 翻滚结束后摇晃衰减
    local wobbleAngle = 0
    if gs.rollWobbleTimer > 0 then
        gs.rollWobbleTimer = gs.rollWobbleTimer - dt
        if gs.rollWobbleTimer <= 0 then
            gs.rollWobbleTimer = 0
        else
            local decay = gs.rollWobbleTimer / gs.rollWobbleDuration
            local freq = 14.0
            local elapsedWobble = gs.rollWobbleDuration - gs.rollWobbleTimer
            wobbleAngle = math_sin(elapsedWobble * freq) * decay * decay * 24.0 * gs.rollWobbleDir
        end
    end

    -- 叠加翻滚+摇晃到飞船旋转（Z轴）
    local finalTiltZ = gs.currentTiltZ + gs.rollAngle + wobbleAngle
    shipNode_.rotation = Quaternion(gs.currentTiltX, 0, finalTiltZ)

    -- 引擎拖尾更新（委托模块）
    EngineTrails_.updatePlaying(dt, shipNode_, gs, frameCount)
end

--- 更新折跃系统（每帧调用）
---@param dt number
function M.updateWarp(dt)
    local gs = gs_

    -- 折跃激活中
    if gs.warpActive then
        gs.warpTimer = gs.warpTimer - dt
        gs.speed = gs.warpSpeed
        if gs.warpTimer <= 0 then
            gs.warpActive = false
            gs.speed = gs.maxSpeed * 0.5
            eventBus_:emit("warp_end")
        end
        return
    end

    -- 充能中（长按空格）
    if gs.warpCharging then
        if inputMgr_:isWarpCharging() then
            gs.warpChargeTimer = gs.warpChargeTimer - dt
            if gs.warpChargeTimer <= 0 then
                gs.warpActive = true
                gs.warpTimer = gs.warpDuration
                gs.warpCharging = false
                gs.warpEnergy = 0
                eventBus_:emit("warp_begin")
            end
        else
            gs.warpCharging = false
            gs.warpChargeTimer = 0
        end
        return
    end

    -- 能量满时按空格开始充能
    if gs.warpEnergy >= gs.warpMaxEnergy and inputMgr_:isWarpCharging() then
        gs.warpCharging = true
        gs.warpChargeTimer = gs.warpChargeTime
        eventBus_:emit("warp_charging")
    end
end

return M
