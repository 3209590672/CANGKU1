-- ============================================================================
-- GameState: 纯数据容器（无逻辑）
-- 遵循编程准则：SRP（一句话 = 持有当前局游戏的全部运行时状态数据）
-- 所有数值参数统一从 Config 读取，Config 为唯一数据源
-- ============================================================================

local Config = require("layer4_content/config")

local GameState = {}

--- 创建一局新的初始状态
function GameState.new()
    return {
        -- === 游戏流程 ===
        phase = 1,           -- 由 FSM transition 事件同步写入
        gameTime = 0,
        frameCount = 0,

        -- === 战斗 ===
        score = 0,
        lives = Config.ship.lives,
        invincibleTimer = 0,
        invincibleDuration = Config.invincible.duration,

        -- === 移动 ===
        speed = Config.speed.initial,
        maxSpeed = Config.speed.max,
        speedIncrement = Config.speed.increment,
        shipX = 0.0,
        shipY = 0.0,
        shipMoveSpeed = Config.ship.moveSpeed,
        moveRangeX = 6.0,       -- 动态计算，由 CalculateVisibleRange 覆写
        moveRangeY = 3.2,       -- 动态计算，由 CalculateVisibleRange 覆写
        shipVelX = 0.0,
        shipVelY = 0.0,
        shipAccel = Config.ship.accel,
        shipDecel = Config.ship.decel,
        currentTiltX = 0.0,
        currentTiltZ = 0.0,

        -- === 护盾 ===
        shieldActive = false,
        shieldDuration = Config.shield.duration,
        shieldTimer = 0,
        shieldCooldown = Config.shield.cooldown,
        shieldCoolTimer = 0,
        shieldAnimTime = Config.shield.animTime,
        shieldAnimTimer = 0,
        shieldAnimState = "none",

        -- === 翻滚 ===
        rollActive = false,
        rollTimer = 0,
        rollDuration = Config.roll.duration,
        rollDirection = 0,
        rollAngle = 0,
        rollCd = Config.roll.cooldown,
        rollCdLeftTimer = 0,
        rollCdRightTimer = 0,
        rollWobbleTimer = 0,
        rollWobbleDuration = Config.roll.wobbleDuration,
        rollWobbleDir = 0,

        -- === 折跃 ===
        warpEnergy = 0,
        warpMaxEnergy = Config.warp.maxEnergy,
        warpCharging = false,
        warpChargeTime = Config.warp.chargeTime,
        warpChargeTimer = 0,
        warpActive = false,
        warpDuration = Config.warp.duration,
        warpTimer = 0,
        warpSpeed = Config.warp.speed,

        -- === 小行星 ===
        asteroids = {},
        asteroidSpawnTimer = 0,
        asteroidSpawnInterval = Config.asteroid.spawnInterval,
        asteroidMinInterval = Config.asteroid.minInterval,

        -- === 碰撞参数 ===
        shipRadius = Config.ship.radius,
        asteroidRadius = Config.asteroid.radius,
    }
end

--- 重置为游戏开始状态（保留 moveRange 等动态计算值）
--- 注意：phase 由 FSM 驱动，不在此处设置
function GameState.resetForNewGame(state)
    state.score = 0
    state.lives = Config.ship.lives
    state.speed = Config.speed.initial
    state.shipX = 0.0
    state.shipY = 0.0
    state.shipVelX = 0.0
    state.shipVelY = 0.0
    state.currentTiltX = 0.0
    state.currentTiltZ = 0.0
    state.gameTime = 0
    state.invincibleTimer = 0
    state.asteroidSpawnTimer = 0
    state.asteroidSpawnInterval = Config.asteroid.spawnInterval

    -- 护盾
    state.shieldActive = false
    state.shieldTimer = 0
    state.shieldCoolTimer = 0
    state.shieldAnimState = "none"
    state.shieldAnimTimer = 0

    -- 翻滚
    state.rollActive = false
    state.rollTimer = 0
    state.rollAngle = 0
    state.rollCdLeftTimer = 0
    state.rollCdRightTimer = 0
    state.rollWobbleTimer = 0

    -- 折跃
    state.warpEnergy = 0
    state.warpCharging = false
    state.warpChargeTimer = 0
    state.warpActive = false
    state.warpTimer = 0

    -- 小行星列表清空由调用者负责（需要 Remove 节点）
    state.asteroids = {}
end

return GameState
