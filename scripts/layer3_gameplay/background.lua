--[[
Layer 3 - 背景视觉系统
管理深空星河、星尘粒子、流星弧线、装饰陨石
--]]

local AsteroidBuilder = require("layer3_gameplay/asteroid_builder")

local Background = {}

-- ============================================================================
-- 依赖注入（init 时传入）
-- ============================================================================
local scene_, cache_
local math_sin, math_cos, math_random, math_max, math_min, math_pi
local table_insert

-- ============================================================================
-- 内部状态
-- ============================================================================
-- 星尘
local starDusts_ = {}
local starDustCount_ = 50
local starDustMat_ = nil

-- 星河
---@type Node
local starfieldNode_ = nil
---@type BillboardSet
local starfieldBBS_ = nil
local starBreathIndices_ = {}
local starBreathBaseSize_ = {}
local starBreathPhase_ = {}
local starBreathFrame_ = 0

-- 流星
local meteors_ = {}
local meteorMat_ = nil
local meteorNextGroupTime_ = 0
local meteorRainbow_ = {
    { 1.0, 0.2, 0.2 },  -- 红
    { 1.0, 0.6, 0.1 },  -- 橙
    { 1.0, 1.0, 0.2 },  -- 黄
    { 0.2, 1.0, 0.3 },  -- 绿
    { 0.2, 0.7, 1.0 },  -- 蓝
    { 0.4, 0.2, 1.0 },  -- 靛
    { 0.8, 0.3, 1.0 },  -- 紫
}

-- 装饰陨石
local decoAsteroids_ = {}
local decoAsteroidMat_ = nil
local asteroidMeshPool_ = {}
local asteroidMeshPoolSize_ = 6
local moveRangeX_, moveRangeY_
local mdlSphere_

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化背景系统
---@param ctx table { scene, cache, starDustMat, meteorMat, decoAsteroidMat, asteroidMeshPool, asteroidMeshPoolSize, moveRangeX, moveRangeY, mdlSphere }
function Background.init(ctx)
    scene_ = ctx.scene
    cache_ = ctx.cache
    starDustMat_ = ctx.starDustMat
    meteorMat_ = ctx.meteorMat
    decoAsteroidMat_ = ctx.decoAsteroidMat
    asteroidMeshPool_ = ctx.asteroidMeshPool
    asteroidMeshPoolSize_ = ctx.asteroidMeshPoolSize
    moveRangeX_ = ctx.moveRangeX
    moveRangeY_ = ctx.moveRangeY
    mdlSphere_ = ctx.mdlSphere

    -- 缓存 math 函数
    math_sin = math.sin
    math_cos = math.cos
    math_random = math.random
    math_max = math.max
    math_min = math.min
    math_pi = math.pi
    table_insert = table.insert
end

-- ============================================================================
-- 星尘
-- ============================================================================

function Background.createStarDusts()
    -- 清除旧节点（防止重复调用时产生孤儿节点）
    for _, dust in ipairs(starDusts_) do
        if dust.node then dust.node:Remove() end
    end
    starDusts_ = {}
    for i = 1, starDustCount_ do
        local dustNode = scene_:CreateChild("StarDust")
        local x = math_random() * 60 - 30
        local y = math_random() * 40 - 20
        local z = math_random() * 150 + 10
        dustNode.position = Vector3(x, y, z)
        dustNode.scale = Vector3(0.05, 0.05, 0.05)

        local model = dustNode:CreateComponent("StaticModel")
        model:SetModel(cache_:GetResource("Model", "Models/Sphere.mdl"))
        model:SetMaterial(starDustMat_)

        table_insert(starDusts_, { node = dustNode, speed = 10 + math_random() * 20 })
    end
end

function Background.updateStarDusts(dt, speed, isPlaying, elapsedTime)
    local currentSpeed = speed
    if not isPlaying then
        local breath = (math_sin(elapsedTime * 0.4) + 1) * 0.5
        currentSpeed = 20 + breath * 40
    end

    local dusts = starDusts_
    for i = 1, #dusts do
        local dust = dusts[i]
        local node = dust.node
        local pos = node.position
        local newZ = pos.z - (currentSpeed + dust.speed) * dt

        if newZ < -20 then
            pos.z = 150 + math_random() * 50
            pos.x = math_random() * 60 - 30
            pos.y = math_random() * 40 - 20
        else
            pos.z = newZ
        end

        node.position = pos
    end
