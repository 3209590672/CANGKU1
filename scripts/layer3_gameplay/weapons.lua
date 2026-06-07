-- ============================================================================
-- weapons.lua — 射击系统（子弹生成、更新、热量管理）
-- ============================================================================
local math_max = math.max
local math_min = math.min
local table_insert = table.insert
local table_remove = table.remove

local Weapons = {}

-- 依赖注入
local scene_
local inputMgr_
local mdlBox_
local mdlSphere_
local bulletCoreMat_
local bulletGlowMat_
local bulletTrailMats_
local bulletTipMat_
local eventBus_

-- 内部状态
local bullets_ = {}
local bulletSpeed_ = 120.0
local fireRate_ = 0.12
local fireTimer_ = 0

-- 热量系统
local heat_ = 0
local heatPerShot_ = 8
local heatCoolRate_ = 15
local heatMax_ = 100
local overheated_ = false
local overheatCooldown_ = 5.0
local overheatTimer_ = 0

-- 获取飞船位置的回调
local getShipPos_ = nil

--- 初始化
-- @param ctx { scene, inputMgr, mdlBox, mdlSphere, bulletCoreMat, bulletGlowMat, bulletTrailMats, bulletTipMat, getShipPos }
function Weapons.init(ctx)
    scene_ = ctx.scene
    inputMgr_ = ctx.inputMgr
    mdlBox_ = ctx.mdlBox
    mdlSphere_ = ctx.mdlSphere
    bulletCoreMat_ = ctx.bulletCoreMat
    bulletGlowMat_ = ctx.bulletGlowMat
    bulletTrailMats_ = ctx.bulletTrailMats
    bulletTipMat_ = ctx.bulletTipMat
    getShipPos_ = ctx.getShipPos
    eventBus_ = ctx.eventBus
end

--- 重置状态（开始新游戏时调用）
function Weapons.reset()
    heat_ = 0
    overheated_ = false
    overheatTimer_ = 0
    fireTimer_ = 0
end

--- 清除所有子弹（返回菜单时调用）
function Weapons.clearBullets()
    for _, bullet in ipairs(bullets_) do
        if bullet.node then
            bullet.node:Remove()
        end
    end
    bullets_ = {}
end

--- 更新射击逻辑（含过热管理和开火）
function Weapons.updateShooting(dt)
    fireTimer_ = math_max(0, fireTimer_ - dt)

    -- 过热冷却中
    if overheated_ then
        overheatTimer_ = overheatTimer_ - dt
        if overheatTimer_ <= 0 then
            overheated_ = false
            heat_ = 0
        end
    else
        -- 正常散热
        heat_ = math_max(0, heat_ - heatCoolRate_ * dt)
    end

    -- 左键射击
    if not overheated_ and fireTimer_ <= 0 and inputMgr_:isFiring() then
        Weapons.fireBullet()
        fireTimer_ = fireRate_
        heat_ = heat_ + heatPerShot_
        if eventBus_ then eventBus_:emit("bullet_fired") end

        -- 过热判断
        if heat_ >= heatMax_ then
            overheated_ = true
            overheatTimer_ = overheatCooldown_
        end
    end
end

