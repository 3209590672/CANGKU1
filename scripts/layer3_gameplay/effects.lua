-- ============================================================================
-- effects.lua — 爆炸特效系统（生成、更新、清理）
-- ============================================================================
local math_sin = math.sin
local math_cos = math.cos
local math_random = math.random
local math_min = math.min
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local Effects = {}

-- 依赖注入
local scene_
local mdlCylinder_
local mdlSphere_
local mdlBox_
local explosionRayMat_
local explosionDebrisMat_
local explosionGlowBaseMat_

-- 内部状态
local explosions_ = {}

-- 帧计数（用于隔帧优化）
local getFrameCount_ = nil

--- 初始化
-- @param ctx { scene, mdlCylinder, mdlSphere, mdlBox, explosionRayMat, explosionDebrisMat, explosionGlowBaseMat, getFrameCount }
function Effects.init(ctx)
    scene_ = ctx.scene
    mdlCylinder_ = ctx.mdlCylinder
    mdlSphere_ = ctx.mdlSphere
    mdlBox_ = ctx.mdlBox
    explosionRayMat_ = ctx.explosionRayMat
    explosionDebrisMat_ = ctx.explosionDebrisMat
    explosionGlowBaseMat_ = ctx.explosionGlowBaseMat
    getFrameCount_ = ctx.getFrameCount
end

--- 生成爆炸特效
function Effects.spawnExplosion(pos, size, color)
    local cr = color and color[1] or 0.9
    local cg = color and color[2] or 0.5
    local cb = color and color[3] or 0.2
    local sz = size or 1.0

    local explosion = { nodes = {}, age = 0, lifetime = 0.7 }

    local rayMat = explosionRayMat_
    local debrisMat = explosionDebrisMat_

    -- 1. 放射尖刺（4条）
    local rayCount = 4
    local cylModel = mdlCylinder_
    for i = 1, rayCount do
        local n = scene_:CreateChild("ER")
        n.position = pos
        local a1 = (i - 1) / rayCount * 6.2832 + (math_random() - 0.5) * 0.6
        local a2 = (math_random() - 0.5) * 2.4
        local dx = math_cos(a1) * math_cos(a2)
        local dy = math_sin(a2)
        local dz = math_sin(a1) * math_cos(a2)
        local rayLen = (0.6 + math_random() * 0.5) * sz
        local rayThick = (0.04 + math_random() * 0.03) * sz
        n.scale = Vector3(rayThick, rayLen, rayThick)
        local dir = Vector3(dx, dy, dz):Normalized()
        n.rotation = Quaternion(Vector3.UP, dir)
        n.position = pos + dir * (rayLen * 0.5)

        local sm = n:CreateComponent("StaticModel")
        sm:SetModel(cylModel)
        sm:SetMaterial(rayMat)
        local spd = (6.0 + math_random() * 5.0) * sz
        table_insert(explosion.nodes, {
            node = n, type = "ray",
            dx = dx, dy = dy, dz = dz,
            spd = spd,
            baseLen = rayLen,
            thick = rayThick,
        })
    end

    -- 2. 中心光球
    local lightNode = scene_:CreateChild("EL")
    lightNode.position = pos
    lightNode.scale = Vector3(0.8 * sz, 0.8 * sz, 0.8 * sz)
    local lgModel = lightNode:CreateComponent("StaticModel")
    lgModel:SetModel(mdlSphere_)
    local lgMat = explosionGlowBaseMat_:Clone("")
    lgMat:SetShaderParameter("MatDiffColor", Variant(Color(0, 0, 0, 0.3)))
    lgMat:SetShaderParameter("MatEmissiveColor", Variant(Color(cr * 8.0, cg * 8.0, cb * 8.0)))
    lgModel:SetMaterial(lgMat)
    lgModel.castShadows = false
    table_insert(explosion.nodes, { node = lightNode, type = "glow" })

    -- 3. 碎石（3块）
    local boxModel = mdlBox_
    for i = 1, 3 do
        local n = scene_:CreateChild("ED")
        n.position = pos
        local a1 = math_random() * 6.2832
        local a2 = (math_random() - 0.5) * 2.8
        local spd = (4.0 + math_random() * 5.0) * sz
        local vx = math_cos(a1) * math_cos(a2) * spd
        local vy = math_sin(a2) * spd + math_random() * 2.5
        local vz = math_sin(a1) * math_cos(a2) * spd
        local ds = (0.06 + math_random() * 0.1) * sz
        n.scale = Vector3(ds * (0.5 + math_random()), ds * (0.4 + math_random() * 0.6), ds * (0.5 + math_random()))
        n.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)
        local sm = n:CreateComponent("StaticModel")
        sm:SetModel(boxModel)
        sm:SetMaterial(debrisMat)
        table_insert(explosion.nodes, {
            node = n, type = "rock",
            vx = vx, vy = vy, vz = vz,
            rotSpd = Vector3(math_random() * 400 - 200, math_random() * 400 - 200, math_random() * 400 - 200),
        })
    end

    table_insert(explosions_, explosion)