end

-- ============================================================================
-- 深空星河
-- ============================================================================

function Background.createStarfield()
    starBreathIndices_ = {}
    starBreathBaseSize_ = {}
    starBreathPhase_ = {}

    starfieldNode_ = scene_:CreateChild("Starfield")
    starfieldNode_.position = Vector3(0, 0, 0)

    starfieldBBS_ = starfieldNode_:CreateComponent("BillboardSet")
    local bbs = starfieldBBS_
    bbs.numBillboards = 500
    bbs.sorted = false
    bbs.relative = false
    bbs.scaled = false
    bbs.faceCameraMode = FC_ROTATE_XYZ

    local mat = Material:new()
    mat:SetTechnique(0, cache_:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 1.0)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(3.0, 3.0, 3.0)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    bbs:SetMaterial(mat)

    local palette = {
        Color(1.0, 1.0, 1.0, 0.9),
        Color(0.8, 0.85, 1.0, 0.9),
        Color(0.6, 0.7, 1.0, 0.85),
        Color(1.0, 0.95, 0.7, 0.85),
        Color(1.0, 0.8, 0.5, 0.8),
        Color(1.0, 0.6, 0.6, 0.75),
        Color(0.7, 0.6, 1.0, 0.8),
        Color(0.5, 1.0, 0.9, 0.8),
    }

    for i = 0, 499 do
        local bb = bbs:GetBillboard(i)
        local x = (math_random() - 0.5) * 220
        local y = (math_random() - 0.5) * 150
        local z = 80 + math_random() * 470
        bb.position = Vector3(x, y, z)

        local baseSize = 0.04 + math_random() * 0.12
        bb.size = Vector2(baseSize, baseSize)

        local colorIdx
        if math_random() < 0.7 then
            colorIdx = math_random(1, 3)
        else
            colorIdx = math_random(1, #palette)
        end
        bb.color = palette[colorIdx]
        bb.rotation = math_random() * 360
        bb.enabled = true

        if math_random() < 0.25 then
            local idx = #starBreathIndices_ + 1
            starBreathIndices_[idx] = i
            starBreathBaseSize_[idx] = baseSize
            starBreathPhase_[idx] = math_random() * 6.283
        end
    end

    bbs:Commit()
end

function Background.updateStarfieldBreath(elapsedTime)
    starBreathFrame_ = starBreathFrame_ + 1
    if starBreathFrame_ % 3 ~= 0 then return end

    local t = elapsedTime * 1.8
    for i = 1, #starBreathIndices_ do
        local bb = starfieldBBS_:GetBillboard(starBreathIndices_[i])
        local s = starBreathBaseSize_[i] * (0.7 + 0.5 * math_sin(t + starBreathPhase_[i]))
        bb.size = Vector2(s, s)
    end
    starfieldBBS_:Commit()
end

-- ============================================================================
-- 流星系统
-- ============================================================================

local function InitMeteorTrail(m)
    local side = (math_random() > 0.5) and 1 or -1
    local startX = -side * (20 + math_random() * 15)
    local startY = 8 + math_random() * 12
    local startZ = 40 + math_random() * 60

    m.px = startX
    m.py = startY
    m.pz = startZ

    m.dirAngle = (side > 0) and (math_random() * 0.3 - 0.15) or (math_pi + math_random() * 0.3 - 0.15)
    m.dirPitch = (math_random() - 0.5) * 0.2
    m.curvature = (math_random() - 0.5) * 0.35
    m.pitchCurve = (math_random() - 0.5) * 0.1
    m.speed = 5 + math_random() * 8
    m.life = 0
    m.maxLife = 3.0 + math_random() * 3.0
    m.trailLen = 18 + math_random(0, 8)
    m.colorOffset = math_random(0, 6)
    m.history = {}
    m.historyHead = nil
    m.historyCount = nil
    m.active = true
    m.node:SetEnabled(true)
end

local function SpawnMeteorGroup()
    local groupSize = 3 + math_random(0, 2)
    local assigned = 0
    for _, m in ipairs(meteors_) do
        if assigned >= groupSize then break end
        if not m.active then
            InitMeteorTrail(m)
            m.py = m.py + (assigned - 1) * (1.5 + math_random() * 1.0)
            m.pz = m.pz + (math_random() - 0.5) * 8
            m.life = -assigned * (0.3 + math_random() * 0.4)
            m.node:SetEnabled(false)
            assigned = assigned + 1
        end
    end
end

function Background.createMeteors()
    -- 清除旧节点
    for _, m in ipairs(meteors_) do
        if m.node then m.node:Remove() end
    end
    meteors_ = {}
    local count = 12
    for i = 1, count do
        local node = scene_:CreateChild("MeteorTrail")
        local geom = node:CreateComponent("CustomGeometry")
        -- 必须先 Commit 一个空 geometry 再 SetMaterial，否则 geometry index 0 不存在
        geom:BeginGeometry(0, TRIANGLE_STRIP)
        geom:Commit()
        geom:SetMaterial(meteorMat_)
        geom.castShadows = false
        node:SetEnabled(false)

        local m = {
            node = node, geom = geom, active = false,
            px = 0, py = 0, pz = 0,
            dirAngle = 0, dirPitch = 0,
            curvature = 0, pitchCurve = 0,
            speed = 6, life = 0, maxLife = 4.0,
            trailLen = 20, colorOffset = 0,
            history = {},
        }
        table_insert(meteors_, m)
    end

    meteorNextGroupTime_ = time.elapsedTime + 0.5 + math_random() * 1.5
end

function Background.updateMeteors(dt, elapsedTime, frameCount)
    if elapsedTime >= meteorNextGroupTime_ then
        SpawnMeteorGroup()
        meteorNextGroupTime_ = elapsedTime + 90.0 + math_random() * 30.0
    end

    local rebuildGeom = (frameCount % 2 == 0)

    for _, m in ipairs(meteors_) do
        if m.active then
            m.life = m.life + dt

            if m.life < 0 then
                m.node:SetEnabled(false)
            else
                if m.life >= m.maxLife then
                    m.active = false
                    m.node:SetEnabled(false)
                else
                    m.dirAngle = m.dirAngle + m.curvature * dt
                    m.dirPitch = m.dirPitch + m.pitchCurve * dt

                    local cosP = math_cos(m.dirPitch)
                    local vx = math_cos(m.dirAngle) * cosP * m.speed
                    local vy = math_sin(m.dirPitch) * m.speed
                    local vz = math_sin(m.dirAngle) * cosP * m.speed * 0.3

                    m.px = m.px + vx * dt
                    m.py = m.py + vy * dt
                    m.pz = m.pz + vz * dt

                    local head = (m.historyHead or 0) + 1
                    if head > m.trailLen then head = 1 end
                    m.historyHead = head
                    local historyCount = m.historyCount or 0
                    if historyCount < m.trailLen then
                        historyCount = historyCount + 1
                        m.historyCount = historyCount
                    end
                    if m.history[head] then
                        m.history[head].x = m.px
                        m.history[head].y = m.py
                        m.history[head].z = m.pz
                    else
                        m.history[head] = { x = m.px, y = m.py, z = m.pz }
                    end

                    if rebuildGeom then
                        local geom = m.geom
                        local numPts = historyCount
                        if numPts < 2 then
                            -- 点数不足时隐藏节点，避免渲染空 geometry 导致 index out of bounds
                            m.node:SetEnabled(false)
                        end
                        if numPts >= 2 then
                            m.node:SetEnabled(true)
                            geom:BeginGeometry(0, TRIANGLE_STRIP)
                            local thickness = 0.06
                            local fadeIn = m.life < 0.5 and (m.life / 0.5) or 1.0
                            local fadeOut = (m.maxLife - m.life < 1.0) and ((m.maxLife - m.life) / 1.0) or 1.0
                            local masterAlpha = fadeIn * fadeOut
                            local invNumPts = 1.0 / numPts

                            local idx = head
                            for pi = 1, numPts do
                                local p = m.history[idx]
                                if not p then break end
                                local tAlpha = (1.0 - (pi - 1) * invNumPts) * masterAlpha
                                local cIdx = ((pi + m.colorOffset - 1) % 7) + 1
                                local rc = meteorRainbow_[cIdx]
                                local emissive = 2.0 * tAlpha
                                local halfW = thickness * tAlpha * 0.5
                                local er = rc[1] * emissive
                                local eg = rc[2] * emissive
                                local eb = rc[3] * emissive

                                geom:DefineVertex(Vector3(p.x, p.y + halfW, p.z))
                                geom:DefineNormal(Vector3.UP)
                                geom:DefineColor(Color(er, eg, eb, tAlpha))

                                geom:DefineVertex(Vector3(p.x, p.y - halfW, p.z))
                                geom:DefineNormal(Vector3.UP)
                                geom:DefineColor(Color(er, eg, eb, tAlpha))

                                idx = idx - 1
                                if idx < 1 then idx = m.trailLen end
                            end
                            geom:Commit()
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 装饰陨石
-- ============================================================================

function Background.createDecoAsteroids()
    -- 清除旧节点
    for _, deco in ipairs(decoAsteroids_) do
        if deco.node then deco.node:Remove() end
    end
    decoAsteroids_ = AsteroidBuilder.createDecoAsteroids({
        scene = scene_,
        moveRangeX = moveRangeX_,
        moveRangeY = moveRangeY_,
        meshPool = asteroidMeshPool_,
        meshPoolSize = asteroidMeshPoolSize_,
        decoMat = decoAsteroidMat_,
        mdlSphere = mdlSphere_,
    })
end

function Background.updateDecoAsteroids(dt, speed, isPlaying, elapsedTime, frameCount)
    local currentSpeed = speed
    if not isPlaying then
        local breath = (math_sin(elapsedTime * 0.4) + 1) * 0.5
        currentSpeed = 20 + breath * 40
    end

    local fadeThreshold = 30.0
    local fadeRange = 15.0
    local targetScale = 1.0
    if isPlaying and speed > fadeThreshold then
        targetScale = math_max(0.0, 1.0 - (speed - fadeThreshold) / fadeRange)
    end

    local decos = decoAsteroids_
    local doRotate = (frameCount % 2 == 0)
    for i = 1, #decos do
        local deco = decos[i]
        local node = deco.node
        local curScale = deco.scale or 1.0
        if curScale ~= targetScale then
            local fadeSpeed = 2.0 * dt
            if targetScale < curScale then
                curScale = math_max(targetScale, curScale - fadeSpeed)
            else
                curScale = math_min(targetScale, curScale + fadeSpeed)
            end
            deco.scale = curScale
            local orig = deco.origScale
            node.scale = Vector3(orig.x * curScale, orig.y * curScale, orig.z * curScale)
        end

        if curScale < 0.01 then
            node:SetEnabled(false)
            goto continue_deco
        else
            node:SetEnabled(true)
        end

        local pos = node.position
        pos.z = pos.z - (currentSpeed * 0.6 + deco.driftSpeed) * dt

        if pos.z < -20 then
            pos.z = 140 + math_random() * 40
            local side = (math_random() > 0.5) and 1 or -1
            pos.x = side * (moveRangeX_ + 5.0 + math_random() * 8.0)
            local ySide = (math_random() > 0.5) and 1 or -1
            pos.y = ySide * (moveRangeY_ + 2.5 + math_random() * 6.0)
        end

        node.position = pos
        if doRotate then
            local rs = deco.rotSpeed
            node:Rotate(Quaternion(rs.x * dt * 2, rs.y * dt * 2, rs.z * dt * 2))
        end

        ::continue_deco::
    end
end

--- 获取装饰陨石数组引用（供 ClearObjects 等外部使用）
function Background.getDecoAsteroids()
    return decoAsteroids_
end

--- 获取星尘数组引用
function Background.getStarDusts()
    return starDusts_
end

return Background
