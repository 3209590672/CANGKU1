--[[
Layer 3 - 游戏逻辑层：护盾系统模块
职责：护盾 CustomGeometry 创建 + 激活/冷却/动画更新
依赖：scene节点、材质、gs状态表
--]]

local math_sqrt = math.sqrt
local math_cos = math.cos
local math_sin = math.sin
local math_atan = math.atan
local math_abs = math.abs
local math_ceil = math.ceil
local math_pi = math.pi
local math_max = math.max
local math_min = math.min

local M = {}

-- 模块内部引用（由 create 注入）
local shieldNode_ = nil
local shieldPulseMat_ = nil
local shieldFillMat_ = nil

--- 创建蜂巢护盾几何体（六边形网格球面 + 填充面 + 点光源）
---@param deps table { shipNode, cache, pulseMat }
---@return table { node, pulseMat, fillMat }
function M.createGeometry(deps)
    local shipNode = deps.shipNode
    local cache = deps.cache
    local pulseMat = deps.pulseMat

    local node = shipNode:CreateChild("Shield")
    node.position = Vector3(0, 0, 1.8)  -- 飞船正前方

    -- === 前方半球六边形蜂窝护盾线框 ===
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local shieldR = 2.0
    local hexEdge = 0.38
    local fadeStart = 1.7
    local fadeEnd = 2.4
    local sqrt3 = math_sqrt(3)

    -- 轴坐标(q, r) → 平面坐标(x, y)，flat-top 六边形
    local function AxialToXY(q, r)
        local x = hexEdge * (1.5 * q)
        local y = hexEdge * (sqrt3 * 0.5 * q + sqrt3 * r)
        return x, y
    end

    -- 平面坐标 → 半球面3D点（Z方向凸出）
    local function FlatToHemi(x, y)
        local dist = math_sqrt(x * x + y * y)
        local theta = math_atan(y, x)
        local phi = (dist / shieldR) * (math_pi * 0.5)
        local z = math_cos(phi)
        local r = math_sin(phi)
        return Vector3(
            r * math_cos(theta) * shieldR,
            r * math_sin(theta) * shieldR,
            z * shieldR
        ), dist
    end

    -- 计算透明度（基于平面距离）
    local function GetAlpha(dist)
        if dist <= fadeStart then return 1.0 end
        if dist >= fadeEnd then return 0.0 end
        return 1.0 - (dist - fadeStart) / (fadeEnd - fadeStart)
    end

    -- 绘制带透明度的线段
    local function AddLineAlpha(p1, d1, p2, d2)
        local a1 = GetAlpha(d1)
        local a2 = GetAlpha(d2)
        if a1 <= 0.01 and a2 <= 0.01 then return end
        geom:DefineVertex(p1)
        geom:DefineNormal(p1:Normalized())
        geom:DefineColor(Color(0.4, 0.75, 1.0, a1))
        geom:DefineTexCoord(Vector2(0, 0))
        geom:DefineVertex(p2)
        geom:DefineNormal(p2:Normalized())
        geom:DefineColor(Color(0.4, 0.75, 1.0, a2))
        geom:DefineTexCoord(Vector2(1, 1))
    end

    -- 六边形顶点偏移（flat-top：顶点从0°开始，间隔60°）
    local hexDirs = {}
    for i = 0, 5 do
        local angle = math_pi / 3.0 * i
        hexDirs[i] = { math_cos(angle) * hexEdge, math_sin(angle) * hexEdge }
    end

    local gridRadius = math_ceil(fadeEnd / (hexEdge * 1.5)) + 1

    -- 记录已绘制的边，避免重复
    local drawnEdges = {}
    local function EdgeKey(x1, y1, x2, y2)
        local k1 = string.format("%.2f,%.2f", x1, y1)
        local k2 = string.format("%.2f,%.2f", x2, y2)
        if k1 < k2 then return k1 .. "|" .. k2
        else return k2 .. "|" .. k1 end
    end

    for q = -gridRadius, gridRadius do
        for r = -gridRadius, gridRadius do
            local s = -q - r
            if math_abs(q) <= gridRadius and math_abs(r) <= gridRadius and math_abs(s) <= gridRadius then
                local cx, cy = AxialToXY(q, r)
                local centerDist = math_sqrt(cx * cx + cy * cy)
                if centerDist < fadeEnd + hexEdge then
                    for i = 0, 5 do
                        local j = (i + 1) % 6
                        local vx1 = cx + hexDirs[i][1]
                        local vy1 = cy + hexDirs[i][2]
                        local vx2 = cx + hexDirs[j][1]
                        local vy2 = cy + hexDirs[j][2]

                        local key = EdgeKey(vx1, vy1, vx2, vy2)
                        if not drawnEdges[key] then
                            drawnEdges[key] = true
                            local p1, d1 = FlatToHemi(vx1, vy1)
                            local p2, d2 = FlatToHemi(vx2, vy2)
                            AddLineAlpha(p1, d1, p2, d2)
                        end
                    end
                end
            end
        end
    end

    geom:Commit()
    geom:SetMaterial(pulseMat)

    -- === 护盾六边形填充面 ===
    local fillNode = node:CreateChild("ShieldFill")
    local fillGeom = fillNode:CreateComponent("CustomGeometry")
    fillGeom:BeginGeometry(0, TRIANGLE_LIST)

    for q = -gridRadius, gridRadius do
        for r = -gridRadius, gridRadius do
            local s = -q - r
            if math_abs(q) <= gridRadius and math_abs(r) <= gridRadius and math_abs(s) <= gridRadius then
                local cx, cy = AxialToXY(q, r)
                local centerDist = math_sqrt(cx * cx + cy * cy)
                if centerDist < fadeStart then
                    local centerP, _ = FlatToHemi(cx, cy)
                    local centerAlpha = 0.5
                    for i = 0, 5 do
                        local j = (i + 1) % 6
                        local vx1 = cx + hexDirs[i][1]
                        local vy1 = cy + hexDirs[i][2]
                        local vx2 = cx + hexDirs[j][1]
                        local vy2 = cy + hexDirs[j][2]
                        local p1, _ = FlatToHemi(vx1, vy1)
                        local p2, _ = FlatToHemi(vx2, vy2)

                        fillGeom:DefineVertex(centerP)
                        fillGeom:DefineNormal(centerP:Normalized())
                        fillGeom:DefineColor(Color(0.3, 0.6, 1.0, centerAlpha))
                        fillGeom:DefineTexCoord(Vector2(0.5, 0.5))

                        fillGeom:DefineVertex(p1)
                        fillGeom:DefineNormal(p1:Normalized())
                        fillGeom:DefineColor(Color(0.3, 0.6, 1.0, centerAlpha))
                        fillGeom:DefineTexCoord(Vector2(0, 0))

                        fillGeom:DefineVertex(p2)
                        fillGeom:DefineNormal(p2:Normalized())
                        fillGeom:DefineColor(Color(0.3, 0.6, 1.0, centerAlpha))
                        fillGeom:DefineTexCoord(Vector2(1, 0))
                    end
                end
            end
        end
    end

    fillGeom:Commit()
    local fillMat = Material:new()
    fillMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    fillMat:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.7, 0.9, 0.5)))
    fillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.12, 0.3)))
    fillMat:SetShaderParameter("Metallic", Variant(0.0))
    fillMat:SetShaderParameter("Roughness", Variant(0.95))
    fillGeom:SetMaterial(fillMat)

    -- === 护盾前方发光点光源 ===
    local shieldGlow = node:CreateChild("ShieldGlow")
    shieldGlow.position = Vector3(0, 0, 0.5)
    local gl = shieldGlow:CreateComponent("Light")
    gl.lightType = LIGHT_POINT
    gl.perVertex = true
    gl.color = Color(0.4, 0.7, 1.0)
    gl.brightness = 6.0
    gl.range = 5.0

    node:SetEnabled(false)

    -- 缓存到模块
    shieldNode_ = node
    shieldPulseMat_ = pulseMat
    shieldFillMat_ = fillMat

    return { node = node, pulseMat = pulseMat, fillMat = fillMat }
