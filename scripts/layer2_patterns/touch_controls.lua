--[[
Layer 2 - 可复用模式层：触摸控制管理
职责：在手机端创建虚拟摇杆和操作按钮，提供统一输入状态查询
设计：
  - 左侧虚拟摇杆 → 移动
  - 右下区域按钮 → 射击、护盾、折跃
  - 左下区域按钮 → 翻滚 (Q/E)
  - 自动检测平台，桌面端不创建任何控件
--]]

local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
require "urhox-libs.UI.VirtualControls"

local TouchControls = {}

-- 内部状态
local initialized_ = false
local isMobile_ = false

-- 摇杆引用
local joystick_ = nil

-- 按钮引用
local fireBtn_ = nil
local shieldBtn_ = nil
local warpBtn_ = nil
local rollLeftBtn_ = nil
local rollRightBtn_ = nil

-- 按钮状态（供 InputManager 查询）
local firePressed_ = false
local shieldPressed_ = false
local warpPressed_ = false
local rollLeftJustPressed_ = false
local rollRightJustPressed_ = false

-- 每帧重置的单次触发标记
local rollLeftConsumed_ = false
local rollRightConsumed_ = false

--- 初始化触摸控制（在 Start() 中调用）
function TouchControls.init()
    isMobile_ = PlatformUtils.IsTouchSupported()

    if not isMobile_ then
        initialized_ = true
        return
    end

    VirtualControls.Initialize()

    -- ====== 左侧虚拟摇杆（移动） ======
    joystick_ = VirtualControls.CreateJoystick({
        position = Vector2(170, -200),
        alignment = { HA_LEFT, VA_BOTTOM },
        baseRadius = 110,
        knobRadius = 44,
        moveRadius = 70,
        deadZone = 0.1,
        isPressCenter = true,
        pressRegionRadius = 220,
        opacity = 0.75,
    })

    -- ====== 右侧按钮区 ======

    -- 射击按钮（主按钮，右下角最大）
    fireBtn_ = VirtualControls.CreateButton({
        position = Vector2(-110, -130),
        alignment = { HA_RIGHT, VA_BOTTOM },
        radius = 70,
        label = "开火",
        color = { 255, 80, 60 },
        alwaysShow = true,
        opacity = 0.85,
        on_press = function()
            firePressed_ = true
        end,
        on_release = function()
            firePressed_ = false
        end,
    })

    -- 护盾按钮（射击按钮左侧）
    shieldBtn_ = VirtualControls.CreateButton({
        position = Vector2(-260, -130),
        alignment = { HA_RIGHT, VA_BOTTOM },
        radius = 58,
        label = "护盾",
        color = { 60, 180, 255 },
        alwaysShow = true,
        opacity = 0.8,
        on_press = function()
            shieldPressed_ = true
        end,
        on_release = function()
            shieldPressed_ = false
        end,
    })

    -- 折跃按钮（射击按钮上方）
    warpBtn_ = VirtualControls.CreateButton({
        position = Vector2(-110, -290),
        alignment = { HA_RIGHT, VA_BOTTOM },
        radius = 54,
        label = "折跃",
        color = { 160, 80, 255 },
        alwaysShow = true,
        opacity = 0.8,
        on_press = function()
            warpPressed_ = true
        end,
        on_release = function()
            warpPressed_ = false
        end,
    })

    -- ====== 左侧翻滚按钮 ======

    -- 左翻滚（摇杆上方左侧）
    rollLeftBtn_ = VirtualControls.CreateButton({
        position = Vector2(80, -360),
        alignment = { HA_LEFT, VA_BOTTOM },
        radius = 48,
        label = "◀左滚",
        color = { 255, 180, 40 },
        alwaysShow = true,
        opacity = 0.75,
        on_press = function()
            rollLeftJustPressed_ = true
            rollLeftConsumed_ = false
        end,
    })

    -- 右翻滚（摇杆上方右侧）
    rollRightBtn_ = VirtualControls.CreateButton({
        position = Vector2(250, -360),
        alignment = { HA_LEFT, VA_BOTTOM },
        radius = 48,
        label = "右滚▶",
        color = { 40, 255, 160 },
        alwaysShow = true,
        opacity = 0.75,
        on_press = function()
            rollRightJustPressed_ = true
            rollRightConsumed_ = false
        end,
    })

    initialized_ = true
    print("[TouchControls] Initialized (mobile mode)")
end

--- 是否处于手机模式
---@return boolean
function TouchControls.isMobile()
    return isMobile_
end

--- 获取摇杆水平输入 (-1 ~ +1)
---@return number
function TouchControls.getHorizontal()
    if not joystick_ then return 0 end
    local x, _ = joystick_:getInput()
    return x
end

--- 获取摇杆垂直输入 (-1 ~ +1, 上为正)
---@return number
function TouchControls.getVertical()
    if not joystick_ then return 0 end
    local _, y = joystick_:getInput()
    -- VirtualControls 的 y 轴：向下为正，需要反转
    return -y
end

--- 是否有移动输入
---@return boolean
function TouchControls.hasMovement()
    if not joystick_ then return false end
    return joystick_.magnitude > 0.01
end

--- 是否按住射击
---@return boolean
function TouchControls.isFiring()
    return firePressed_
end

--- 是否按住护盾
---@return boolean
function TouchControls.isShielding()
    return shieldPressed_
end

--- 是否按住折跃充能
---@return boolean
function TouchControls.isWarpCharging()
    return warpPressed_
end

--- 左翻滚是否刚按下（单次触发，消费后重置）
---@return boolean
function TouchControls.isRollLeftPressed()
    if rollLeftJustPressed_ and not rollLeftConsumed_ then
        rollLeftConsumed_ = true
        rollLeftJustPressed_ = false
        return true
    end
    return false
end

--- 右翻滚是否刚按下（单次触发，消费后重置）
---@return boolean
function TouchControls.isRollRightPressed()
    if rollRightJustPressed_ and not rollRightConsumed_ then
        rollRightConsumed_ = true
        rollRightJustPressed_ = false
        return true
    end
    return false
end

--- 设置控件可见性（游戏中显示，菜单/结局隐藏）
---@param visible boolean
function TouchControls.setVisible(visible)
    if not isMobile_ then return end

    -- VirtualJoystick 通过 visible 属性 + _updateShouldShow() 控制
    if joystick_ then
        joystick_.visible = visible
        joystick_:_updateShouldShow()
    end

    -- VirtualButton 在移动端 _updateShouldShow() 强制 _shouldShow=true
    -- 因此直接设置 _shouldShow 来控制显隐
    local buttons = { fireBtn_, shieldBtn_, warpBtn_, rollLeftBtn_, rollRightBtn_ }
    for _, btn in ipairs(buttons) do
        if btn then
            btn._shouldShow = visible
        end
    end

    -- 隐藏时重置所有按钮状态，避免残留输入
    if not visible then
        firePressed_ = false
        shieldPressed_ = false
        warpPressed_ = false
        rollLeftJustPressed_ = false
        rollRightJustPressed_ = false
    end
end

return TouchControls
