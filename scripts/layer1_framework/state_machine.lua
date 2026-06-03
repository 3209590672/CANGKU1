--[[
Layer 1 - 基础框架层：泛型有限状态机 (FSM)
零游戏依赖，可跨项目移植

用法：
    local FSM = require("layer1_framework/state_machine")
    local sm = FSM.new({ "menu", "playing", "gameover" })
    sm:on("enter_playing", function(from) ... end)
    sm:on("exit_menu", function(to) ... end)
    sm:on("transition", function(from, to) ... end)
    sm:go("playing")
--]]

local FSM = {}
FSM.__index = FSM

--- 创建新的状态机
---@param states table 状态名称列表，如 { "menu", "playing", "gameover" }
---@param initial string|nil 初始状态（默认为第一个）
---@return table FSM实例
function FSM.new(states, initial)
    local self = setmetatable({}, FSM)
    self._states = {}
    for _, s in ipairs(states) do
        self._states[s] = true
    end
    self._current = initial or states[1]
    self._listeners = {}
    return self
end

--- 获取当前状态
---@return string
function FSM:current()
    return self._current
end

--- 判断是否处于某状态
---@param state string
---@return boolean
function FSM:is(state)
    return self._current == state
end

--- 注册事件监听
--- 支持的事件：
---   "enter_<state>"   进入某状态时触发，参数(fromState)
---   "exit_<state>"    离开某状态时触发，参数(toState)
---   "transition"      任意状态切换时触发，参数(fromState, toState)
---@param event string
---@param callback function
function FSM:on(event, callback)
    if not self._listeners[event] then
        self._listeners[event] = {}
    end
    table.insert(self._listeners[event], callback)
end

--- 移除事件监听
---@param event string
---@param callback function|nil 如果为nil则移除该事件所有监听
function FSM:off(event, callback)
    if not callback then
        self._listeners[event] = nil
        return
    end
    local list = self._listeners[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == callback then
            table.remove(list, i)
        end
    end
end

--- 触发事件（内部用）
local function emit(self, event, ...)
    local list = self._listeners[event]
    if not list then return end
    for _, cb in ipairs(list) do
        cb(...)
    end
end

--- 切换状态
---@param newState string
---@return boolean 是否切换成功
function FSM:go(newState)
    if not self._states[newState] then
        print("[FSM] WARNING: Invalid state '" .. tostring(newState) .. "'")
        return false
    end
    if self._current == newState then
        return false
    end

    local oldState = self._current
    -- exit 回调
    emit(self, "exit_" .. oldState, newState)
    -- 切换
    self._current = newState
    -- enter 回调
    emit(self, "enter_" .. newState, oldState)
    -- 通用 transition 回调
    emit(self, "transition", oldState, newState)
    return true
end

--- 强制设置状态（不触发回调，用于初始化）
---@param state string
function FSM:set(state)
    if self._states[state] then
        self._current = state
    end
end

return FSM
