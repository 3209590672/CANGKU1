-- ============================================================================
-- warp_visuals.lua — 折跃视觉效果（穿越光条 + 星尘拉伸 + 飞船发光 + 翼尖拖尾）
-- ============================================================================
local math_random = math.random
local math_floor = math.floor
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local M = {}

-- 内部状态
local warpStreaks_ = {}
local warpStreakCount_ = 32
local warpGlowNode_ = nil
local warpVisualDirty_ = true
local warpLastActive_ = nil

--- 创建折跃穿越光条 + 飞船发光节点
---@param deps { scene: Scene, shipNode: Node, cache: ResourceCache }
function M.createStreaks(deps)
    local scene = deps.scene
    local shipNode = deps.shipNode
    local cache = deps.cache

    local streakMat = Material:new()
    streakMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    streakMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.7, 1.0, 0.6)))
    streakMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.6, 0.9, 2.5)))
    streakMat:SetShaderParameter("Metallic", Variant(0.0))
    streakMat:SetShaderParameter("Roughness", Variant(0.1))

    warpStreaks_ = {}
    for i = 1, warpStreakCount_ do
        local node = scene:CreateChild("WarpStreak")
        local x = math_random() * 16 - 8
        local y = math_random() * 10 - 5
        local z = math_random() * 80 + 20
        node.position = Vector3(x, y, z)
        local thickness = 0.03 + math_random() * 0.06
        local length = 6.0 + math_random() * 10.0
        node.scale = Vector3(thickness, thickness, length)

        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        model:SetMaterial(streakMat)

        node:SetEnabled(false)
        table_insert(warpStreaks_, { node = node, speed = 120 + math_random() * 80, length = length })
    end

    -- 飞船折跃发光
    warpGlowNode_ = shipNode:CreateChild("WarpGlow")
    warpGlowNode_.position = Vector3(0, 0, -0.5)
    local light = warpGlowNode_:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.perVertex = true
    light.color = Color(0.4, 0.7, 1.0)
    light.brightness = 60
    light.range = 8.0
    warpGlowNode_:SetEnabled(false)

    warpVisualDirty_ = true
    warpLastActive_ = nil
end

--- 更新折跃视觉效果（光条+星尘拉伸+发光+翼尖拖尾）
---@param dt number
---@param gs table GameState
---@param shipNode Node
---@param Background table Background模块引用
---@param wingTrail table|nil 翼尖拖尾数据 { node, bbs, data }
function M.update(dt, gs, shipNode, Background, wingTrail)
    local active = gs.warpActive

    -- 穿越光条
    local visibleCount = 0
    if active then
        local elapsed = gs.warpDuration - gs.warpTimer
        local remaining = gs.warpTimer
        local fadeIn = 3.0
        local fadeOut = 3.0
        local ratio = 1.0
        if elapsed < fadeIn then
            ratio = elapsed / fadeIn
        end
        if remaining < fadeOut and remaining < elapsed then
            ratio = remaining / fadeOut
        end
        visibleCount = math_max(1, math_floor(warpStreakCount_ * ratio))
    end

    for i, streak in ipairs(warpStreaks_) do
        if active and i <= visibleCount then
            streak.node:SetEnabled(true)
            local pos = streak.node.position
            pos.z = pos.z - streak.speed * dt
            if pos.z < -15 then
                pos.z = 60 + math_random() * 40
                pos.x = math_random() * 16 - 8
                pos.y = math_random() * 10 - 5
            end
            streak.node.position = pos
        else
            streak.node:SetEnabled(false)
        end
    end

    -- 星尘拉伸（仅状态切换时更新）
    if warpVisualDirty_ or (warpLastActive_ ~= active) then
        warpLastActive_ = active
        warpVisualDirty_ = false
        local sz = active and Vector3(0.05, 0.05, 1.5) or Vector3(0.05, 0.05, 0.05)
        for _, dust in ipairs(Background.getStarDusts()) do
            dust.node.scale = sz
        end
    end

    -- 飞船发光
    if warpGlowNode_ then
        warpGlowNode_:SetEnabled(active)
    end

    -- 翼尖拖尾
    if wingTrail and wingTrail.node then
        local warpWingTrailNode = wingTrail.node
        local warpWingTrailBBS = wingTrail.bbs
        local warpWingTrailData = wingTrail.data
        local wingTrailSegs = 16

        warpWingTrailNode:SetEnabled(active)
        if active and shipNode then
            local shipPos = shipNode.position
            local shipRot = shipNode.rotation
            for _, sideData in ipairs(warpWingTrailData) do
                local localTip = Vector3(sideData.wingX, sideData.wingY, sideData.wingZ)
                local worldTip = shipPos + shipRot * localTip
                table_insert(sideData.positions, 1, worldTip)
                while #sideData.positions > wingTrailSegs do
                    table_remove(sideData.positions)
                end
                for i = 1, wingTrailSegs do
                    local bb = warpWingTrailBBS:GetBillboard(sideData.baseIdx + i - 1)
                    if i <= #sideData.positions then
                        bb.enabled = true
                        bb.position = sideData.positions[i]
                        local ratio = (i - 1) / (wingTrailSegs - 1)
                        local s = 0.04 * (1.0 - ratio * 0.7)
                        bb.size = Vector2(s, s)
                        local alpha = 0.85 * (1.0 - ratio)
                        bb.color = Color(0.4 + 0.4 * (1.0 - ratio), 0.7 + 0.3 * (1.0 - ratio), 1.0, alpha)
                    else
                        bb.enabled = false
                    end
                end
            end
            warpWingTrailBBS:Commit()
        else
            for _, sideData in ipairs(warpWingTrailData) do
                sideData.positions = {}
                for i = 0, 15 do
                    local bb = warpWingTrailBBS:GetBillboard(sideData.baseIdx + i)
                    bb.enabled = false
                end
            end
            warpWingTrailBBS:Commit()
        end
    end
end

--- 重置翼尖拖尾数据
---@param wingTrail table|nil
function M.resetWingTrail(wingTrail)
    if wingTrail and wingTrail.node then
        wingTrail.node:SetEnabled(false)
        for _, sideData in ipairs(wingTrail.data) do
            sideData.positions = {}
        end
    end
end

return M
