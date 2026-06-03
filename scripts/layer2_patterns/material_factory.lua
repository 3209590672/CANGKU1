-- ============================================================================
-- Layer2: 材质工厂（通用 PBR 材质创建工具，零游戏依赖）
-- ============================================================================

local MaterialFactory = {}

local cache = nil
local techOpaque = nil
local techAlpha = nil

--- 初始化（需在游戏启动后调用一次）
function MaterialFactory.init(resourceCache)
    cache = resourceCache
    techOpaque = cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml")
    techAlpha = cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml")
end

--- 解析 technique 名称为引擎对象（OCP：新增 tech 只需扩展此表）
local techMap -- 延迟初始化
local function resolveTech(name)
    if not techMap then
        techMap = { opaque = techOpaque, alpha = techAlpha }
    end
    return techMap[name] or techOpaque
end

--- 从定义数据创建单个材质
--- @param def table { tech, diff, emissive, metallic, roughness }
--- @return Material
function MaterialFactory.create(def)
    if def.cacheResource then
        return cache:GetResource("Material", def.cacheResource)
    end
    local mat = Material:new()
    mat:SetTechnique(0, resolveTech(def.tech))
    local d = def.diff
    mat:SetShaderParameter("MatDiffColor", Variant(Color(d[1], d[2], d[3], d[4] or 1.0)))
    if def.emissive then
        local e = def.emissive
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(e[1], e[2], e[3])))
    end
    mat:SetShaderParameter("Metallic", Variant(def.metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(def.roughness or 0.5))
    return mat
end

--- 从颜色列表批量创建材质数组
--- @param def table { tech, colors, alpha, emissiveScale, metallic, roughness }
--- @return table 材质数组
function MaterialFactory.createColorArray(def)
    local result = {}
    local tech = resolveTech(def.tech)
    for idx, c in ipairs(def.colors) do
        local mat = Material:new()
        mat:SetTechnique(0, tech)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(c[1], c[2], c[3], def.alpha or 1.0)))
        if def.emissiveScale then
            local s = def.emissiveScale
            mat:SetShaderParameter("MatEmissiveColor", Variant(Color(c[1] * s, c[2] * s, c[3] * s)))
        end
        mat:SetShaderParameter("Metallic", Variant(def.metallic or 0.0))
        mat:SetShaderParameter("Roughness", Variant(def.roughness or 0.5))
        result[idx] = mat
    end
    return result
end

--- 创建子弹拖尾渐变材质数组
--- @param def table { tech, count, baseDiff, baseEmissive, metallic, roughness }
--- @return table 材质数组
function MaterialFactory.createTrailArray(def)
    local result = {}
    local tech = resolveTech(def.tech)
    for i = 1, def.count do
        local fade = 1.0 - (i / (def.count + 1))
        local mat = Material:new()
        mat:SetTechnique(0, tech)
        local bd = def.baseDiff
        mat:SetShaderParameter("MatDiffColor", Variant(Color(bd[1], bd[2], bd[3], 0.2 * fade)))
        local be = def.baseEmissive
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(be[1] * fade, be[2] * fade, be[3] * fade)))
        mat:SetShaderParameter("Metallic", Variant(def.metallic or 0.0))
        mat:SetShaderParameter("Roughness", Variant(def.roughness or 0.0))
        result[i] = mat
    end
    return result
end

--- 创建小行星岩石及碎石材质对
--- @param def table { tech, colors, metallic, roughness, debrisDarkScale, debrisMetallic, debrisRoughness }
--- @return table rockMats, table debrisMats
function MaterialFactory.createRockPairs(def)
    local rocks = {}
    local debris = {}
    local tech = resolveTech(def.tech)
    for idx, c in ipairs(def.colors) do
        local mat = Material:new()
        mat:SetTechnique(0, tech)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(c[1], c[2], c[3], 1.0)))
        mat:SetShaderParameter("Metallic", Variant(def.metallic))
        mat:SetShaderParameter("Roughness", Variant(def.roughness))
        rocks[idx] = mat

        local dMat = Material:new()
        dMat:SetTechnique(0, tech)
        local ds = def.debrisDarkScale
        dMat:SetShaderParameter("MatDiffColor", Variant(Color(c[1] * ds, c[2] * ds, c[3] * ds, 1.0)))
        dMat:SetShaderParameter("Metallic", Variant(def.debrisMetallic))
        dMat:SetShaderParameter("Roughness", Variant(def.debrisRoughness))
        debris[idx] = dMat
    end
    return rocks, debris
end

return MaterialFactory
