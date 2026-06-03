-- ============================================================================
-- GameState: 纯数据容器（无逻辑）
-- 遵循编程准则：SRP（一句话 = 持有当前局游戏的全部运行时状态数据）
-- ============================================================================

local GameState = {}

--- 创建一局新的初始状态
function GameState.new()
    return {
        -- === 游戏流程 ===
        phase = 1,           -- STATE_MENU=1, STATE_PLAYING=2, STATE_GAMEOVER=3, STATE_STORY_CHOICE=4, STATE_STORY_ENDING=5
        gameTime = 0,
        frameCount = 0,

        -- === 战斗 ===
        score = 0,
        lives = 5,
        invincibleTimer = 0,
        invincibleDuration = 1.5,

        -- === 移动 ===
        speed = 20.0,
        maxSpeed = 80.0,
        speedIncrement = 0.5,
        shipX = 0.0,
        shipY = 0.0,
        shipMoveSpeed = 6.5,
        moveRangeX = 6.0,
        moveRangeY = 3.2,
        shipVelX = 0.0,
        shipVelY = 0.0,
        shipAccel = 60.0,
        shipDecel = 40.0,
        currentTiltX = 0.0,
        currentTiltZ = 0.0,

        -- === 护盾 ===
        shieldActive = false,
        shieldDuration = 5.0,
        shieldTimer = 0,
        shieldCooldown = 5.0,
        shieldCoolTimer = 0,
        shieldAnimTime = 0.75,
        shieldAnimTimer = 0,
        shieldAnimState = "none",

        -- === 翻滚 ===
        rollActive = false,
        rollTimer = 0,
        rollDuration = 0.5,
        rollDirection = 0,
        rollAngle = 0,
        rollCd = 5.0,
        rollCdLeftTimer = 0,
        rollCdRightTimer = 0,
        rollWobbleTimer = 0,
        rollWobbleDuration = 1.0,
        rollWobbleDir = 0,

        -- === 折跃 ===
        warpEnergy = 0,
        warpMaxEnergy = 5,
        warpCharging = false,
        warpChargeTime = 5.0,
        warpChargeTimer = 0,
        warpActive = false,
        warpDuration = 10.0,
        warpTimer = 0,
        warpSpeed = 150.0,

        -- === 小行星 ===
        asteroids = {},
        asteroidSpawnTimer = 0,
        asteroidSpawnInterval = 0.4,
        asteroidMinInterval = 0.12,

        -- === 碰撞参数 ===
        shipRadius = 0.8,
        asteroidRadius = 1.2,
    }
end

--- 重置为游戏开始状态（保留 moveRange 等动态计算值）
function GameState.resetForNewGame(state)
    state.phase = 2  -- STATE_PLAYING
    state.score = 0
    state.lives = 5
    state.speed = 20.0
    state.shipX = 0.0
    state.shipY = 0.0
    state.shipVelX = 0.0
    state.shipVelY = 0.0
    state.currentTiltX = 0.0
    state.currentTiltZ = 0.0
    state.gameTime = 0
    state.invincibleTimer = 0
    state.asteroidSpawnTimer = 0
    state.asteroidSpawnInterval = 0.4

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
