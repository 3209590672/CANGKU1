-- ============================================================================
-- crystals.lua — 能量水晶系统（生成、更新、拾取）
-- ============================================================================
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove

local Crystals = {}

-- 依赖注入
local scene_
local crystalMats_
local crystalRadius_ = 0.8

-- 内部状态
local crystals_ = {}
local crystalSpawnTimer_ = 0
local crystalSpawnInterval_ = 1.5
local crystalMatFrame_ = 0

-- 动态参数回调
local getSpeed_ = nil
local getMoveRange_ = nil
local getFrameCount_ = nil
local getElapsedTime_ = nil

--- 初始化
-- @param ctx { scene, crystalMats, getSpeed, getMoveRange, getFrameCount, getElapsedTime }
function Crystals.init(ctx)
    scene_ = ctx.scene
    crystalMats_ = ctx.crystalMats
    getSpeed_ = ctx.getSpeed
    getMoveRange_ = ctx.getMoveRange
    getFrameCount_ = ctx.getFrameCount
    getElapsedTime_ = ctx.getElapsedTime
end

--- 重置状态（新游戏开始时调用）
function Crystals.reset()
    crystalSpawnTimer_ = 0
end

--- 清除所有水晶（返回菜单时调用）
function Crystals.clearCrystals()
    for _, crystal in ipairs(crystals_) do
        if crystal.node then
            crystal.node:Remove()
        end
    end
    crystals_ = {}
end

--- 获取水晶列表（碰撞检测用）
function Crystals.getCrystals()
    return crystals_
end

--- 移除指定索引的水晶
function Crystals.removeCrystalAt(idx)
    if crystals_[idx] then
        crystals_[idx].node:Remove()
        table_remove(crystals_, idx)
    end
end

--- 更新水晶（生成+呼吸灯+移动）
function Crystals.update(dt)
    local speed = getSpeed_()

    crystalSpawnTimer_ = crystalSpawnTimer_ + dt
    if crystalSpawnTimer_ >= crystalSpawnInterval_ then
        crystalSpawnTimer_ = 0
        if #crystals_ < 3 then
            Crystals.spawn()
        end
    end

    -- 水晶呼吸灯效果（共享材质，每3帧更新一次）
    crystalMatFrame_ = crystalMatFrame_ + 1
    if crystalMatFrame_ % 3 == 0 then
        local t = getElapsedTime_()
        local glow = 0.6 + 0.4 * math_sin(t * 2.5)
        local crystalBaseColors = { {0.2, 1.0, 0.4}, {0.3, 0.6, 1.0}, {1.0, 0.8, 0.2} }
        for idx, c in ipairs(crystalBaseColors) do
            if crystalMats_[idx] then
                crystalMats_[idx]:SetShaderParameter("MatEmissiveColor",
                    Variant(Color(c[1] * 2.5 * glow, c[2] * 2.5 * glow, c[3] * 2.5 * glow)))
            end
        end
    end

    -- 水晶旋转隔帧更新
    local frameCount = getFrameCount_()
    local crystalRotFrame = (frameCount % 2 == 0)
    local rotQ = nil
    if crystalRotFrame then
        rotQ = Quaternion(15 * dt * 2, 60 * dt * 2, 8 * dt * 2)
    end

    local i = 1
    while i <= #crystals_ do
        local crystal = crystals_[i]
        local pos = crystal.node.position
        pos.z = pos.z - speed * dt
        crystal.node.position = pos

        if crystalRotFrame then
            crystal.node:Rotate(rotQ)
        end

        if pos.z < -10 then
            crystal.node:Remove()
            table_remove(crystals_, i)
        else
            i = i + 1
        end
    end
end

--- 生成一颗水晶
function Crystals.spawn()
    local moveRangeX, moveRangeY = getMoveRange_()

    local node = scene_:CreateChild("Crystal")
    local x = math_random() * moveRangeX * 1.5 - moveRangeX * 0.75
    local y = math_random() * moveRangeY * 1.5 - moveRangeY * 0.75
    local z = 80 + math_random() * 30
    node.position = Vector3(x, y, z)
    node.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

    local colors = {
        { 0.2, 1.0, 0.4 },
        { 0.3, 0.6, 1.0 },
        { 1.0, 0.8, 0.2 },
    }
    local colorIdx = math_random(1, #colors)

    -- 四棱水晶造型（CustomGeometry）
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local sides = 4
    local radius = 0.38
    local halfBody = 0.5
    local tipHeight = 0.6

    local topRing = {}
    local botRing = {}
    for i = 1, sides do
        local angle = 2 * math_pi * (i - 1) / sides + 0.785
        local cx = math_cos(angle) * radius
        local cz = math_sin(angle) * radius
        topRing[i] = Vector3(cx, halfBody, cz)
        botRing[i] = Vector3(cx, -halfBody, cz)
    end
    local topTip = Vector3(0, halfBody + tipHeight, 0)
    local botTip = Vector3(0, -(halfBody + tipHeight), 0)

    local function AddFace(p1, p2, p3)
        local e1 = p2 - p1
        local e2 = p3 - p1
        local n = e1:CrossProduct(e2):Normalized()
        geom:DefineVertex(p1); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(0, 0))
        geom:DefineVertex(p2); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(1, 0))
        geom:DefineVertex(p3); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(0, 1))
    end

    for i = 1, sides do
        local next = (i % sides) + 1
        AddFace(topTip, topRing[i], topRing[next])
        AddFace(botTip, botRing[next], botRing[i])
        AddFace(topRing[i], botRing[i], botRing[next])
        AddFace(topRing[i], botRing[next], topRing[next])
    end

    geom:Commit()
    geom:SetMaterial(crystalMats_[colorIdx])

    table_insert(crystals_, {
        node = node,
        radius = crystalRadius_,
    })
end

return Crystals
