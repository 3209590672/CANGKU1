--[[
Layer 1 - 基础框架层：事件总线
零游戏依赖，可跨项目移植

用法：
    local EventBus = require("layer1_framework/event_bus")
    local bus = EventBus.new()
    
    local id = bus:on("score_changed", function(newScore) ... end)
    bus:emit("score_changed", 1500)
    bus:off("score_changed", id)
--]]

local EventBus = {}
EventBus.__index = EventBus

local _nextId = 0

--- 创建新的事件总线
---@return table EventBus实例
function EventBus.new()
    local self = setmetatable({}, EventBus)
    self._listeners = {}    -- { eventName = { {id=n, cb=fn}, ... } }
    return self
end

--- 注册事件监听
---@param event string 事件名
---@param callback function 回调函数
---@return number 监听器ID（用于 off 取消）
function EventBus:on(event, callback)
    if not self._listeners[event] then
        self._listeners[event] = {}
    end
    _nextId = _nextId + 1
    table.insert(self._listeners[event], { id = _nextId, cb = callback })
    return _nextId
end

--- 注册一次性事件监听（触发一次后自动移除）
---@param event string
---@param callback function
---@return number
function EventBus:once(event, callback)
    local id
    id = self:on(event, function(...)
        self:off(event, id)
        callback(...)
    end)
    return id
end

--- 取消事件监听
---@param event string
---@param listenerId number
function EventBus:off(event, listenerId)
    local list = self._listeners[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].id == listenerId then
            table.remove(list, i)
            return
        end
    end
end

--- 发射事件
---@param event string
---@param ... any 传递给回调的参数
function EventBus:emit(event, ...)
    local list = self._listeners[event]
    if not list then return end
    -- 遍历副本以防止回调内修改列表
    local snapshot = {}
    for i = 1, #list do
        snapshot[i] = list[i]
    end
    for _, listener in ipairs(snapshot) do
        listener.cb(...)
    end
end

--- 移除某事件的所有监听器
---@param event string|nil 如果为nil则清空所有
function EventBus:clear(event)
    if event then
        self._listeners[event] = nil
    else
        self._listeners = {}
    end
end

--- 获取某事件的监听器数量
---@param event string
---@return number
function EventBus:count(event)
    local list = self._listeners[event]
    return list and #list or 0
end

return EventBus
