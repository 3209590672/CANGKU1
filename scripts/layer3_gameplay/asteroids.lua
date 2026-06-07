-- ============================================================================
-- Asteroids 模块：小行星生成与更新
-- 职责：管理小行星的生成、移动、旋转、移除
-- ============================================================================
local table_remove = table.remove

local Asteroids = {}

-- 依赖注入
---@type table
local state_ = nil           -- GameState 引用（读写 asteroids, asteroidSpawnTimer 等）
---@type Scene
local scene_ = nil
---@type table
local AsteroidBuilder_ = nil
---@type table
local meshPool_ = nil
---@type number
local meshPoolSize_ = nil
---@type table
local rockMats_ = nil
---@type table
local debrisMats_ = nil
---@type any
local crackMat_ = nil
---@type any
local oreMat_ = nil
---@type any
local mdlSphere_ = nil
---@type any
local mdlBox_ = nil

--- 初始化（一次性，DI 注入所有依赖）
---@param ctx table
function Asteroids.init(ctx)
    state_ = ctx.state
    scene_ = ctx.scene
    AsteroidBuilder_ = ctx.AsteroidBuilder
    meshPool_ = ctx.meshPool
    meshPoolSize_ = ctx.meshPoolSize
    rockMats_ = ctx.rockMats
    debrisMats_ = ctx.debrisMats
    crackMat_ = ctx.crackMat
    oreMat_ = ctx.oreMat
    mdlSphere_ = ctx.mdlSphere
    mdlBox_ = ctx.mdlBox
end

--- 生成一个小行星
function Asteroids.spawn()
    local entry = AsteroidBuilder_.spawnAsteroid({
        scene = scene_,
        moveRangeX = state_.moveRangeX,
        moveRangeY = state_.moveRangeY,
        meshPool = meshPool_,
        meshPoolSize = meshPoolSize_,
        rockMats = rockMats_,
        debrisMats = debrisMats_,
        crackMat = crackMat_,
        oreMat = oreMat_,
        mdlSphere = mdlSphere_,
        mdlBox = mdlBox_,
    })
    table.insert(state_.asteroids, entry)
end

--- 每帧更新（生成定时 + 移动 + 超出视野移除）
---@param dt number
function Asteroids.update(dt)
    -- 生成计时
    state_.asteroidSpawnTimer = state_.asteroidSpawnTimer + dt
    if state_.asteroidSpawnTimer >= state_.asteroidSpawnInterval then
        state_.asteroidSpawnTimer = 0
        Asteroids.spawn()
    end

    -- 移动 & 旋转
    local asteroids = state_.asteroids
    local speed = state_.speed
    local frameCount = state_.frameCount
    local i = 1
    while i <= #asteroids do
        local asteroid = asteroids[i]
        local pos = asteroid.node.position
        pos.z = pos.z - speed * dt
        asteroid.node.position = pos

        -- 旋转（隔帧更新，节省性能）
        if (frameCount + i) % 2 == 0 then
            asteroid.node:Rotate(Quaternion(
                asteroid.rotSpeed.x * dt * 2,
                asteroid.rotSpeed.y * dt * 2,
                asteroid.rotSpeed.z * dt * 2
            ))
        end

        -- 超出视野移除
        if pos.z < -10 then
            asteroid.node:Remove()
            table_remove(asteroids, i)
        else
            i = i + 1
        end
    end
end

--- 清除所有小行星节点
function Asteroids.clearAll()
    for _, asteroid in ipairs(state_.asteroids) do
        if asteroid.node ~= nil then
            asteroid.node:Remove()
        end
    end
    state_.asteroids = {}
end

--- 获取小行星列表（供碰撞检测使用）
function Asteroids.getList()
    return state_.asteroids
end

--- 移除指定索引的小行星（碰撞后调用）
function Asteroids.removeAt(idx)
    local asteroid = state_.asteroids[idx]
    if asteroid and asteroid.node then
        asteroid.node:Remove()
    end
    table_remove(state_.asteroids, idx)
end

return Asteroids
