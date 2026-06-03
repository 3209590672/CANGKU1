--[[
Layer 2 - 可复用模式层：音频管理器
封装BGM播放/停止/切换逻辑，支持多轨道（主BGM + 结局BGM）
--]]

local AudioManager = {}
AudioManager.__index = AudioManager

--- 创建音频管理器
---@param scene userdata UrhoX Scene
---@return table AudioManager实例
function AudioManager.new(scene)
    local self = setmetatable({}, AudioManager)
    self._scene = scene
    self._tracks = {}   -- { trackName = { node, source, sound, enabled, gain } }
    return self
end

--- 加载并播放一个音轨
---@param trackName string 音轨标识（如 "main", "ending"）
---@param file string 音频文件路径
---@param options table|nil { loop=bool, gain=number }
---@return boolean 是否成功
function AudioManager:play(trackName, file, options)
    options = options or {}
    local loop = options.loop ~= false  -- 默认循环
    local gain = options.gain or 0.5

    local sound = cache:GetResource("Sound", file)
    if sound == nil then
        print("[AudioManager] ERROR: Failed to load " .. file)
        return false
    end
    sound.looped = loop

    -- 停止同名音轨
    self:stop(trackName)

    local node = self._scene:CreateChild("Audio_" .. trackName)
    local source = node:CreateComponent("SoundSource")
    source.soundType = SOUND_MUSIC
    source.gain = gain
    source:Play(sound)

    self._tracks[trackName] = {
        node    = node,
        source  = source,
        sound   = sound,
        enabled = true,
        gain    = gain,
    }
    return true
end

--- 停止音轨
---@param trackName string
function AudioManager:stop(trackName)
    local track = self._tracks[trackName]
    if not track then return end
    if track.source then
        track.source:Stop()
    end
    if track.node then
        track.node:Remove()
    end
    self._tracks[trackName] = nil
end

--- 切换音轨开关（静音/恢复）
---@param trackName string
---@return boolean 当前是否启用
function AudioManager:toggle(trackName)
    local track = self._tracks[trackName]
    if not track then return false end
    track.enabled = not track.enabled
    if track.enabled then
        -- 恢复播放
        if not track.source.playing and track.sound then
            track.source:Play(track.sound)
        end
        track.source.gain = track.gain
    else
        track.source.gain = 0.0
    end
    return track.enabled
end

--- 设置音量
---@param trackName string
---@param gain number 0.0~1.0
function AudioManager:setGain(trackName, gain)
    local track = self._tracks[trackName]
    if not track then return end
    track.gain = gain
    if track.enabled then
        track.source.gain = gain
    end
end

--- 静音某音轨（不销毁）
---@param trackName string
function AudioManager:mute(trackName)
    local track = self._tracks[trackName]
    if not track then return end
    track.source.gain = 0.0
end

--- 恢复音量
---@param trackName string
function AudioManager:unmute(trackName)
    local track = self._tracks[trackName]
    if not track then return end
    if track.enabled then
        track.source.gain = track.gain
    end
end

--- 查询音轨是否启用
---@param trackName string
---@return boolean
function AudioManager:isEnabled(trackName)
    local track = self._tracks[trackName]
    return track ~= nil and track.enabled
end

--- 查询音轨是否存在
---@param trackName string
---@return boolean
function AudioManager:has(trackName)
    return self._tracks[trackName] ~= nil
end

--- 尝试恢复播放（用于浏览器自动播放策略）
---@param trackName string
function AudioManager:resume(trackName)
    local track = self._tracks[trackName]
    if not track then return end
    if track.enabled and track.sound then
        track.source:Play(track.sound)
        track.source.gain = track.gain
    end
end

--- 停止所有音轨
function AudioManager:stopAll()
    for name, _ in pairs(self._tracks) do
        self:stop(name)
    end
end

return AudioManager