end

--- 更新所有爆炸特效
function Effects.updateExplosions(dt)
    local frameCount = getFrameCount_()
    local i = 1
    while i <= #explosions_ do
        local exp = explosions_[i]
        exp.age = exp.age + dt
        local p = exp.age / exp.lifetime

        if p >= 1.0 then
            for _, item in ipairs(exp.nodes) do
                item.node:Remove()
            end
            table_remove(explosions_, i)
        else
            for _, item in ipairs(exp.nodes) do
                local itype = item.type
                if itype == "ray" then
                    local grow = math_min(p * 10.0, 1.0)
                    local shrink = math_max(0, (p - 0.25) * 1.3333)
                    local lenMul = grow * 3.5 * (1.0 - shrink * shrink)
                    local curLen = item.baseLen * lenMul
                    local curThick = item.thick * (1.0 - p * 0.7)
                    if curLen < 0.001 then curLen = 0.001 end
                    if curThick < 0.002 then curThick = 0.002 end
                    item.node.scale = Vector3(curThick, curLen, curThick)
                    local moveD = item.spd * dt * (1.0 - p * 0.5)
                    local pos = item.node.position
                    pos.x = pos.x + item.dx * moveD
                    pos.y = pos.y + item.dy * moveD
                    pos.z = pos.z + item.dz * moveD
                    item.node.position = pos

                elseif itype == "glow" then
                    local glowScale = 0.8 * (1.0 - p * p)
                    if glowScale < 0.01 then glowScale = 0.01 end
                    item.node.scale = Vector3(glowScale, glowScale, glowScale)

                elseif itype == "rock" then
                    local slow = 1.0 - p * 0.5
                    local pos = item.node.position
                    pos.x = pos.x + item.vx * dt * slow
                    pos.y = pos.y + item.vy * dt * slow - 5.0 * dt * p
                    pos.z = pos.z + item.vz * dt * slow
                    item.node.position = pos
                    if frameCount % 2 == 0 then
                        local rs = item.rotSpd
                        item.node:Rotate(Quaternion(
                            rs.x * dt * 2.0, rs.y * dt * 2.0, rs.z * dt * 2.0))
                    end
                    if p > 0.4 then
                        local sc = item.node.scale
                        local shrinkF = 1.0 - dt * 3.0
                        item.node.scale = Vector3(sc.x * shrinkF, sc.y * shrinkF, sc.z * shrinkF)
                    end
                end
            end
            i = i + 1
        end
    end
end

--- 清除所有爆炸（返回菜单时）
function Effects.clearExplosions()
    for _, exp in ipairs(explosions_) do
        for _, item in ipairs(exp.nodes) do
            if item.node then
                item.node:Remove()
            end
        end
    end
    explosions_ = {}
end

return Effects
