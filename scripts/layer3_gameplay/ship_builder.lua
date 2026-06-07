--[[
Layer 3 - 游戏逻辑：飞船建造器
职责：读取 Layer4 几何数据 + Layer2 工具，构建完整飞船节点树
返回飞船节点及相关引用（护盾、拖尾等）
--]]

local unpack = table.unpack

local GeomUtils = require("layer2_patterns/geometry_utils")
local MatFactory = require("layer2_patterns/material_factory")
local ShipGeo = require("layer4_content/ship_geometry")

local math_pi = math.pi
local math_cos = math.cos
local math_sin = math.sin
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_random = math.random
local math_max = math.max
local math_min = math.min
local math_deg = math.deg
local math_atan = math.atan
local table_insert = table.insert

local ShipBuilder = {}

-- ============================================================================
-- 材质工厂（委托 MatFactory，消除重复）
-- ============================================================================

local function MakeHullMat(r, g, b, metallic, roughness)
    return MatFactory.create({
        tech = "opaque",
        diff = { r, g, b, 1.0 },
        emissive = { metallic * 0.13, metallic * 0.13, metallic * 0.15 },
        metallic = metallic,
        roughness = roughness,
    })
end

local function MakeGlowMat(r, g, b, er, eg, eb)
    return MatFactory.create({
        tech = "opaque",
        diff = { r, g, b, 1.0 },
        emissive = { er, eg, eb },
        metallic = 0.0,
        roughness = 0.2,
    })
end

-- ============================================================================
-- 截面生成器
-- ============================================================================

--- 生成N边形椭圆截面（上凸下平）
local function MakeSection(z, w, hTop, hBot, flatness, nEdges)
    local pts = {}
    for i = 0, nEdges - 1 do
        local angle = (i / nEdges) * math_pi * 2
        local rawX = math_sin(angle)
        local rawY = math_cos(angle)
        local px = rawX * w
        local py
        if rawY >= 0 then
            py = rawY * hTop
        else
            py = rawY * hBot * (1.0 - flatness * 0.5 * (1 + rawY))
        end
        pts[i + 1] = Vector3(px, py, z)
    end
    return pts
end

--- 翼型截面生成
local function MakeWingSection(t, side, cfg)
    local span = cfg.rootSpan + t * (cfg.tipSpan - cfg.rootSpan)
    local dropY = cfg.tipDropY * t
    local chord = cfg.rootChord - t * (cfg.rootChord - cfg.tipChord)
    local thick = cfg.tipThick + (cfg.rootThick - cfg.tipThick) * (1.0 - t) * (1.0 - t)
    local sweep = cfg.sweepMax * t
    local zFront = cfg.zFrontBase + sweep
    local zBack = zFront - chord
    local pts = {}
    local nPts = cfg.profilePts
    for i = 0, nPts - 1 do
        local a = (i / nPts) * math_pi * 2
        local cx = math_cos(a) * 0.5
        local cy = math_sin(a)
        if cy > 0 then cy = cy * 1.0 else cy = cy * 0.5 end
        local pz = zFront + (zBack - zFront) * (cx + 0.5)
        local py = dropY + cy * thick
        pts[i + 1] = Vector3(side * span, py, pz)
    end
    return pts
end

--- 尾翼截面生成
local function MakeTailSection(t, side, cfg)
    local baseX = side * (cfg.baseXInner + t * (cfg.baseXOuter - cfg.baseXInner))
    local baseY = cfg.baseYBottom + t * (cfg.topY - cfg.baseYBottom)
    local chord = cfg.rootChord - t * (cfg.rootChord - cfg.tipChord)
    local thick = cfg.rootThick * (1.0 - t * cfg.tipThickRatio)
    local zFront = cfg.zFront + t * cfg.zSweep
    local zBack = zFront - chord
    local pts = {}
    local nPts = cfg.profilePts
    for i = 0, nPts - 1 do
        local a = (i / nPts) * math_pi * 2
        local cx = math_cos(a) * 0.5
        local cy = math_sin(a)
        local flatFactor = 1.0 - (1.0 - t) * 0.7
        if cy < 0 then cy = cy * flatFactor end
        local pz = zFront + (zBack - zFront) * (cx + 0.5)
        local px = baseX + cy * thick * side
        pts[i + 1] = Vector3(px, baseY, pz)
    end
    return pts
