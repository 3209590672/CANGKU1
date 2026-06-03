-- ============================================================================
-- engine_trails.lua — 引擎拖尾系统（光带段 + 微粒 + 火花BillboardSet）
-- ============================================================================
local math_sin = math.sin
local math_cos = math.cos
local math_sqrt = math.sqrt
local math_random = math.random
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local table_insert = table.insert

local M = {}

-- 内部状态
local engineTrails_ = nil           -- 双引擎光带段
local engineTrailParticles_ = nil   -- 微粒
local exhaustSparkBBS_ = nil        -- 火花 BillboardSet
local exhaustSparkNode_ = nil
local exhaustSparkData_ = {}
local trailLastSpeedScale_ = nil
local trailLastWarpScale_ = nil
local trailParticleFrame_ = 0
local trailPtLastWarp_ = nil
-- 翼尖 warp 拖尾
local warpWingTrailBBS_ = nil
local warpWingTrailNode_ = nil
local warpWingTrailData_ = {}

--- 创建引擎拖尾节点（光带段 + 微粒 + 火花）
---@param deps { scene: Scene, shipNode: Node, cache: ResourceCache, circleTex: Texture2D }
function M.create(deps)
    local scene = deps.scene
    local shipNode = deps.shipNode
    local cache = deps.cache
    local circleTex = deps.circleTex

    -- ================================================================
    -- 引擎拖尾（极简：少段长条 + 固定偏移，无链式追踪）
    -- ================================================================
    local trailMat = Material:new()
    trailMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    trailMat:SetShaderParameter("Metallic", Variant(0.0))
    trailMat:SetShaderParameter("Roughness", Variant(1.0))

    engineTrails_ = {}
    local trailCount = 24
    local segSpacing = 0.075
    local boxMdl = cache:GetResource("Model", "Models/Box.mdl")
    for side = -1, 1, 2 do
        local trail = { nodes = {}, baseX = side * 0.42, baseY = -0.05, baseZ = -1.4 }
        for i = 1, trailCount do
            local tn = scene:CreateChild("Trail")
            local s = 1.0 - (i - 1) / trailCount
            local thickness = 0.028 * s + 0.005
            local zLen = 0.22 + 0.12 * s
            tn.scale = Vector3(thickness, thickness, zLen)
            local tm = tn:CreateComponent("StaticModel")
            tm:SetModel(boxMdl)
            local segMat = trailMat:Clone("")
            segMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.4, 1.0, 0.45 * s)))
            segMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3 * s, 0.8 * s, 3.0 * s)))
            tm:SetMaterial(segMat)
            tm.castShadows = false
            trail.nodes[i] = tn
        end
        trail.segSpacing = segSpacing
        table_insert(engineTrails_, trail)
    end

    -- 引擎拖尾微粒
    engineTrailParticles_ = {}
    local particleCount = 20
    local sphereMdl = cache:GetResource("Model", "Models/Sphere.mdl")
    for side = -1, 1, 2 do
        for p = 1, particleCount do
            local pn = scene:CreateChild("TrailParticle")
            local pSize = 0.005 + math_random() * 0.008
            pn.scale = Vector3(pSize, pSize, pSize)
            local pm = pn:CreateComponent("StaticModel")
            pm:SetModel(sphereMdl)
            local pMat = trailMat:Clone("")
            local brightness = 0.4 + math_random() * 0.6
            pMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.3, 1.0, 0.25 * brightness)))
            pMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3 * brightness, 0.7 * brightness, 3.0 * brightness)))
            pm:SetMaterial(pMat)
            pm.castShadows = false
            local zOffset = -1.4 - math_random() * 2.5
            local xSpread = (math_random() - 0.5) * 0.12
            table_insert(engineTrailParticles_, {
                node = pn,
                baseX = side * 0.42 + xSpread,
                baseY = -0.05 + (math_random() - 0.5) * 0.06,
                baseZ = zOffset,
                phase = math_random() * 6.28,
                freq = 2.0 + math_random() * 3.0,
                amp = 0.02 + math_random() * 0.03,
                driftZ = -0.3 - math_random() * 0.7,
            })
        end
    end

    -- ================================================================
    -- 翼尖 warp 拖尾（BillboardSet，仅warp时显示）
    -- ================================================================
    warpWingTrailNode_ = scene:CreateChild("WarpWingTrail")
    warpWingTrailBBS_ = warpWingTrailNode_:CreateComponent("BillboardSet")
    local wingTrailSegs = 16
    warpWingTrailBBS_.numBillboards = wingTrailSegs * 2
    warpWingTrailBBS_.sorted = false
    warpWingTrailBBS_.relative = false
    warpWingTrailBBS_.scaled = false
    warpWingTrailBBS_.faceCameraMode = FC_ROTATE_XYZ

    local wingTrailMat = Material:new()
    wingTrailMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml"))
    wingTrailMat:SetTexture(0, circleTex)
    wingTrailMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.7, 1.0, 0.8)))
    wingTrailMat:SetShaderParameter("MatEmissiveColor", Variant(Color(1.0, 2.0, 5.0)))
    warpWingTrailBBS_:SetMaterial(wingTrailMat)

    warpWingTrailData_ = {}
    for side = -1, 1, 2 do
        local sideData = { positions = {} }
        local baseIdx = (side == -1) and 0 or wingTrailSegs
        for i = 0, wingTrailSegs - 1 do
            local bb = warpWingTrailBBS_:GetBillboard(baseIdx + i)
            bb.enabled = false
            bb.size = Vector2(0.03, 0.03)
            bb.color = Color(0.5, 0.8, 1.0, 0.0)
            bb.position = Vector3(0, 0, 0)
            sideData.positions[i + 1] = Vector3(0, 0, 0)
        end
        sideData.baseIdx = baseIdx
        sideData.wingX = side * 1.55
        sideData.wingY = -0.03
        sideData.wingZ = -0.1
        table_insert(warpWingTrailData_, sideData)
    end
    warpWingTrailBBS_:Commit()
    warpWingTrailNode_:SetEnabled(false)

    -- ================================================================
    -- 尾焰火花粒子（BillboardSet：单 draw call，30个微小火花）
    -- ================================================================
    exhaustSparkNode_ = shipNode:CreateChild("ExhaustSparks")
    exhaustSparkNode_.position = Vector3(0, 0, 0)
    exhaustSparkBBS_ = exhaustSparkNode_:CreateComponent("BillboardSet")
    local sparkCount = 30
    exhaustSparkBBS_.numBillboards = sparkCount
    exhaustSparkBBS_.sorted = false
    exhaustSparkBBS_.relative = false
    exhaustSparkBBS_.scaled = false
    exhaustSparkBBS_.faceCameraMode = FC_ROTATE_XYZ

    local sparkMat = Material:new()
    sparkMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml"))
    sparkMat:SetTexture(0, circleTex)
    sparkMat:SetShaderParameter("MatDiffColor", Variant(Color(0.5, 0.8, 1.0, 0.9)))
    sparkMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8, 1.5, 4.0)))
    exhaustSparkBBS_:SetMaterial(sparkMat)

    exhaustSparkData_ = {}
    local shipPos = shipNode.position
    local shipRot = shipNode.rotation
    for i = 0, sparkCount - 1 do
        local bb = exhaustSparkBBS_:GetBillboard(i)
        bb.enabled = true
        bb.size = Vector2(0.006, 0.006)
        bb.color = Color(0.5, 0.8, 1.0, 0.0)
        local side = (i % 2 == 0) and 0.42 or -0.42
        local localPos = Vector3(side + (math_random() - 0.5) * 0.08, -0.05, -1.5)
        bb.position = shipPos + shipRot * localPos
        bb.rotation = math_random() * 360

        local maxLife = 0.3 + math_random() * 0.5
        exhaustSparkData_[i] = {
            life = math_random() * maxLife,
            maxLife = maxLife,
            side = side,
            vx = (math_random() - 0.5) * 0.4,
            vy = (math_random() - 0.5) * 0.3,
            vz = -2.0 - math_random() * 3.0,
        }
    end
    exhaustSparkBBS_:Commit()
