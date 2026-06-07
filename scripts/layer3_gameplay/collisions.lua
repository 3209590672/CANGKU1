-- ============================================================================
-- Collisions 模块：碰撞检测
-- 职责：子弹vs小行星、飞船vs小行星、飞船vs水晶
-- 数据变更通过直接读写 GameState 完成（纯数据容器模式）
-- 跨模块通知通过 EventBus 发射事件（解耦模块间依赖）
-- ============================================================================
local math_floor = math.floor
local table_remove = table.remove

local Collisions = {}

-- 依赖注入
---@type table
local state_ = nil
---@type table
local Weapons_ = nil
---@type table
local Asteroids_ = nil
---@type table
local Crystals_ = nil
---@type table
local Effects_ = nil
---@type table
local eventBus_ = nil  -- Layer 1 事件总线

--- 初始化
---@param ctx table
function Collisions.init(ctx)
    state_ = ctx.state
    Weapons_ = ctx.Weapons
    Asteroids_ = ctx.Asteroids
    Crystals_ = ctx.Crystals
    Effects_ = ctx.Effects
    eventBus_ = ctx.eventBus
end

--- 每帧碰撞检测
function Collisions.check()
    local shipPos = Vector3(state_.shipX, state_.shipY, 0)
    local scoreMul = state_.warpActive and 2 or 1

    -- 子弹 vs 小行星
    local bullets = Weapons_.getBullets()
    local asteroids = state_.asteroids
    local numBullets = #bullets
    local numAsteroids = #asteroids
    if numBullets > 0 and numAsteroids > 0 then
        for bi = numBullets, 1, -1 do
            local bullet = bullets[bi]
            local bPos = bullet.node.position
            local bz = bPos.z
            local bx = bPos.x
            local by = bPos.y
            local hit = false

            for ai = numAsteroids, 1, -1 do
                local asteroid = asteroids[ai]
                local aPos = asteroid.node.position
                local dz = bz - aPos.z
                if dz > -3 and dz < 3 then
                    local dx = bx - aPos.x
                    local dy = by - aPos.y
                    local dist2 = dx * dx + dy * dy + dz * dz
                    local r = 0.5 + asteroid.radius

                    if dist2 < r * r then
                        state_.score = state_.score + 5 * scoreMul
                        Effects_.spawnExplosion(asteroid.node.position, asteroid.radius * 1.2, { 0.9, 0.4, 0.1 })
                        Asteroids_.removeAt(ai)
                        numAsteroids = numAsteroids - 1
                        eventBus_:emit("asteroid_destroyed", asteroid.node.position)
                        hit = true
                        break
                    end
                end
            end

            if hit then
                Weapons_.removeBulletAt(bi)
            end
        end
    end

    -- 无敌/折跃/翻滚时跳过飞船碰撞
    if state_.invincibleTimer > 0 or state_.warpActive or state_.rollActive then return end

    -- 小行星 vs 飞船
    asteroids = state_.asteroids  -- 刷新引用（上面可能已修改）
    for i = #asteroids, 1, -1 do
        local asteroid = asteroids[i]
        local astPos = asteroid.node.position
        local dx = shipPos.x - astPos.x
        local dy = shipPos.y - astPos.y
        local dz = shipPos.z - astPos.z
        local dist2 = dx * dx + dy * dy + dz * dz

        local collideRadius = state_.shipRadius + asteroid.radius
        if state_.shieldActive then collideRadius = 1.5 + asteroid.radius end

        if dist2 < collideRadius * collideRadius then
            if state_.shieldActive then
                state_.score = state_.score + 5 * scoreMul
                Effects_.spawnExplosion(asteroid.node.position, asteroid.radius * 0.8, { 0.2, 0.6, 1.0 })
                Asteroids_.removeAt(i)
                eventBus_:emit("shield_block")
            else
                state_.lives = state_.lives - 1
                state_.invincibleTimer = state_.invincibleDuration
                Effects_.spawnExplosion(asteroid.node.position, asteroid.radius * 1.0, { 1.0, 0.2, 0.1 })
                Asteroids_.removeAt(i)
                eventBus_:emit("ship_hit", state_.lives)

                if state_.lives <= 0 then
                    eventBus_:emit("game_over", state_.score)
                    return
                end
                break
            end
        end
    end

    -- 水晶碰撞
    local crystals = Crystals_.getCrystals()
    for i = #crystals, 1, -1 do
        local crystal = crystals[i]
        local crPos = crystal.node.position
        local dx = shipPos.x - crPos.x
        local dy = shipPos.y - crPos.y
        local dz = shipPos.z - crPos.z
        local dist2 = dx * dx + dy * dy + dz * dz
        local r = state_.shipRadius + crystal.radius

        if dist2 < r * r then
            state_.score = state_.score + 10 * scoreMul
            if state_.warpEnergy < state_.warpMaxEnergy then
                state_.warpEnergy = state_.warpEnergy + 1
            end
            Crystals_.removeCrystalAt(i)
            eventBus_:emit("crystal_collected", state_.warpEnergy)
        end
    end
end

return Collisions
