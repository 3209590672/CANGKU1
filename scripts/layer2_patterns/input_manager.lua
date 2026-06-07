--[[
Layer 2 - 可复用模式层：输入管理器
封装键盘/鼠标/触摸输入状态查询，提供语义化统一接口

设计意图：
  - 所有按键绑定集中于此，方便日后改键/手柄适配
  - 上层逻辑只关心"意图"而非"哪个键"
  - 手机端自动代理到 TouchControls 模块
--]]

local TouchControls = require("layer2_patterns/touch_controls")

local InputManager = {}
InputManager.__index = InputManager

--- 创建输入管理器
---@return table InputManager实例
function InputManager.new()
    local self = setmetatable({}, InputManager)
    return self
end

-- ============================================================================
-- 移动
-- ============================================================================

--- 获取水平移动方向 (-1, 0, +1)  手机端返回连续值 (-1 ~ +1)
---@return number
function InputManager:getHorizontal()
    -- 触摸摇杆优先（手机端）
    if TouchControls.isMobile() and TouchControls.hasMovement() then
        return TouchControls.getHorizontal()
    end
    -- 键盘输入
    local h = 0
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then
        h = h - 1
    end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then
        h = h + 1
    end
    return h
end

--- 获取垂直移动方向 (-1, 0, +1)  手机端返回连续值 (-1 ~ +1)
---@return number
function InputManager:getVertical()
    -- 触摸摇杆优先（手机端）
    if TouchControls.isMobile() and TouchControls.hasMovement() then
        return TouchControls.getVertical()
    end
    -- 键盘输入
    local v = 0
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
        v = v - 1
    end
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
        v = v + 1
    end
    return v
end

--- 是否有任何移动输入
---@return boolean
function InputManager:hasMovement()
    if TouchControls.isMobile() then
        return TouchControls.hasMovement()
    end
    return self:getHorizontal() ~= 0 or self:getVertical() ~= 0
end

-- ============================================================================
-- 速度控制
-- ============================================================================

--- 是否按住减速键 (X)
---@return boolean
function InputManager:isDecelerating()
    return input:GetKeyDown(KEY_X)
end

--- 是否按住加速键 (C)
---@return boolean
function InputManager:isAccelerating()
    return input:GetKeyDown(KEY_C)
end

-- ============================================================================
-- 战斗
-- ============================================================================

--- 是否按住射击键（鼠标左键 / 手机射击按钮）
---@return boolean
function InputManager:isFiring()
    if TouchControls.isMobile() then
        return TouchControls.isFiring()
    end
    return input:GetMouseButtonDown(MOUSEB_LEFT)
end

--- 是否按住护盾键（鼠标右键 / 手机护盾按钮）
---@return boolean
function InputManager:isShielding()
    if TouchControls.isMobile() then
        return TouchControls.isShielding()
    end
    return input:GetMouseButtonDown(MOUSEB_RIGHT)
end

-- ============================================================================
-- 技能
-- ============================================================================

--- 是否按住折跃充能键（空格 / 手机折跃按钮）
---@return boolean
function InputManager:isWarpCharging()
    if TouchControls.isMobile() then
        return TouchControls.isWarpCharging()
    end
    return input:GetKeyDown(KEY_SPACE)
end

--- 是否按下左翻滚键（Q / 手机左翻滚按钮）- 单次触发
---@return boolean
function InputManager:isRollLeftPressed()
    if TouchControls.isMobile() then
        return TouchControls.isRollLeftPressed()
    end
    return input:GetKeyPress(KEY_Q)
end

--- 是否按下右翻滚键（E / 手机右翻滚按钮）- 单次触发
---@return boolean
function InputManager:isRollRightPressed()
    if TouchControls.isMobile() then
        return TouchControls.isRollRightPressed()
    end
    return input:GetKeyPress(KEY_E)
end

return InputManager