end

--- 游戏中更新引擎拖尾（光带段+微粒+火花）
---@param dt number
---@param shipNode Node
---@param gs table  GameState 数据
---@param frameCount number
function M.updatePlaying(dt, shipNode, gs, frameCount)
    -- 引擎拖尾光带段
    if engineTrails_ then
        local shipPos = shipNode.position
        local shipRot = shipNode.rotation

        local speedLenScale = gs.speed / 40.0
        local warpWidthScale = 1.0
        if gs.warpActive then
            local elapsed = gs.warpDuration - gs.warpTimer
            local remaining = gs.warpTimer
            if elapsed < 3.0 then
                warpWidthScale = 1.0 + (elapsed / 3.0) * 2.0
            elseif remaining < 3.0 then
                warpWidthScale = 1.0 + (remaining / 3.0) * 2.0
            else
                warpWidthScale = 3.0
            end
        end

        local scaleChanged = (trailLastSpeedScale_ ~= speedLenScale) or (trailLastWarpScale_ ~= warpWidthScale)
        trailLastSpeedScale_ = speedLenScale
        trailLastWarpScale_ = warpWidthScale

        local shipPosX, shipPosY, shipPosZ = shipPos.x, shipPos.y, shipPos.z

        for _, trail in ipairs(engineTrails_) do
            local spacing = trail.segSpacing
            local nodes = trail.nodes
            local trailCount = #nodes
            local baseX = trail.baseX
            local baseY = trail.baseY
            local baseZ = trail.baseZ
            local maxDrift = spacing * speedLenScale * 1.5
            local maxDrift2 = maxDrift * maxDrift
            local spacingScaled = spacing * speedLenScale
            for i, tn in ipairs(nodes) do
                local localPos = Vector3(baseX, baseY, baseZ - (i - 1) * spacingScaled)
                local targetPos = shipRot * localPos
                local tx = targetPos.x + shipPosX
                local ty = targetPos.y + shipPosY
                local tz = targetPos.z + shipPosZ
                local followSpeed = 60.0 / (0.3 + i * 0.28)
                local lerpFactor = math_min(1.0, followSpeed * dt)
                local curPos = tn.position
                local cx, cy, cz = curPos.x, curPos.y, curPos.z
                local newX = cx + (tx - cx) * lerpFactor
                local newY = cy + (ty - cy) * lerpFactor
                local newZ = cz + (tz - cz) * lerpFactor
                local dx = newX - tx
                local dy = newY - ty
                local dz = newZ - tz
                local drift2 = dx*dx + dy*dy + dz*dz
                if drift2 > maxDrift2 then
                    local s = maxDrift / math_sqrt(drift2)
                    newX = tx + dx * s
                    newY = ty + dy * s
                    newZ = tz + dz * s
                end
                tn.position = Vector3(newX, newY, newZ)
                if (frameCount + i) % 2 == 0 then
                    local rotLerp = math_min(1.0, (50.0 / (0.3 + i * 0.4)) * dt * 2.0)
                    tn.rotation = tn.rotation:Slerp(shipRot, rotLerp)
                end
                if scaleChanged then
                    local s = 1.0 - (i - 1) / trailCount
                    local baseThickness = 0.028 * s + 0.005
                    local baseZLen = 0.22 + 0.12 * s
                    local scaleXY = baseThickness * warpWidthScale
                    local scaleZ = baseZLen * speedLenScale
                    tn.scale = Vector3(scaleXY, scaleXY, scaleZ)
                end
            end
        end
    end

    -- 拖尾微粒更新（隔帧）
    trailParticleFrame_ = trailParticleFrame_ + 1
    if engineTrailParticles_ and trailParticleFrame_ % 2 == 0 then
        local shipPos = shipNode.position
        local shipRot = shipNode.rotation
        local t = time.elapsedTime

        local ptLenScale = gs.speed / 40.0
        local warpPtWidth = 1.0
        if gs.warpActive then
            local elapsed = gs.warpDuration - gs.warpTimer
            local remaining = gs.warpTimer
            if elapsed < 3.0 then
                warpPtWidth = 1.0 + (elapsed / 3.0) * 1.5
            elseif remaining < 3.0 then
                warpPtWidth = 1.0 + (remaining / 3.0) * 1.5
            else
                warpPtWidth = 2.5
            end
        end

        local spX, spY, spZ = shipPos.x, shipPos.y, shipPos.z
        local lf = math_min(1.0, 20.0 * dt)
        local ptScaleChanged = (trailPtLastWarp_ ~= warpPtWidth)
        trailPtLastWarp_ = warpPtWidth

        for _, pt in ipairs(engineTrailParticles_) do
            local ox = math_sin(t * pt.freq + pt.phase) * pt.amp * warpPtWidth
            local oy = math_cos(t * pt.freq * 0.7 + pt.phase + 1.0) * pt.amp * 0.6 * warpPtWidth
            local zCycle = 2.5 * ptLenScale
            local zDrift = ((t * pt.driftZ + pt.phase * 0.5) % zCycle)
            local localZ = pt.baseZ * ptLenScale + zDrift
            local localPos = Vector3(pt.baseX + ox, pt.baseY + oy, localZ)
            local targetPos = shipRot * localPos
            local ttx = targetPos.x + spX
            local tty = targetPos.y + spY
            local ttz = targetPos.z + spZ
            local curPos = pt.node.position
            local cx, cy, cz = curPos.x, curPos.y, curPos.z
            pt.node.position = Vector3(
                cx + (ttx - cx) * lf,
                cy + (tty - cy) * lf,
                cz + (ttz - cz) * lf
            )
            if ptScaleChanged then
                local baseSize = 0.005 + 0.008 * ((pt.phase / 6.28) % 1.0)
                local pSize = baseSize * warpPtWidth
                pt.node.scale = Vector3(pSize, pSize, pSize)
            end
        end
    end

    -- 尾焰火花粒子更新
    if exhaustSparkBBS_ then
        local shipPos = shipNode.position
        local shipRot = shipNode.rotation
        local sparkCount = exhaustSparkBBS_.numBillboards
        for i = 0, sparkCount - 1 do
            local d = exhaustSparkData_[i]
            d.life = d.life + dt
            if d.life >= d.maxLife then
                d.life = 0
                d.maxLife = 0.3 + math_random() * 0.5
                d.vx = (math_random() - 0.5) * 0.3
                d.vy = (math_random() - 0.5) * 0.2
                d.vz = -2.0 - math_random() * 3.0
                local localPos = Vector3(d.side + (math_random() - 0.5) * 0.06, -0.05, -1.5)
                local bb = exhaustSparkBBS_:GetBillboard(i)
                bb.position = shipPos + shipRot * localPos
                bb.size = Vector2(0.006, 0.006)
                bb.color = Color(0.6, 0.85, 1.0, 0.9)
            else
                local bb = exhaustSparkBBS_:GetBillboard(i)
                local ratio = d.life / d.maxLife
                local localOff = Vector3(d.vx * dt, d.vy * dt, d.vz * dt * (1.0 + gs.speed * 0.02))
                local worldOff = shipRot * localOff
                local pos = bb.position
                bb.position = Vector3(pos.x + worldOff.x, pos.y + worldOff.y, pos.z + worldOff.z)
                local s = 0.006 * (1.0 - ratio * 0.8)
                bb.size = Vector2(s, s)
                local alpha = 0.9 * (1.0 - ratio)
                bb.color = Color(0.2 + 0.4 * (1.0 - ratio), 0.5 + 0.4 * (1.0 - ratio), 1.0, alpha)
            end
        end
        exhaustSparkBBS_:Commit()
    end
