-- ============================================================================
-- Layer3: 小行星建造器（SpawnAsteroid + CreateDecoAsteroids）
-- 依赖: GeomUtils, MatDefs, 全局资源（scene_, mdlSphere_, mdlBox_, 材质等）
-- ============================================================================

local GeomUtils = require("layer2_patterns/geometry_utils")
local MatDefs = require("layer4_content/material_defs")

local AsteroidBuilder = {}

local math_random = math.random
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local math_sqrt = math.sqrt
local table_insert = table.insert

--- 生成不规则多面体顶点（扰动正二十面体）
---@param subdivLevel number 细分级别（0或1）
---@param jitter number 扰动幅度（0~1）
---@return table verts, table faces
function AsteroidBuilder.generateRockVertices(subdivLevel, jitter)
    local phi = (1.0 + math_sqrt(5.0)) / 2.0
    local baseVerts = {
        Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
        Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
        Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1),
    }
    for i, v in ipairs(baseVerts) do
        local len = math_sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        baseVerts[i] = Vector3(v.x / len, v.y / len, v.z / len)
    end
    local faces = {
        {1,12,6}, {1,6,2}, {1,2,8}, {1,8,11}, {1,11,12},
        {2,6,10}, {6,12,5}, {12,11,3}, {11,8,7}, {8,2,9},
        {4,10,5}, {4,5,3}, {4,3,7}, {4,7,9}, {4,9,10},
        {5,10,6}, {3,5,12}, {7,3,11}, {9,7,8}, {10,9,2},
    }

    if subdivLevel >= 1 then
        local newFaces = {}
        local midCache = {}
        local function getMid(ia, ib)
            local key = math.min(ia, ib) .. "_" .. math.max(ia, ib)
            if midCache[key] then return midCache[key] end
            local a = baseVerts[ia]
            local b = baseVerts[ib]
            local mx = (a.x + b.x) * 0.5
            local my = (a.y + b.y) * 0.5
            local mz = (a.z + b.z) * 0.5
            local len = math_sqrt(mx*mx + my*my + mz*mz)
            table_insert(baseVerts, Vector3(mx/len, my/len, mz/len))
            local idx = #baseVerts
            midCache[key] = idx
            return idx
        end
        for _, f in ipairs(faces) do
            local a, b, c = f[1], f[2], f[3]
            local ab = getMid(a, b)
            local bc = getMid(b, c)
            local ca = getMid(c, a)
            table_insert(newFaces, {a, ab, ca})
            table_insert(newFaces, {b, bc, ab})
            table_insert(newFaces, {c, ca, bc})
            table_insert(newFaces, {ab, bc, ca})
        end
        faces = newFaces
    end

    for i, v in ipairs(baseVerts) do
        local distort = 1.0 + (math_random() - 0.5) * jitter
        baseVerts[i] = Vector3(v.x * distort, v.y * distort, v.z * distort)
    end

    return baseVerts, faces
end

--- 预生成岩石网格数据池（启动时一次性调用）
---@param poolSize number 池大小（默认6）
---@return table meshPool
function AsteroidBuilder.initMeshPool(poolSize)
    poolSize = poolSize or 6
    local pool = {}
    for i = 1, poolSize do
        local verts, faces = AsteroidBuilder.generateRockVertices(1, 0.6)
        pool[i] = { verts = verts, faces = faces }
    end
    return pool
end

--- 从 mesh pool 数据构建不规则岩石 CustomGeometry（游戏特定建模逻辑）
local function buildRockMesh(geom, meshData, scale, cr, cg, cb, colorJitter)
    local verts, faces = meshData.verts, meshData.faces
    geom:BeginGeometry(0, TRIANGLE_LIST)
    for _, f in ipairs(faces) do
        local v1 = verts[f[1]]
        local v2 = verts[f[2]]
        local v3 = verts[f[3]]
        local e1x, e1y, e1z = v2.x - v1.x, v2.y - v1.y, v2.z - v1.z
        local e2x, e2y, e2z = v3.x - v1.x, v3.y - v1.y, v3.z - v1.z
        local nx = e1y * e2z - e1z * e2y
        local ny = e1z * e2x - e1x * e2z
        local nz = e1x * e2y - e1y * e2x
        local nlen = math_sqrt(nx*nx + ny*ny + nz*nz)
        if nlen > 0.0001 then nx = nx/nlen; ny = ny/nlen; nz = nz/nlen end
        local normal = Vector3(nx, ny, nz)
        local faceShade = (1.0 - colorJitter * 0.5) + math_random() * colorJitter

        geom:DefineVertex(v1 * scale)
        geom:DefineNormal(normal)
        geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))

        geom:DefineVertex(v2 * scale)
        geom:DefineNormal(normal)
        geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))

        geom:DefineVertex(v3 * scale)
        geom:DefineNormal(normal)
        geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))
    end
    geom:Commit()
