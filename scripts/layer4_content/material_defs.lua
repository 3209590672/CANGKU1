-- ============================================================================
-- Layer4: 材质定义数据（纯数据，无逻辑）
-- 格式: { tech="opaque"|"alpha", diff={r,g,b,a}, emissive={r,g,b}|nil, metallic=N, roughness=N }
-- ============================================================================

local MatDefs = {}

-- ========== 护盾 ==========
MatDefs.shieldPulse = {
    tech = "alpha",
    diff = { 0.3, 0.7, 1.0, 0.08 },
    emissive = { 0.8, 2.0, 5.0 },
    metallic = 0.0, roughness = 1.0,
}

-- ========== 子弹 ==========
MatDefs.bulletCore = {
    tech = "opaque",
    diff = { 0.8, 1.0, 0.9, 1.0 },
    emissive = { 1.5, 3.5, 2.0 },
    metallic = 0.0, roughness = 0.0,
}

MatDefs.bulletGlow = {
    tech = "alpha",
    diff = { 0.2, 0.9, 0.5, 0.25 },
    emissive = { 0.4, 1.8, 0.8 },
    metallic = 0.0, roughness = 0.0,
}

MatDefs.bulletTip = {
    tech = "opaque",
    diff = { 1.0, 1.0, 1.0, 1.0 },
    emissive = { 2.0, 4.0, 2.5 },
    metallic = 0.0, roughness = 0.0,
}

-- 子弹拖尾（5级衰减）
MatDefs.bulletTrail = {
    tech = "alpha",
    count = 5,
    -- 生成器参数: fade = 1 - (i / 6)
    baseDiff = { 0.1, 0.8, 0.4 },   -- alpha = 0.2 * fade
    baseEmissive = { 0.3, 1.5, 0.6 }, -- 乘以 fade
    metallic = 0.0, roughness = 0.0,
}

-- ========== 爆炸 ==========
MatDefs.explosionRay = {
    tech = "alpha",
    diff = { 1.0, 0.85, 0.4, 0.95 },
    emissive = { 9.0, 3.5, 0.6 },
    metallic = 0.0, roughness = 0.0,
}

MatDefs.explosionDebris = {
    tech = "opaque",
    diff = { 0.3, 0.15, 0.08, 1.0 },
    emissive = { 1.8, 0.4, 0.0 },
    metallic = 0.2, roughness = 0.85,
}

-- 爆炸光球基础材质（引擎缓存资源路径）
MatDefs.explosionGlowBase = {
    cacheResource = "Materials/DefaultGrey.xml",
}

-- ========== 水晶（3色） ==========
MatDefs.crystal = {
    tech = "alpha",
    colors = {
        { 0.2, 1.0, 0.4 },
        { 0.3, 0.6, 1.0 },
        { 1.0, 0.8, 0.2 },
    },
    alpha = 0.7,
    emissiveScale = 2.5,
    metallic = 0.95, roughness = 0.02,
}

-- ========== 小行星岩石（6色） ==========
MatDefs.asteroidRock = {
    tech = "opaque",
    colors = {
        { 0.165, 0.145, 0.12 },
        { 0.235, 0.20, 0.165 },
        { 0.12, 0.12, 0.14 },
        { 0.20, 0.185, 0.145 },
        { 0.095, 0.08, 0.075 },
        { 0.27, 0.215, 0.135 },
    },
    metallic = 0.38, roughness = 0.64,
    -- 碎石变体参数
    debrisDarkScale = 0.85,
    debrisMetallic = 0.29, debrisRoughness = 0.73,
}

-- 熔岩裂缝
MatDefs.asteroidCrack = {
    tech = "opaque",
    diff = { 0.5, 0.15, 0.02, 1.0 },
    emissive = { 2.0, 0.5, 0.05 },
    metallic = 0.0, roughness = 0.95,
}

-- 冰晶矿脉
MatDefs.asteroidOre = {
    tech = "opaque",
    diff = { 0.1, 0.3, 0.5, 1.0 },
    emissive = { 0.3, 0.7, 1.5 },
    metallic = 0.6, roughness = 0.2,
}

-- ========== 星尘 ==========
MatDefs.starDust = {
    tech = "opaque",
    diff = { 0.75, 0.75, 0.75, 1.0 },
    emissive = { 1.5, 1.5, 1.5 },
    metallic = 0.0, roughness = 1.0,
}

-- ========== 装饰陨石 ==========
MatDefs.decoAsteroid = {
    tech = "opaque",
    diff = { 0.12, 0.10, 0.09, 1.0 },
    metallic = 0.3, roughness = 0.8,
}

-- ========== 流星 ==========
MatDefs.meteor = {
    tech = "opaque",
    diff = { 0.6, 0.7, 0.9, 1.0 },
    emissive = { 3.0, 3.5, 5.0 },
    metallic = 0.0, roughness = 1.0,
}

-- ========== 小行星顶点颜色（SpawnAsteroid 使用） ==========
MatDefs.asteroidVertexColors = {
    { 0.25, 0.22, 0.18 },
    { 0.35, 0.30, 0.25 },
    { 0.18, 0.18, 0.20 },
    { 0.30, 0.28, 0.22 },
    { 0.15, 0.12, 0.10 },
    { 0.40, 0.32, 0.20 },
}

-- ========== 装饰陨石顶点颜色 ==========
MatDefs.decoAsteroidVertexColors = {
    { 0.12, 0.10, 0.09 },
    { 0.15, 0.13, 0.11 },
    { 0.09, 0.09, 0.11 },
    { 0.14, 0.12, 0.10 },
    { 0.07, 0.06, 0.06 },
    { 0.18, 0.14, 0.09 },
}

return MatDefs