end

--- 菜单状态下的引擎拖尾动画（缓慢浮动时的尾焰效果）
---@param dt number
---@param shipNode Node
---@param menuSpeed number 菜单呼吸速度
function M.updateMenu(dt, shipNode, menuSpeed)
    local shipPos = shipNode.position
    local shipRot = shipNode.rotation
    local speedLenScale = menuSpeed / 40.0

    -- 引擎拖尾段
    if engineTrails_ then
        for _, trail in ipairs(engineTrails_) do
            local spacing = trail.segSpacing
            local nodes = trail.nodes
            local trailCount = #nodes
            for i, tn in ipairs(nodes) do
                local localPos = Vector3(trail.baseX, trail.baseY, trail.baseZ - (i - 1) * spacing * speedLenScale)
                local targetPos = shipPos + shipRot * localPos
                local followSpeed = 60.0 / (0.3 + i * 0.28)
                local lf = math_min(1.0, followSpeed * dt)
                local curPos = tn.position
                local newX = curPos.x + (targetPos.x - curPos.x) * lf
                local newY = curPos.y + (targetPos.y - curPos.y) * lf
                local newZ = curPos.z + (targetPos.z - curPos.z) * lf
                local maxDrift = spacing * speedLenScale * 1.5
                local dx = newX - targetPos.x
                local dy = newY - targetPos.y
                local dz = newZ - targetPos.z
                local drift2 = dx*dx + dy*dy + dz*dz
                if drift2 > maxDrift * maxDrift then
                    local s = maxDrift / math_sqrt(drift2)
                    newX = targetPos.x + dx * s
                    newY = targetPos.y + dy * s
                    newZ = targetPos.z + dz * s
                end
                tn.position = Vector3(newX, newY, newZ)
                local rotLerp = math_min(1.0, (50.0 / (0.3 + i * 0.4)) * dt)
                tn.rotation = tn.rotation:Slerp(shipRot, rotLerp)

                local s2 = 1.0 - (i - 1) / trailCount
                local baseThickness = 0.028 * s2 + 0.005
                local baseZLen = 0.22 + 0.12 * s2
                local scaleXY = baseThickness
                local scaleZ = baseZLen * speedLenScale
                tn.scale = Vector3(scaleXY, scaleXY, scaleZ)
            end
        end
    end

    -- 微粒
    if engineTrailParticles_ then
        local t = time.elapsedTime
        local ptLenScale = menuSpeed / 40.0
        for _, pt in ipairs(engineTrailParticles_) do
            local ox = math_sin(t * pt.freq + pt.phase) * pt.amp
            local oy = math_cos(t * pt.freq * 0.7 + pt.phase + 1.0) * pt.amp * 0.6
            local zCycle = 2.5 * ptLenScale
            local zDrift = ((t * pt.driftZ + pt.phase * 0.5) % zCycle)
            local localZ = pt.baseZ * ptLenScale + zDrift
            local localPos = Vector3(pt.baseX + ox, pt.baseY + oy, localZ)
            local targetPos = shipPos + shipRot * localPos
            local curPos = pt.node.position
            local lf = math_min(1.0, 20.0 * dt)
            pt.node.position = Vector3(
                curPos.x + (targetPos.x - curPos.x) * lf,
                curPos.y + (targetPos.y - curPos.y) * lf,
                curPos.z + (targetPos.z - curPos.z) * lf
            )
        end
    end

    -- 火花粒子
    if exhaustSparkBBS_ then
        for i = 0, exhaustSparkBBS_.numBillboards - 1 do
            local d = exhaustSparkData_[i]
            d.life = d.life + dt
            if d.life >= d.maxLife then
                d.life = 0
                d.maxLife = 0.3 + math_random() * 0.5
                d.vx = (math_random() - 0.5) * 0.3
                d.vy = (math_random() - 0.5) * 0.2
                d.vz = -2.0 - math_random() * 3.0
                local localPos = Vector3(d.side + (math_random() - 0.5) * 0.06, -0.05, -1.5)
                local bb = exhaustSparkBBS_:GetBillboard(i)
                bb.position = shipPos + shipRot * localPos
                bb.size = Vector2(0.006, 0.006)
                bb.color = Color(0.6, 0.85, 1.0, 0.9)
            else
                local bb = exhaustSparkBBS_:GetBillboard(i)
                local ratio = d.life / d.maxLife
                local localOff = Vector3(d.vx * dt, d.vy * dt, d.vz * dt)
                local worldOff = shipRot * localOff
                local pos = bb.position
                bb.position = Vector3(pos.x + worldOff.x, pos.y + worldOff.y, pos.z + worldOff.z)
                local s = 0.006 * (1.0 - ratio * 0.8)
                bb.size = Vector2(s, s)
                local alpha = 0.9 * (1.0 - ratio)
                bb.color = Color(0.2 + 0.4 * (1.0 - ratio), 0.5 + 0.4 * (1.0 - ratio), 1.0, alpha)
            end
        end
        exhaustSparkBBS_:Commit()
    end
end

--- 重置拖尾位置（避免残留，游戏重新开始时调用）
function M.resetPositions(shipNode)
    if engineTrails_ then
        for _, trail in ipairs(engineTrails_) do
            local resetPos = Vector3(trail.baseX, trail.baseY, trail.baseZ)
            for _, tn in ipairs(trail.nodes) do
                tn.position = resetPos
            end
        end
    end
    if engineTrailParticles_ then
        for _, pt in ipairs(engineTrailParticles_) do
            pt.node.position = Vector3(pt.baseX, pt.baseY, pt.baseZ)
        end
    end
end

--- 获取翼尖拖尾相关引用（供 warp 模块使用）
function M.getWarpWingTrail()
    return {
        node = warpWingTrailNode_,
        bbs = warpWingTrailBBS_,
        data = warpWingTrailData_,
    }
end

return M