end

--- 生成一颗游戏内小行星（带碰撞检测用）
--- @param ctx table { scene, moveRangeX, moveRangeY, meshPool, meshPoolSize, rockMats, debrisMats, crackMat, oreMat, mdlSphere, mdlBox }
--- @return table asteroid entry for asteroids_ list
function AsteroidBuilder.spawnAsteroid(ctx)
    local node = ctx.scene:CreateChild("Asteroid")
    local x = math_random() * ctx.moveRangeX * 2 - ctx.moveRangeX
    local y = math_random() * ctx.moveRangeY * 2 - ctx.moveRangeY
    local z = 80 + math_random() * 40
    node.position = Vector3(x, y, z)

    local baseSize = 0.7 + math_random() * 1.0

    -- CustomGeometry 不规则岩石
    local geom = node:CreateComponent("CustomGeometry")
    local meshData = ctx.meshPool[math_random(1, ctx.meshPoolSize)]

    local colorIdx = math_random(1, 6)
    local colors = MatDefs.asteroidVertexColors
    local c = colors[colorIdx]
    local cr = c[1] + (math_random() - 0.5) * 0.08
    local cg = c[2] + (math_random() - 0.5) * 0.06
    local cb = c[3] + (math_random() - 0.5) * 0.05

    buildRockMesh(geom, meshData, baseSize * 0.5, cr, cg, cb, 0.3)
    geom:SetMaterial(ctx.rockMats[colorIdx])
    geom.castShadows = false

    -- 1个表面碎石
    local debris = node:CreateChild("Debris")
    local angle1 = math_random() * math_pi * 2
    local angle2 = (math_random() - 0.5) * math_pi
    local dist = baseSize * 0.5 * (0.75 + math_random() * 0.2)
    debris.position = Vector3(
        math_cos(angle1) * math_cos(angle2) * dist,
        math_sin(angle2) * dist,
        math_sin(angle1) * math_cos(angle2) * dist
    )
    local dSize = baseSize * (0.12 + math_random() * 0.18)
    debris.scale = Vector3(
        dSize * (0.6 + math_random() * 0.8),
        dSize * (0.5 + math_random() * 0.6),
        dSize * (0.6 + math_random() * 0.8)
    )
    debris.rotation = Quaternion(math_random()*360, math_random()*360, math_random()*360)
    local dModel = debris:CreateComponent("StaticModel")
    dModel:SetModel(ctx.mdlSphere)
    dModel:SetMaterial(ctx.debrisMats[colorIdx])
    dModel.castShadows = false

    -- 20% 熔岩裂缝
    if math_random() < 0.20 then
        local crack = node:CreateChild("Crack")
        crack.position = Vector3(0, 0, 0)
        crack.scale = Vector3(0.4, 0.4, 0.4) * baseSize
        local crackModel = crack:CreateComponent("StaticModel")
        crackModel:SetModel(ctx.mdlSphere)
        crackModel:SetMaterial(ctx.crackMat)
    end

    -- 15% 冰晶矿脉
    if math_random() < 0.15 then
        local ore = node:CreateChild("Ore")
        local oa1 = math_random() * math_pi * 2
        local oa2 = (math_random() - 0.5) * math_pi * 0.8
        local oDist = baseSize * 0.5 * (0.8 + math_random() * 0.15)
        ore.position = Vector3(
            math_cos(oa1) * math_cos(oa2) * oDist,
            math_sin(oa2) * oDist,
            math_sin(oa1) * math_cos(oa2) * oDist
        )
        local oSize = baseSize * (0.08 + math_random() * 0.1)
        ore.scale = Vector3(oSize, oSize * (1.5 + math_random()), oSize)
        ore.rotation = Quaternion(math_random()*360, math_random()*360, math_random()*360)
        local oModel = ore:CreateComponent("StaticModel")
        oModel:SetModel(ctx.mdlBox)
        oModel:SetMaterial(ctx.oreMat)
    end

    node.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

    return {
        node = node,
        radius = baseSize * 0.55,
        rotSpeed = Vector3(
            math_random() * 30 - 15,
            math_random() * 30 - 15,
            math_random() * 30 - 15
        )
    }
end