--- 发射子弹（双管）
function Weapons.fireBullet()
    local shipX, shipY = getShipPos_()

    for side = -1, 1, 2 do
        local node = scene_:CreateChild("Bullet")
        node.position = Vector3(shipX + side * 0.65, shipY - 0.06, 2.0)

        -- 子弹核心（明亮能量弹头）
        local core = node:CreateChild("Core")
        core.scale = Vector3(0.07, 0.07, 0.45)
        local coreModel = core:CreateComponent("StaticModel")
        coreModel:SetModel(mdlBox_)
        coreModel:SetMaterial(bulletCoreMat_)

        -- 外层光晕（稍大半透明包裹）
        local glow = node:CreateChild("Glow")
        glow.scale = Vector3(0.15, 0.15, 0.6)
        local glowModel = glow:CreateComponent("StaticModel")
        glowModel:SetModel(mdlBox_)
        glowModel:SetMaterial(bulletGlowMat_)

        -- 曳光拖尾（5段渐隐）
        local trails = {}
        for i = 1, 5 do
            local trail = node:CreateChild("Trail")
            local zOffset = -0.35 * i
            trail.position = Vector3(0, 0, zOffset)
            local fade = 1.0 - (i / 6)
            local trailWidth = 0.09 * fade * fade + 0.015
            local trailLen = 0.28 * fade + 0.06
            trail.scale = Vector3(trailWidth, trailWidth, trailLen)

            local trailModel = trail:CreateComponent("StaticModel")
            trailModel:SetModel(mdlBox_)
            trailModel:SetMaterial(bulletTrailMats_[i])
            trails[i] = trail
        end

        -- 曳光芯线（中心细长高亮线条）
        local tracerLine = node:CreateChild("Tracer")
        tracerLine.scale = Vector3(0.02, 0.02, 2.2)
        tracerLine.position = Vector3(0, 0, -1.0)
        local tracerMdl = tracerLine:CreateComponent("StaticModel")
        tracerMdl:SetModel(mdlBox_)
        tracerMdl:SetMaterial(bulletTipMat_)

        -- 子弹尖端光点
        local tip = node:CreateChild("Tip")
        tip.position = Vector3(0, 0, 0.25)
        tip.scale = Vector3(0.05, 0.05, 0.05)
        local tipModel = tip:CreateComponent("StaticModel")
        tipModel:SetModel(mdlSphere_)
        tipModel:SetMaterial(bulletTipMat_)

        table_insert(bullets_, { node = node, age = 0, glowRef = glow, tracerRef = tracerLine, trailRefs = trails })
    end
end

--- 更新子弹位置和动画
function Weapons.updateBullets(dt)
    local i = 1
    while i <= #bullets_ do
        local bullet = bullets_[i]
        local pos = bullet.node.position
        pos.z = pos.z + bulletSpeed_ * dt
        bullet.node.position = pos
        bullet.age = bullet.age + dt

        -- 曳光动态效果（三角波近似）
        local phase = (bullet.age * 35.0 + i * 5.0) % 6.2832
        local pulse = 0.85 + 0.15 * (1.0 - phase * 0.31831 * 2.0)
        if phase > 3.1416 then pulse = 0.85 + 0.15 * ((phase - 3.1416) * 0.31831 * 2.0 - 1.0) end
        local glowRef = bullet.glowRef
        if glowRef then
            glowRef.scale = Vector3(0.15 * pulse, 0.15 * pulse, 0.6 + 0.08 * pulse)
        end

        -- 尾迹渐开（仅前0.2秒内计算）
        local trailRefs = bullet.trailRefs
        if trailRefs and bullet.age < 0.25 then
            local stretch = math_min(bullet.age * 5.0, 1.0)
            for ti = 1, 5 do
                local fade = 1.0 - (ti / 6)
                local tw = (0.09 * fade * fade + 0.015) * pulse
                local tl = (0.28 * fade + 0.06) * (0.4 + 0.6 * stretch)
                trailRefs[ti].scale = Vector3(tw, tw, tl)
            end
        end

        -- 超出范围移除
        if pos.z > 130 then
            bullet.node:Remove()
            table_remove(bullets_, i)
        else
            i = i + 1
        end
    end
end

--- 获取子弹列表（碰撞检测用）
function Weapons.getBullets()
    return bullets_
end

--- 移除指定索引的子弹（碰撞命中后调用）
function Weapons.removeBulletAt(idx)
    if bullets_[idx] then
        bullets_[idx].node:Remove()
        table_remove(bullets_, idx)
    end
end

--- 热量 getters（HUD 显示用）
function Weapons.getHeat()
    return heat_
end

function Weapons.getHeatMax()
    return heatMax_
end

function Weapons.isOverheated()
    return overheated_
end

function Weapons.getOverheatTimer()
    return overheatTimer_
end

return Weapons
