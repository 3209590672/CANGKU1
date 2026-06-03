--[[
Layer 2 - 可复用模式层：材质缓存管理器
统一管理 PBR 材质的创建与缓存，避免每帧重复创建
--]]

local MaterialCache = {}
MaterialCache.__index = MaterialCache

--- 创建材质缓存管理器
---@return table MaterialCache实例
function MaterialCache.new()
    local self = setmetatable({}, MaterialCache)
    self._cache = {}         -- { name = Material }
    self._techniques = {}    -- { name = Technique }
    self._models = {}        -- { name = Model }
    return self
end

--- 预加载常用 Technique
function MaterialCache:loadTechniques()
    self._techniques.pbrNoTex = cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml")
    self._techniques.pbrNoTexAlpha = cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml")
    self._techniques.diffUnlitAlpha = cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml")
end

--- 预加载常用 Model
function MaterialCache:loadModels()
    self._models.box = cache:GetResource("Model", "Models/Box.mdl")
    self._models.sphere = cache:GetResource("Model", "Models/Sphere.mdl")
    self._models.cylinder = cache:GetResource("Model", "Models/Cylinder.mdl")
    self._models.plane = cache:GetResource("Model", "Models/Plane.mdl")
end

--- 获取预加载的 Technique
---@param name string "pbrNoTex" | "pbrNoTexAlpha" | "diffUnlitAlpha"
---@return userdata Technique
function MaterialCache:technique(name)
    return self._techniques[name]
end

--- 获取预加载的 Model
---@param name string "box" | "sphere" | "cylinder" | "plane"
---@return userdata Model
function MaterialCache:model(name)
    return self._models[name]
end

--- 创建 PBR 材质（不透明）
---@param name string 缓存键名
---@param params table { diffuse={r,g,b}, emissive={r,g,b}, metallic=n, roughness=n }
---@return userdata Material
function MaterialCache:createPBR(name, params)
    local mat = Material:new()
    mat:SetTechnique(0, self._techniques.pbrNoTex)
    local d = params.diffuse or { 0.5, 0.5, 0.5 }
    mat:SetShaderParameter("MatDiffColor", Variant(Color(d[1], d[2], d[3], 1.0)))
    if params.emissive then
        local e = params.emissive
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(e[1], e[2], e[3])))
    end
    mat:SetShaderParameter("Metallic", Variant(params.metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(params.roughness or 0.5))
    self._cache[name] = mat
    return mat
end

--- 创建 PBR 半透明材质
---@param name string 缓存键名
---@param params table { diffuse={r,g,b,a}, emissive={r,g,b}, metallic=n, roughness=n }
---@return userdata Material
function MaterialCache:createPBRAlpha(name, params)
    local mat = Material:new()
    mat:SetTechnique(0, self._techniques.pbrNoTexAlpha)
    local d = params.diffuse or { 0.5, 0.5, 0.5, 0.5 }
    mat:SetShaderParameter("MatDiffColor", Variant(Color(d[1], d[2], d[3], d[4] or 0.5)))
    if params.emissive then
        local e = params.emissive
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(e[1], e[2], e[3])))
    end
    mat:SetShaderParameter("Metallic", Variant(params.metallic or 0.0))
    mat:SetShaderParameter("Roughness", Variant(params.roughness or 0.5))
    self._cache[name] = mat
    return mat
end

--- 获取已缓存的材质
---@param name string
---@return userdata|nil Material
function MaterialCache:get(name)
    return self._cache[name]
end

--- 缓存一个外部创建的材质
---@param name string
---@param mat userdata Material
function MaterialCache:set(name, mat)
    self._cache[name] = mat
end

--- 克隆已缓存材质
---@param sourceName string 源材质名
---@param newName string|nil 新缓存键名（nil则不缓存）
---@return userdata|nil Material
function MaterialCache:clone(sourceName, newName)
    local source = self._cache[sourceName]
    if not source then return nil end
    local cloned = source:Clone("")
    if newName then
        self._cache[newName] = cloned
    end
    return cloned
end

--- 批量创建材质组（如小行星6色）
---@param prefix string 前缀
---@param colorList table 颜色列表 { {r,g,b}, ... }
---@param params table 共享参数 { metallic, roughness }
---@return table 材质数组
function MaterialCache:createBatch(prefix, colorList, params)
    local mats = {}
    for idx, c in ipairs(colorList) do
        local name = prefix .. "_" .. idx
        mats[idx] = self:createPBR(name, {
            diffuse = c,
            metallic = params.metallic,
            roughness = params.roughness,
        })
    end
    return mats
end

return MaterialCache