--- 创建装饰陨石群（航道外静态氛围）
--- @param ctx table { scene, moveRangeX, moveRangeY, meshPool, meshPoolSize, decoMat, mdlSphere }
--- @return table decoAsteroids list
function AsteroidBuilder.createDecoAsteroids(ctx)
    local result = {}
    local count = 12
    local decoColors = MatDefs.decoAsteroidVertexColors

    for i = 1, count do
        local node = ctx.scene:CreateChild("DecoAsteroid")
        local side = (i % 2 == 0) and 1 or -1
        local x = side * (ctx.moveRangeX + 5.0 + math_random() * 8.0)
        local ySide = (math_random() > 0.5) and 1 or -1
        local y = ySide * (ctx.moveRangeY + 2.5 + math_random() * 6.0)
        local z = math_random() * 160 - 10
        node.position = Vector3(x, y, z)

        local baseSize = 0.8 + math_random() * 2.0
        node.scale = Vector3(
            baseSize * (0.7 + math_random() * 0.6),
            baseSize * (0.6 + math_random() * 0.5),
            baseSize * (0.7 + math_random() * 0.6)
        )
        node.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

        local geom = node:CreateComponent("CustomGeometry")
        local meshData = ctx.meshPool[math_random(1, ctx.meshPoolSize)]
        local c = decoColors[math_random(1, #decoColors)]
        local cr = c[1] + (math_random() - 0.5) * 0.04
        local cg = c[2] + (math_random() - 0.5) * 0.03
        local cb = c[3] + (math_random() - 0.5) * 0.03

        buildRockMesh(geom, meshData, 1.0, cr, cg, cb, 0.4)
        geom:SetMaterial(ctx.decoMat)
        geom.castShadows = false

        -- 附加1个小碎石
        local debris = node:CreateChild("DecoDebris")
        local angle1 = math_random() * math_pi * 2
        local angle2 = (math_random() - 0.5) * math_pi
        local dist = 0.55 + math_random() * 0.2
        debris.position = Vector3(
            math_cos(angle1) * math_cos(angle2) * dist,
            math_sin(angle2) * dist,
            math_sin(angle1) * math_cos(angle2) * dist
        )
        local dSize = 0.15 + math_random() * 0.2
        debris.scale = Vector3(
            dSize * (0.6 + math_random() * 0.8),
            dSize * (0.5 + math_random() * 0.6),
            dSize * (0.6 + math_random() * 0.8)
        )
        debris.rotation = Quaternion(math_random()*360, math_random()*360, math_random()*360)
        local dModel = debris:CreateComponent("StaticModel")
        dModel:SetModel(ctx.mdlSphere)
        dModel:SetMaterial(ctx.decoMat)
        dModel.castShadows = false

        table_insert(result, {
            node = node,
            origScale = node.scale,
            scale = 1.0,
            rotSpeed = Vector3(
                (math_random() - 0.5) * 8,
                (math_random() - 0.5) * 8,
                (math_random() - 0.5) * 8
            ),
            driftSpeed = 0.5 + math_random() * 1.5,
        })
    end

    -- 细小碎石散布
    local smallCount = 24
    for i = 1, smallCount do
        local sNode = ctx.scene:CreateChild("DecoSmallRock")
        local side = (i % 2 == 0) and 1 or -1
        local x = side * (ctx.moveRangeX + 3.5 + math_random() * 14.0)
        local ySide = (math_random() > 0.5) and 1 or -1
        local y = ySide * (ctx.moveRangeY + 1.5 + math_random() * 8.0)
        local z = math_random() * 180 - 20
        sNode.position = Vector3(x, y, z)

        local sSize = 0.1 + math_random() * 0.35
        sNode.scale = Vector3(
            sSize * (0.6 + math_random() * 0.8),
            sSize * (0.5 + math_random() * 0.7),
            sSize * (0.6 + math_random() * 0.8)
        )
        sNode.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

        local geom = sNode:CreateComponent("CustomGeometry")
        local meshData = ctx.meshPool[math_random(1, ctx.meshPoolSize)]
        local shade = 0.05 + math_random() * 0.08

        buildRockMesh(geom, meshData, 1.0, shade, shade * 0.9, shade * 0.85, 0.5)
        geom:SetMaterial(ctx.decoMat)
        geom.castShadows = false

        table_insert(result, {
            node = sNode,
            origScale = sNode.scale,
            scale = 1.0,
            rotSpeed = Vector3(
                (math_random() - 0.5) * 12,
                (math_random() - 0.5) * 12,
                (math_random() - 0.5) * 12
            ),
            driftSpeed = 0.8 + math_random() * 2.0,
        })
    end

    return result
end

return AsteroidBuilder
