--[[
Layer 3 - 游戏逻辑层：游戏流程管理
职责：状态切换（菜单/游戏/结束/剧情）、模块重置协调、对象清理
依赖：通过 init(ctx) 注入最小依赖集（ISP）
通信：
  - 状态切换通过 FSM:go() 完成，gs.phase 由 FSM transition 事件自动同步
  - 跨模块通知通过 EventBus 发射事件（game_start / game_return_menu）
  - UI 编排回调由 main 提供（避免循环引用）
--]]

local M = {}

-- 最小依赖集（由 init 注入）
---@type table
local gs_ = nil
---@type table
local fsm_ = nil
---@type table
local eventBus_ = nil
---@type Node
local shipNode_ = nil
---@type table
local GameState_ = nil
---@type table
local Crystals_ = nil
---@type table
local Weapons_ = nil
---@type table
local Asteroids_ = nil
---@type table
local Effects_ = nil
---@type table
local Shield_ = nil
---@type table
local EngineTrails_ = nil
---@type table
local story_ = nil

-- UI 回调（由 main 提供，避免循环引用）
local showMenuUI_ = nil
local showPlayingUI_ = nil
local showGameOverUI_ = nil

--- 初始化游戏流程模块
---@param ctx table 最小依赖集
--[[
  ctx = {
    gs, fsm, eventBus, shipNode,
    GameState, Crystals, Weapons, Asteroids, Effects, Shield, EngineTrails, story,
    showMenuUI, showPlayingUI, showGameOverUI,
  }
--]]
function M.init(ctx)
    gs_ = ctx.gs
    fsm_ = ctx.fsm
    eventBus_ = ctx.eventBus
    shipNode_ = ctx.shipNode
    GameState_ = ctx.GameState
    Crystals_ = ctx.Crystals
    Weapons_ = ctx.Weapons
    Asteroids_ = ctx.Asteroids
    Effects_ = ctx.Effects
    Shield_ = ctx.Shield
    EngineTrails_ = ctx.EngineTrails
    story_ = ctx.story
    showMenuUI_ = ctx.showMenuUI
    showPlayingUI_ = ctx.showPlayingUI
    showGameOverUI_ = ctx.showGameOverUI
end

--- 清除所有游戏对象
function M.clearObjects()
    Asteroids_.clearAll()
    Crystals_.clearCrystals()
    Weapons_.clearBullets()
    Effects_.clearExplosions()
end

--- 开始新游戏
function M.startGame()
    -- 发射事件：让 GameAudio 等模块自行响应（DIP：不直接依赖 GameAudio）
    eventBus_:emit("game_start")

    -- ⚠️ 必须先清除旧对象（节点 Remove），再重置状态数据
    M.clearObjects()

    -- 重置所有游戏状态数据
    GameState_.resetForNewGame(gs_)

    -- FSM 切换到 playing（触发 gs.phase 同步）
    fsm_:go("playing")

    -- 重置各模块
    Crystals_.reset()
    Weapons_.reset()
    Shield_.reset(gs_)

    -- 重置剧情系统
    story_:reset()

    -- 重置飞船
    shipNode_:SetEnabled(true)
    shipNode_.position = Vector3(0, 0, 0)
    shipNode_.rotation = Quaternion(0, 0, 0)

    -- 重置拖尾位置（避免残留）
    EngineTrails_.resetPositions(shipNode_)

    -- 切换到游戏 HUD
    showPlayingUI_()

    print("=== Game Started ===")
end

--- 游戏结束
function M.gameOver()
    fsm_:go("gameover")
    print(string.format("=== Game Over | Score: %d ===", gs_.score))
    showGameOverUI_()
end

--- 返回主菜单
function M.returnToMenu()
    -- 发射事件：让 GameAudio / Background 等模块自行响应
    eventBus_:emit("game_return_menu")

    -- 清除游戏物体
    M.clearObjects()

    -- 重置飞船到菜单状态
    if shipNode_ then
        shipNode_:SetEnabled(true)
        shipNode_.position = Vector3(0, 0, 0)
        shipNode_.rotation = Quaternion(0, 0, 0)
    end

    -- 切换到菜单
    fsm_:go("menu")
    showMenuUI_()
end

--- 剧情选择完成后回调
---@param isEnding boolean 是否进入结局
function M.onStoryChoiceMade(isEnding)
    if isEnding then
        fsm_:go("story_ending")
    else
        fsm_:go("playing")
        showPlayingUI_()
    end
end



return M
