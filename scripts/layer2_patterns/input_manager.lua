--[[
Layer 2 - 可复用模式层：输入管理器
封装键盘/鼠标输入状态查询，提供统一接口
--]]

local InputManager = {}
InputManager.__index = InputManager

--- 创建输入管理器
---@return table InputManager实例
function InputManager.new()
    local self = setmetatable({}, InputManager)
    return self
end

--- 获取水平移动方向 (-1, 0, +1)
---@return number
function InputManager:getHorizontal()
    local h = 0
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then
        h = h - 1
    end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then
        h = h + 1
    end
    return h
end

--- 获取垂直移动方向 (-1, 0, +1)
---@return number
function InputManager:getVertical()
    local v = 0
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
        v = v - 1
    end
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
        v = v + 1
    end
    return v
end

--- 是否按住减速键
---@return boolean
function InputManager:isBraking()
    return input:GetKeyDown(KEY_LSHIFT) or input:GetKeyDown(KEY_RSHIFT)
end

--- 是否按住射击键（左键）
---@return boolean
function InputManager:isFiring()
    return input:GetMouseButtonDown(MOUSEB_LEFT)
end

--- 是否按住护盾键（右键）
---@return boolean
function InputManager:isShielding()
    return input:GetMouseButtonDown(MOUSEB_RIGHT)
end

--- 是否按住折跃充能键（空格）
---@return boolean
function InputManager:isWarpCharging()
    return input:GetKeyDown(KEY_SPACE)
end

--- 是否按下左翻滚键（Q）
---@return boolean
function InputManager:isRollLeftPressed()
    return input:GetKeyPress(KEY_Q)
end

--- 是否按下右翻滚键（E）
---@return boolean
function InputManager:isRollRightPressed()
    return input:GetKeyPress(KEY_E)
end

--- 是否有任何移动输入
---@return boolean
function InputManager:hasMovement()
    return self:getHorizontal() ~= 0 or self:getVertical() ~= 0
end

return InputManager
