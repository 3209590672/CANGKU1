--[[
Layer 3 - 游戏逻辑层：游戏流程管理
职责：状态切换（菜单/游戏/结束/剧情）、模块重置协调、对象清理
依赖：通过 init(ctx) 注入所有外部引用
--]]

local M = {}

-- 上下文引用（由 init 注入）
local ctx = nil

--- 初始化游戏流程模块
---@param context table 包含所有必要引用的上下文表
--[[
  context = {
    gs,                  -- 游戏状态表
    STATE_MENU,          -- 状态常量
    STATE_PLAYING,
    STATE_GAMEOVER,
    STATE_STORY_CHOICE,
    STATE_STORY_ENDING,
    -- 节点引用
    shipNode,
    -- 模块引用
    GameState, GameAudio, Crystals, Weapons, Asteroids, Effects, Background,
    Shield, EngineTrails, WarpVisuals, story,
    -- UI 回调（由 main 提供，避免循环引用）
    showMenuUI, showPlayingUI, showGameOverUI, showStoryChoiceUI, showStoryEndingUI,
    playEndingBGM, stopEndingBGM,
  }
--]]
function M.init(context)
    ctx = context
end

--- 清除所有游戏对象
function M.clearObjects()
    ctx.Asteroids.clearAll()
    ctx.Crystals.clearCrystals()
    ctx.Weapons.clearBullets()
    ctx.Effects.clearExplosions()
end

--- 开始新游戏
function M.startGame()
    -- 停止所有 BGM（游戏中无音乐）
    ctx.stopEndingBGM()
    ctx.GameAudio.muteMainBGM()

    -- 重置所有游戏状态数据
    ctx.GameState.resetForNewGame(ctx.gs)

    -- 重置各模块
    ctx.Crystals.reset()
    ctx.Weapons.reset()

    -- 重置护盾视觉
    ctx.Shield.reset(ctx.gs)

    -- 重置翼尖拖尾视觉
    ctx.WarpVisuals.resetWingTrail()

    -- 重置剧情系统
    ctx.story:reset()

    -- 清除所有障碍物
    M.clearObjects()

    -- 重置飞船
    local ship = ctx.shipNode
    ship:SetEnabled(true)
    ship.position = Vector3(0, 0, 0)
    ship.rotation = Quaternion(0, 0, 0)

    -- 重置拖尾位置（避免残留）
    ctx.EngineTrails.resetPositions(ship)

    -- 切换到游戏 HUD
    ctx.showPlayingUI()

    print("=== Game Started ===")
end

--- 游戏结束
function M.gameOver()
    ctx.gs.phase = ctx.STATE_GAMEOVER
    print(string.format("=== Game Over | Score: %d ===", ctx.gs.score))
    ctx.showGameOverUI()
end

--- 返回主菜单
function M.returnToMenu()
    -- 停止结局BGM
    ctx.stopEndingBGM()
    ctx.GameAudio.resumeMainBGM()

    -- 清除游戏物体
    M.clearObjects()

    -- 重新生成装饰物
    ctx.Background.createStarDusts()
    ctx.Background.createDecoAsteroids()
    ctx.Background.createMeteors()

    -- 重置飞船到菜单状态
    local ship = ctx.shipNode
    if ship then
        ship:SetEnabled(true)
        ship.position = Vector3(0, 0, 0)
        ship.rotation = Quaternion(0, 0, 0)
    end

    -- 切换到菜单
    ctx.gs.phase = ctx.STATE_MENU
    ctx.showMenuUI()
end

--- 剧情选择完成后回调
---@param isEnding boolean 是否进入结局
function M.onStoryChoiceMade(isEnding)
    if isEnding then
        M.showStoryEnding()
    else
        ctx.gs.phase = ctx.STATE_PLAYING
        ctx.showPlayingUI()
    end
end

--- 显示剧情结局画面
function M.showStoryEnding()
    ctx.gs.phase = ctx.STATE_STORY_ENDING
    local ending = ctx.story:getEnding()
    ctx.playEndingBGM(ending.key)
    ctx.showStoryEndingUI(ending)
end

--- 显示剧情选择画面
---@param thresholdIdx number 触发阈值索引
function M.showStoryChoice(thresholdIdx)
    ctx.gs.phase = ctx.STATE_STORY_CHOICE
    ctx.showStoryChoiceUI(thresholdIdx)
end

return M