end

-- ============================================================================
-- 主构建函数
-- ============================================================================

--- 构建完整飞船
---@param scene Scene 场景实例
---@param resourceCache ResourceCache 资源缓存（依赖注入）
---@return table 包含 shipNode, shieldNode, engineTrails, 等引用的结构体
function ShipBuilder.build(scene, resourceCache)
    local shipNode = scene:CreateChild("Ship")
    shipNode.position = Vector3(0, 0, 0)

    local matDefs = ShipGeo.materials

    -- 创建材质实例
    local hullMain = MakeHullMat(unpack(matDefs.hullMain))
    local hullLight = MakeHullMat(unpack(matDefs.hullLight))
    local hullDark = MakeHullMat(unpack(matDefs.hullDark))
    local hullAccent = MakeHullMat(unpack(matDefs.hullAccent))
    local cockpitMat = MakeGlowMat(unpack(matDefs.cockpit))
    local engineGlow = MakeGlowMat(unpack(matDefs.engineGlow))
    local energyLine = MakeGlowMat(unpack(matDefs.energyLine))
    local warnMat = MakeGlowMat(unpack(matDefs.warn))
    local reactorMat = MakeGlowMat(unpack(matDefs.reactor))
    local shieldEmit = MakeGlowMat(unpack(matDefs.shieldEmit))

    -- ==== 主机身 ====
    local hullNode = shipNode:CreateChild("Hull")
    local hullGeom = hullNode:CreateComponent("CustomGeometry")
    hullGeom:BeginGeometry(0, TRIANGLE_LIST)

    local sections = {}
    for i, s in ipairs(ShipGeo.hullSections) do
        sections[i] = MakeSection(s[1], s[2], s[3], s[4], s[5], ShipGeo.hullEdges)
    end

    -- 连接相邻截面
    for s = 1, #sections - 1 do
        GeomUtils.connectRings(hullGeom, sections[s], sections[s + 1])
    end

    -- 封闭前后端面
    local frontCenter = Vector3(0, 0, sections[1][1].z)
    GeomUtils.capRing(hullGeom, sections[1], frontCenter, true)
    local backCenter = Vector3(0, 0, sections[#sections][1].z)
    GeomUtils.capRing(hullGeom, sections[#sections], backCenter, false)

    hullGeom:Commit()
    hullGeom:SetMaterial(hullMain)
    hullGeom.castShadows = true

    -- ==== 座舱顶盖 ====
    local canopyNode = shipNode:CreateChild("Canopy")
    local canopyGeom = canopyNode:CreateComponent("CustomGeometry")
    canopyGeom:BeginGeometry(0, TRIANGLE_LIST)

    local cBaseY = ShipGeo.canopyBaseY
    local canopyVerts = {}
    for i, p in ipairs(ShipGeo.canopyProfiles) do
        canopyVerts[i] = {
            Vector3(-p.w, cBaseY, p.z),
            Vector3(-p.w * 0.65, cBaseY + p.h * 0.7, p.z),
            Vector3(0, cBaseY + p.h, p.z),
            Vector3(p.w * 0.65, cBaseY + p.h * 0.7, p.z),
            Vector3(p.w, cBaseY, p.z),
        }
    end

    for s = 1, #canopyVerts - 1 do
        local cur = canopyVerts[s]
        local nxt = canopyVerts[s + 1]
        for f = 1, 4 do
            GeomUtils.addQuad(canopyGeom, cur[f], nxt[f], nxt[f + 1], cur[f + 1])
        end
    end

    -- 前端封面
    local frontV = canopyVerts[1]
    local firstProfile = ShipGeo.canopyProfiles[1]
    local fCenter = Vector3(0, cBaseY + firstProfile.h * 0.5, firstProfile.z + 0.03)
    for f = 1, 4 do
        local n = GeomUtils.faceNormal(fCenter, frontV[f], frontV[f + 1])
        GeomUtils.addTri(canopyGeom, fCenter, frontV[f], frontV[f + 1], n)
    end

    -- 后端封面
    local backV = canopyVerts[#canopyVerts]
    local lastProfile = ShipGeo.canopyProfiles[#ShipGeo.canopyProfiles]
    local bCenter = Vector3(0, cBaseY + lastProfile.h * 0.3, lastProfile.z - 0.02)
    for f = 1, 4 do
        local n = GeomUtils.faceNormal(bCenter, backV[f + 1], backV[f])
        GeomUtils.addTri(canopyGeom, bCenter, backV[f + 1], backV[f], n)
    end

    canopyGeom:Commit()
    canopyGeom:SetMaterial(cockpitMat)

    -- 座舱框架棱线
    for i, verts in ipairs(canopyVerts) do
        if i < #canopyVerts then
            local nxtVerts = canopyVerts[i + 1]
            local midZ = (verts[3].z + nxtVerts[3].z) * 0.5
            local midY = (verts[3].y + nxtVerts[3].y) * 0.5
            local lenZ = math_abs(verts[3].z - nxtVerts[3].z)
            local ribTop = shipNode:CreateChild("CRibT")
            ribTop.position = Vector3(0, midY + 0.003, midZ)
            ribTop.scale = Vector3(0.008, 0.008, lenZ)
            local rtM = ribTop:CreateComponent("StaticModel")
            rtM:SetModel(resourceCache:GetResource("Model", "Models/Box.mdl"))
            rtM:SetMaterial(hullDark)
        end
        if i >= 2 and i <= #canopyVerts - 1 then
            for f = 1, 4 do
                local p1 = verts[f]
                local p2 = verts[f + 1]
                local mx = (p1.x + p2.x) * 0.5
                local my = (p1.y + p2.y) * 0.5
                local mz = (p1.z + p2.z) * 0.5
                local dx = p2.x - p1.x
                local dy = p2.y - p1.y
                local segLen = math_sqrt(dx * dx + dy * dy)
                local rib = shipNode:CreateChild("CRibH")
                rib.position = Vector3(mx, my + 0.003, mz)
                local angle = math_deg(math_atan(dy, dx))
                rib.rotation = Quaternion(angle, Vector3.FORWARD)
                rib.scale = Vector3(segLen, 0.006, 0.006)
                local rM = rib:CreateComponent("StaticModel")
                rM:SetModel(resourceCache:GetResource("Model", "Models/Box.mdl"))
                rM:SetMaterial(hullDark)
            end
        end
    end

    -- ==== 主翼 ====
    local wCfg = ShipGeo.wing
    for side = -1, 1, 2 do
        local wingNode = shipNode:CreateChild("Wing")
        local wGeom = wingNode:CreateComponent("CustomGeometry")
        wGeom:BeginGeometry(0, TRIANGLE_LIST)

        local wingSections = {}
        for i = 0, wCfg.segments do
            wingSections[i] = MakeWingSection(i / wCfg.segments, side, wCfg)
        end

        for s = 0, wCfg.segments - 1 do
            GeomUtils.connectRings(wGeom, wingSections[s], wingSections[s + 1])
        end

        -- 封闭翼根
        local rootC = Vector3(side * wCfg.rootSpan, 0, -0.2)
        GeomUtils.capRing(wGeom, wingSections[0], rootC, false)

        -- 封闭翼尖
        local tipC = Vector3(side * wCfg.tipSpan, wCfg.tipDropY, -0.45)
        GeomUtils.capRing(wGeom, wingSections[wCfg.segments], tipC, true)

        wGeom:Commit()
        wGeom:SetMaterial(hullMain)
        wGeom.castShadows = true

        -- 翼面能量脊
        local spine = shipNode:CreateChild("WSpine")
        spine.position = Vector3(side * 0.8, 0.035, -0.2)
        spine.scale = Vector3(0.7, 0.012, 0.025)
        local spM = spine:CreateComponent("StaticModel")
        spM:SetModel(resourceCache:GetResource("Model", "Models/Box.mdl"))
        spM:SetMaterial(energyLine)

        -- 翼端导航灯
        local navNormal = Vector3(side, -0.1, 0):Normalized()
        local navMat = side < 0 and MakeGlowMat(unpack(matDefs.navRed)) or MakeGlowMat(unpack(matDefs.navGreen))
        GeomUtils.createHexLight(shipNode, "NavL", Vector3(side * wCfg.tipSpan, -0.02, -0.45), navNormal, 0.035, navMat)
    end

    -- ==== 垂直双尾翼 ====
    local tCfg = ShipGeo.tail
    for side = -1, 1, 2 do
        local tailNode = shipNode:CreateChild("VTail")
        local tGeom = tailNode:CreateComponent("CustomGeometry")
        tGeom:BeginGeometry(0, TRIANGLE_LIST)

        local tailSections = {}
        for i = 0, tCfg.segments do
            tailSections[i] = MakeTailSection(i / tCfg.segments, side, tCfg)
        end

        for s = 0, tCfg.segments - 1 do
            GeomUtils.connectRings(tGeom, tailSections[s], tailSections[s + 1])
        end

        -- 仅封闭顶端
        local topC = Vector3(side * tCfg.baseXOuter, tCfg.topY, -0.85)
        GeomUtils.capRing(tGeom, tailSections[tCfg.segments], topC, true)

        tGeom:Commit()
        tGeom:SetMaterial(hullAccent)
        tGeom.castShadows = true

        -- 尾翼顶灯
        local tailLampNormal = Vector3(side * 0.3, 0.95, 0):Normalized()
        GeomUtils.createHexLight(shipNode, "TLamp", Vector3(side * tCfg.baseXOuter, tCfg.topY + 0.01, -0.88), tailLampNormal, 0.025, warnMat)
    end

    -- ==== 引擎舱 ====
    local eCfg = ShipGeo.engine
    for side = -1, 1, 2 do
        local ex, ey = side * eCfg.centerX, eCfg.centerY

        local nacNode = shipNode:CreateChild("Nacelle")
        local nacGeom = nacNode:CreateComponent("CustomGeometry")
        nacGeom:BeginGeometry(0, TRIANGLE_LIST)

        local nacSections = {}
        for i, s in ipairs(eCfg.nacelleSections) do
            nacSections[i] = GeomUtils.makeOctRing(ex, ey, s.z, s.rx, s.ry)
        end

        for s = 1, #nacSections - 1 do
            GeomUtils.connectRings(nacGeom, nacSections[s], nacSections[s + 1])
        end

        -- 封闭进气口（环面）
        local firstSec = eCfg.nacelleSections[1]
        local lastSec = eCfg.nacelleSections[#eCfg.nacelleSections]
        local fPts = nacSections[1]
        local inF = GeomUtils.makeOctRing(ex, ey, firstSec.z, eCfg.intakeInnerR, eCfg.intakeInnerRY)
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            GeomUtils.addQuad(nacGeom, fPts[i], inF[i], inF[i2], fPts[i2])
        end

        -- 封闭喷口（环面）
        local bPts = nacSections[#nacSections]
        local inB = GeomUtils.makeOctRing(ex, ey, lastSec.z, eCfg.nozzleInnerR, eCfg.nozzleInnerRY)
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            GeomUtils.addQuad(nacGeom, bPts[i2], inB[i2], inB[i], bPts[i])
        end

        nacGeom:Commit()
        nacGeom:SetMaterial(hullDark)
        nacGeom.castShadows = true

        -- 进气口发光环
        local intakeNode = shipNode:CreateChild("Intake")
        local intGeom = intakeNode:CreateComponent("CustomGeometry")
        intGeom:BeginGeometry(0, TRIANGLE_LIST)
        local intOuter = GeomUtils.makeOctRing(ex, ey, firstSec.z + 0.01, firstSec.rx + 0.005, firstSec.ry + 0.005)
        local intInner = GeomUtils.makeOctRing(ex, ey, firstSec.z + 0.01, firstSec.rx - 0.005, firstSec.ry - 0.005)
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            GeomUtils.addQuad(intGeom, intOuter[i], intInner[i], intInner[i2], intOuter[i2])
        end
        intGeom:Commit()
        intGeom:SetMaterial(energyLine)
        intGeom.castShadows = false

        -- 喷口外环
        local nr = eCfg.nozzleRing
        local nozNode = shipNode:CreateChild("Nozzle")
        local nozGeom = nozNode:CreateComponent("CustomGeometry")
        nozGeom:BeginGeometry(0, TRIANGLE_LIST)
        local nozOuter = GeomUtils.makeOctRing(ex, ey, nr.z1, nr.outerR, nr.outerRY)
        local nozInner = GeomUtils.makeOctRing(ex, ey, nr.z1, nr.innerR, nr.innerRY)
        local nozOuterB = GeomUtils.makeOctRing(ex, ey, nr.z2, nr.outerR2, nr.outerRY2)
        local nozInnerB = GeomUtils.makeOctRing(ex, ey, nr.z2, nr.innerR2, nr.innerRY2)
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            GeomUtils.addQuad(nozGeom, nozOuter[i], nozInner[i], nozInner[i2], nozOuter[i2])
            GeomUtils.addQuad(nozGeom, nozOuter[i], nozOuterB[i], nozOuterB[i2], nozOuter[i2])
            GeomUtils.addQuad(nozGeom, nozInner[i2], nozInnerB[i2], nozInnerB[i], nozInner[i])
            GeomUtils.addQuad(nozGeom, nozOuterB[i2], nozInnerB[i2], nozInnerB[i], nozOuterB[i])
        end
        nozGeom:Commit()
        nozGeom:SetMaterial(hullDark)
        nozGeom.castShadows = true

        -- 引擎焰芯
        local flame = shipNode:CreateChild("Flame")
        flame.position = Vector3(ex, eCfg.flamePos.y, eCfg.flamePos.z1)
        flame.scale = Vector3(eCfg.flameScale1[1], eCfg.flameScale1[2], eCfg.flameScale1[3])
        local flM = flame:CreateComponent("StaticModel")
        flM:SetModel(resourceCache:GetResource("Model", "Models/Sphere.mdl"))
        flM:SetMaterial(engineGlow)

        -- 引擎外焰
        local flame2 = shipNode:CreateChild("Flame2")
        flame2.position = Vector3(ex, eCfg.flamePos.y, eCfg.flamePos.z2)
        flame2.scale = Vector3(eCfg.flameScale2[1], eCfg.flameScale2[2], eCfg.flameScale2[3])
        local fl2M = flame2:CreateComponent("StaticModel")
        fl2M:SetModel(resourceCache:GetResource("Model", "Models/Sphere.mdl"))
        fl2M:SetMaterial(MakeGlowMat(unpack(matDefs.flame2)))

        -- 引擎光源（perVertex 减少渲染视图占用）
        local eLt = shipNode:CreateChild("ELt")
        eLt.position = Vector3(ex, eCfg.flamePos.y, eCfg.lightZ)
        local el = eLt:CreateComponent("Light")
        el.lightType = LIGHT_POINT
        el.color = Color(eCfg.lightColor[1], eCfg.lightColor[2], eCfg.lightColor[3])
        el.brightness = eCfg.lightBrightness
        el.range = eCfg.lightRange
        el.perVertex = true
    end

    -- ==== 中央辅助引擎 ====
    local ce = ShipGeo.centralEngine
    local cEng = shipNode:CreateChild("CEng")
    cEng.position = Vector3(ce.pos[1], ce.pos[2], ce.pos[3])
    cEng.scale = Vector3(ce.scale[1], ce.scale[2], ce.scale[3])
    local ceM = cEng:CreateComponent("StaticModel")
    ceM:SetModel(resourceCache:GetResource("Model", "Models/Box.mdl"))
    ceM:SetMaterial(hullDark)

    local cFlame = shipNode:CreateChild("CFlame")
    cFlame.position = Vector3(ce.flamePos[1], ce.flamePos[2], ce.flamePos[3])
    cFlame.scale = Vector3(ce.flameScale[1], ce.flameScale[2], ce.flameScale[3])
    local cfM = cFlame:CreateComponent("StaticModel")
    cfM:SetModel(resourceCache:GetResource("Model", "Models/Sphere.mdl"))
    cfM:SetMaterial(reactorMat)

    -- ==== 细节装饰 ====
    local det = ShipGeo.details

    -- 能量管线
    for side = -1, 1, 2 do
        local pipe = shipNode:CreateChild("Pipe")
        pipe.position = Vector3(side * det.pipes.xOffset, det.pipes.y, det.pipes.z)
        pipe.scale = Vector3(det.pipes.scale[1], det.pipes.scale[2], det.pipes.scale[3])
        local pM = pipe:CreateComponent("StaticModel")
        pM:SetModel(resourceCache:GetResource("Model", "Models/Box.mdl"))
        pM:SetMaterial(energyLine)
    end

    -- 反应堆核心
    local rct = det.reactor
    GeomUtils.createHexLight(shipNode, "Reactor", Vector3(rct.pos[1], rct.pos[2], rct.pos[3]),
                             Vector3(0, -1, 0), rct.radius, reactorMat)
    local rctLight = shipNode:CreateChild("RLight")
    rctLight.position = Vector3(rct.pos[1], rct.pos[2], rct.pos[3])
    local rl = rctLight:CreateComponent("Light")
    rl.lightType = LIGHT_POINT
    rl.color = Color(rct.lightColor[1], rct.lightColor[2], rct.lightColor[3])
    rl.brightness = rct.lightBrightness
    rl.range = rct.lightRange
    rl.perVertex = true

    -- 武器挂点
    local wp = det.weapons
    for side = -1, 1, 2 do
        local pylon = shipNode:CreateChild("Pylon")
        pylon.position = Vector3(side * wp.xOffset, wp.pylonY, 0.0)
        pylon.scale = Vector3(wp.pylonScale[1], wp.pylonScale[2], wp.pylonScale[3])
        local pyM = pylon:CreateComponent("StaticModel")
        pyM:SetModel(resourceCache:GetResource("Model", "Models/Box.mdl"))
        pyM:SetMaterial(hullDark)

        for offset = -wp.gunSpacing * 0.5, wp.gunSpacing * 0.5, wp.gunSpacing do
            local gun = shipNode:CreateChild("Gun")
            gun.position = Vector3(side * wp.xOffset + offset, wp.gunY, wp.gunZ)
            gun.rotation = Quaternion(90, Vector3.RIGHT)
            gun.scale = Vector3(wp.gunScale[1], wp.gunScale[2], wp.gunScale[3])
            local gM = gun:CreateComponent("StaticModel")
            gM:SetModel(resourceCache:GetResource("Model", "Models/Cylinder.mdl"))
            gM:SetMaterial(hullDark)
        end

        -- 炮口光环
        local mRing = shipNode:CreateChild("MRing")
        mRing.position = Vector3(side * wp.xOffset, wp.gunY, wp.muzzleZ)
        mRing.rotation = Quaternion(90, Vector3.RIGHT)
        mRing.scale = Vector3(wp.muzzleScale[1], wp.muzzleScale[2], wp.muzzleScale[3])
        local mrM = mRing:CreateComponent("StaticModel")
        mrM:SetModel(resourceCache:GetResource("Model", "Models/Cylinder.mdl"))
        mrM:SetMaterial(energyLine)
    end

    -- 护盾发生器
    local sg = det.shieldGens
    for side = -1, 1, 2 do
        local sgNormal = Vector3(side * 0.2, 0.98, 0):Normalized()
        GeomUtils.createHexLight(shipNode, "SGen", Vector3(side * sg.xOffset, sg.y, sg.z), sgNormal, sg.radius, shieldEmit)
    end

    -- 腹部散热灯
    local ventMat = MakeGlowMat(unpack(matDefs.ventGlow))
    local vt = det.vents
    for i = 0, vt.count - 1 do
        GeomUtils.createHexLight(shipNode, "Vent", Vector3(0, vt.y, vt.zStart + i * vt.zSpacing),
                                 Vector3(0, -1, 0), vt.radius, ventMat)
    end

    return {
        shipNode = shipNode,
        hullMain = hullMain,
        hullDark = hullDark,
        hullAccent = hullAccent,
        energyLine = energyLine,
        engineGlow = engineGlow,
        reactorMat = reactorMat,
    }
end

return ShipBuilder