end

-- eventBus 引用（由外部注入）
local eventBus_ = nil

--- 设置 eventBus（由 main 调用）
function M.setEventBus(eb)
    eventBus_ = eb
end

--- 更新护盾逻辑（冷却/动画/激活）
---@param dt number 帧时间
---@param gs table 游戏状态
---@param inputMgr table|nil InputManager实例（手机端需要）
function M.update(dt, gs, inputMgr)
    -- 冷却计时
    if gs.shieldCoolTimer > 0 then
        gs.shieldCoolTimer = math_max(0, gs.shieldCoolTimer - dt)
    end

    -- 护盾展开/消散动画
    if gs.shieldAnimState ~= "none" and shieldNode_ then
        gs.shieldAnimTimer = gs.shieldAnimTimer + dt
        local progress = math_min(gs.shieldAnimTimer / gs.shieldAnimTime, 1.0)

        if gs.shieldAnimState == "expanding" then
            local t = 1.0 - progress
            local s = 1.0 - t * t * t
            shieldNode_:SetScale(Vector3(s, s, s))
        else -- collapsing
            local eased = progress * progress
            local s = 1.0 + 0.5 * eased
            local alpha = 1.0 - eased
            shieldNode_:SetScale(Vector3(s, s, s))
            shieldPulseMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.7, 1.0, 0.08 * alpha)))
            shieldPulseMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8 * alpha, 2.0 * alpha, 5.0 * alpha)))
            if shieldFillMat_ then
                shieldFillMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.7, 0.9, 0.5 * alpha)))
                shieldFillMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05 * alpha, 0.12 * alpha, 0.3 * alpha)))
            end
        end

        if progress >= 1.0 then
            if gs.shieldAnimState == "collapsing" then
                shieldNode_:SetEnabled(false)
                shieldNode_:SetScale(Vector3(1, 1, 1))
                -- 恢复材质参数
                shieldPulseMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.7, 1.0, 0.08)))
                shieldPulseMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8, 2.0, 5.0)))
                if shieldFillMat_ then
                    shieldFillMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.7, 0.9, 0.5)))
                    shieldFillMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.12, 0.3)))
                end
                gs.shieldCoolTimer = gs.shieldCooldown
            end
            gs.shieldAnimState = "none"
        end
    end

    -- 护盾激活中
    if gs.shieldActive then
        gs.shieldTimer = gs.shieldTimer - dt
        if shieldNode_ then
            shieldNode_:Rotate(Quaternion(0, 0, 25 * dt))
            local pulse = 0.6 + 0.4 * math_sin(time.elapsedTime * 4.0)
            local flicker = 0.85 + 0.15 * math_sin(time.elapsedTime * 11.0)
            local glow = pulse * flicker
            shieldPulseMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.7, 1.0, 0.05 + 0.06 * glow)))
            shieldPulseMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8 * glow, 2.0 * glow, 5.0 * glow)))
        end
        if gs.shieldTimer <= 0 then
            gs.shieldActive = false
            gs.shieldAnimState = "collapsing"
            gs.shieldAnimTimer = 0
            if eventBus_ then eventBus_:emit("shield_deactivated") end
        end
    else
        -- 激活护盾（鼠标右键 / 手机护盾按钮）
        local shieldInput = inputMgr and inputMgr:isShielding() or input:GetMouseButtonPress(MOUSEB_RIGHT)
        if gs.shieldCoolTimer <= 0 and gs.shieldAnimState == "none" and shieldInput then
            gs.shieldActive = true
            gs.shieldTimer = gs.shieldDuration
            if shieldNode_ then
                shieldNode_:SetEnabled(true)
                shieldNode_:SetScale(Vector3(0.01, 0.01, 0.01))
            end
            gs.shieldAnimState = "expanding"
            gs.shieldAnimTimer = 0
            if eventBus_ then eventBus_:emit("shield_activated") end
        end
    end
end

--- 重置护盾状态
---@param gs table 游戏状态
function M.reset(gs)
    gs.shieldActive = false
    gs.shieldTimer = 0
    gs.shieldCoolTimer = 0
    gs.shieldAnimState = "none"
    gs.shieldAnimTimer = 0
    if shieldNode_ then
        shieldNode_:SetEnabled(false)
        shieldNode_:SetScale(Vector3(1, 1, 1))
    end
end

--- 获取护盾节点（碰撞检测用）
function M.getNode()
    return shieldNode_
end

--- 是否激活中
function M.isActive(gs)
    return gs.shieldActive
end

return M
