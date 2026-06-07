--[[
Layer 3 - 游戏音频管理
封装主BGM、结局BGM、SFX音效的播放、停止、切换逻辑
事件驱动：通过 EventBus 订阅游戏事件，自行响应
--]]

local GameAudio = {}

-- 内部状态
---@type Scene
local scene_ = nil
---@type ResourceCache
local resourceCache_ = nil
---@type table
local eventBus_ = nil
---@type Node
local bgmNode_ = nil
---@type SoundSource
local bgmSource_ = nil
local bgmEnabled_ = true
---@type Sound
local bgmSound_ = nil

---@type Node
local endingBgmNode_ = nil
---@type SoundSource
local endingBgmSource_ = nil
local endingBgmEnabled_ = true

-- SFX 系统
local sfxEnabled_ = true
---@type Node
local sfxNode_ = nil          -- SFX 共享节点
local sfxSources_ = {}        -- 多通道 SoundSource 池
local sfxPoolSize_ = 12       -- 同时可播放的音效数量
local sfxNextIndex_ = 1       -- 轮询索引

-- 循环音效专用通道（引擎轰鸣等）
---@type Node
local loopNode_ = nil
---@type SoundSource
local engineIdleSource_ = nil
---@type SoundSource
local engineBoostSource_ = nil
---@type SoundSource
local warpLoopSource_ = nil
---@type SoundSource
local shieldLoopSource_ = nil

-- 预加载的音效资源
local sfxSounds_ = {}

-- 结局BGM文件映射
local endingBgmFiles_ = {
    ["最后的希望"] = "BGM/ending_last_hope.ogg",
    ["黑暗森林"]   = "BGM/ending_dark_forest.ogg",
    ["故土尘埃"]   = "BGM/ending_homeland_dust.ogg",
    ["新生"]       = "BGM/ending_new_dawn.ogg",
    ["永恒漂泊"]   = "BGM/ending_eternal_drift.ogg",
}

-- SFX 文件映射（资源路径从 assets/ 根开始）
local sfxFiles_ = {
    laser_fire        = "audio/ogg音效包/激光射击.ogg",
    asteroid_break1   = "audio/ogg音效包/击碎陨石1.ogg",
    asteroid_break2   = "audio/ogg音效包/击碎陨石2.ogg",
    asteroid_hit1     = "audio/ogg音效包/陨石撞击1长.ogg",
    asteroid_hit2     = "audio/ogg音效包/陨石撞击2短.ogg",
    shield_activate   = "audio/ogg音效包/光护盾.ogg",
    shield_loop       = "audio/ogg音效包/护盾5秒1秒消失.ogg",
    shield_block      = "audio/ogg音效包/护盾挡住陨石.ogg",
    roll_light        = "audio/ogg音效包/飞船翻滚1轻.ogg",
    roll_heavy        = "audio/ogg音效包/飞船翻滚2重.ogg",
    warp_charge       = "audio/ogg音效包/飞船跃迁准备，5秒.ogg",
    warp_fly          = "audio/ogg音效包/宇宙飞船 超光速跃迁飞行 星际跃迁_爱给网_aigei_com.ogg",
    warp_end          = "audio/ogg音效包/飞船跃迁结束.ogg",
    engine_idle       = "audio/ogg音效包/默认引擎室轰鸣声.ogg",
    engine_boost      = "audio/ogg音效包/默认飞船加速轰鸣声.ogg",
    crystal_collect   = "audio/ogg音效包/闷闷的闷响 _ 音效_47068_爱给网_aigei_com.ogg",
}

--- 预加载所有音效
local function preloadSounds()
    for key, path in pairs(sfxFiles_) do
        local snd = resourceCache_:GetResource("Sound", path)
        if snd then
            sfxSounds_[key] = snd
        else
            print("[SFX] WARNING: Failed to load " .. path)
        end
    end
    -- 循环音效标记
    if sfxSounds_.engine_idle then sfxSounds_.engine_idle.looped = true end
    if sfxSounds_.engine_boost then sfxSounds_.engine_boost.looped = true end
    if sfxSounds_.warp_fly then sfxSounds_.warp_fly.looped = true end
    if sfxSounds_.shield_loop then sfxSounds_.shield_loop.looped = true end
end

--- 创建 SFX 通道池
local function createSfxPool()
    sfxNode_ = scene_:CreateChild("SFX")
    for i = 1, sfxPoolSize_ do
        local src = sfxNode_:CreateComponent("SoundSource")
        src.soundType = SOUND_EFFECT
        src.gain = 0.6
        sfxSources_[i] = src
    end

    -- 循环音效专用通道
    loopNode_ = scene_:CreateChild("SFX_Loop")

    engineIdleSource_ = loopNode_:CreateComponent("SoundSource")
    engineIdleSource_.soundType = SOUND_EFFECT
    engineIdleSource_.gain = 0.15

    engineBoostSource_ = loopNode_:CreateComponent("SoundSource")
    engineBoostSource_.soundType = SOUND_EFFECT
    engineBoostSource_.gain = 0.0

    warpLoopSource_ = loopNode_:CreateComponent("SoundSource")
    warpLoopSource_.soundType = SOUND_EFFECT
    warpLoopSource_.gain = 0.5

    shieldLoopSource_ = loopNode_:CreateComponent("SoundSource")
    shieldLoopSource_.soundType = SOUND_EFFECT
    shieldLoopSource_.gain = 0.4
end

--- 播放一次性音效（从池中轮询一个通道）
---@param key string 音效键名
---@param gain number|nil 音量（默认0.6）
function GameAudio.playSFX(key, gain)
    if not sfxEnabled_ then return end
    local snd = sfxSounds_[key]
    if not snd then return end

    local src = sfxSources_[sfxNextIndex_]
    src.gain = gain or 0.6
    src:Play(snd)
    sfxNextIndex_ = (sfxNextIndex_ % sfxPoolSize_) + 1
end

--- 播放循环音效到指定通道
---@param source SoundSource
---@param key string
---@param gain number
local function playLoop(source, key, gain)
    if not sfxEnabled_ then return end
    local snd = sfxSounds_[key]
    if not snd or not source then return end
    if not source.playing then
        source:Play(snd)
    end
    source.gain = gain
end

--- 停止循环音效
---@param source SoundSource
local function stopLoop(source)
    if source and source.playing then
        source:Stop()
    end
end

--- 初始化主BGM
---@param scene userdata
---@param resourceCache userdata
---@param eventBus table|nil EventBus 实例（可选，传入后自动订阅事件）
function GameAudio.init(scene, resourceCache, eventBus)
    scene_ = scene
    resourceCache_ = resourceCache
    eventBus_ = eventBus

    -- 预加载 SFX
    preloadSounds()
    createSfxPool()

    -- 主 BGM
    local sound = resourceCache:GetResource("Sound", "BGM/cosmic_drift.ogg")
    if sound == nil then
        print("[BGM] ERROR: Failed to load BGM/cosmic_drift.ogg")
        return
    end
    sound.looped = true

    bgmNode_ = scene:CreateChild("BGM")
    bgmSource_ = bgmNode_:CreateComponent("SoundSource")
    bgmSource_.soundType = SOUND_MUSIC
    bgmSource_.gain = 0.5
    bgmSource_:Play(sound)
    bgmEnabled_ = true
    bgmSound_ = sound

    -- 浏览器自动播放策略：首次交互后恢复音频
    SubscribeToEvent("MouseButtonDown", "HandleAudioResume")
    SubscribeToEvent("TouchBegin", "HandleAudioResume")

    -- 事件订阅：GameAudio 自行响应游戏流程事件
    if eventBus_ then
        eventBus_:on("game_start", function()
            GameAudio.stopEnding()
            GameAudio.muteMainBGM()
            -- 启动引擎音效
            GameAudio.startEngineIdle()
        end)
        eventBus_:on("game_return_menu", function()
            GameAudio.stopEnding()
            GameAudio.resumeMainBGM()
            -- 停止所有循环音效
            GameAudio.stopAllLoops()
        end)

        -- SFX 事件订阅
        eventBus_:on("asteroid_destroyed", function(_pos)
            local key = math.random(1, 2) == 1 and "asteroid_break1" or "asteroid_break2"
            GameAudio.playSFX(key, 0.5)
        end)
        eventBus_:on("ship_hit", function(_lives)
            local key = math.random(1, 2) == 1 and "asteroid_hit1" or "asteroid_hit2"
            GameAudio.playSFX(key, 0.7)
        end)
        eventBus_:on("crystal_collected", function(_energy)
            GameAudio.playSFX("crystal_collect", 0.5)
        end)
        eventBus_:on("shield_activated", function()
            GameAudio.playSFX("shield_activate", 0.6)
            -- 启动护盾循环音效
            playLoop(shieldLoopSource_, "shield_loop", 0.35)
        end)
        eventBus_:on("shield_deactivated", function()
            stopLoop(shieldLoopSource_)
        end)
        eventBus_:on("shield_block", function()
            GameAudio.playSFX("shield_block", 0.6)
        end)
        eventBus_:on("bullet_fired", function()
            GameAudio.playSFX("laser_fire", 0.35)
        end)
        eventBus_:on("roll_start", function(direction)
            local key = direction == -1 and "roll_light" or "roll_heavy"
            GameAudio.playSFX(key, 0.5)
        end)
        eventBus_:on("warp_charging", function()
            GameAudio.playSFX("warp_charge", 0.6)
        end)
        eventBus_:on("warp_begin", function()
            stopLoop(engineIdleSource_)
            stopLoop(engineBoostSource_)
            GameAudio.playSFX("warp_end", 0.0) -- stop any previous
            playLoop(warpLoopSource_, "warp_fly", 0.5)
        end)
        eventBus_:on("warp_end", function()
            stopLoop(warpLoopSource_)
            GameAudio.playSFX("warp_end", 0.6)
            -- 恢复引擎音效
            GameAudio.startEngineIdle()
        end)
        eventBus_:on("game_over", function(_score)
            GameAudio.stopAllLoops()
        end)
    end
end

--- 启动引擎怠速音效
function GameAudio.startEngineIdle()
    playLoop(engineIdleSource_, "engine_idle", 0.15)
    if engineBoostSource_ then engineBoostSource_.gain = 0.0 end
end

--- 更新引擎音效（根据加速状态混合）
---@param isAccelerating boolean
function GameAudio.updateEngine(isAccelerating)
    if not sfxEnabled_ then return end
    if isAccelerating then
        if engineBoostSource_ and not engineBoostSource_.playing and sfxSounds_.engine_boost then
            engineBoostSource_:Play(sfxSounds_.engine_boost)
        end
        if engineBoostSource_ then engineBoostSource_.gain = 0.25 end
        if engineIdleSource_ then engineIdleSource_.gain = 0.05 end
    else
        if engineBoostSource_ then engineBoostSource_.gain = 0.0 end
        if engineIdleSource_ then engineIdleSource_.gain = 0.15 end
    end
end

--- 停止所有循环音效
function GameAudio.stopAllLoops()
    stopLoop(engineIdleSource_)
    stopLoop(engineBoostSource_)
    stopLoop(warpLoopSource_)
    stopLoop(shieldLoopSource_)
end

--- 浏览器首次交互后恢复BGM播放（全局函数，供事件系统调用）
function HandleAudioResume(eventType, eventData)
    if not GameAudio.isInMenu() then return end
    if bgmSource_ and bgmEnabled_ and bgmSound_ then
        bgmSource_:Play(bgmSound_)
        bgmSource_.gain = 0.5
    end
    UnsubscribeFromEvent("MouseButtonDown")
    UnsubscribeFromEvent("TouchBegin")
end

--- 设置菜单状态判断回调
local isInMenuFn_ = nil
function GameAudio.setMenuChecker(fn)
    isInMenuFn_ = fn
end
function GameAudio.isInMenu()
    return isInMenuFn_ and isInMenuFn_() or false
end

--- 切换主BGM开关
---@return boolean 当前启用状态
function GameAudio.toggleBGM()
    if bgmSource_ == nil then return bgmEnabled_ end
    bgmEnabled_ = not bgmEnabled_
    if bgmEnabled_ then
        if not bgmSource_.playing and bgmSound_ then
            bgmSource_:Play(bgmSound_)
        end
        bgmSource_.gain = 0.5
    else
        bgmSource_.gain = 0.0
    end
    return bgmEnabled_
end

--- 获取主BGM启用状态
function GameAudio.isBgmEnabled()
    return bgmEnabled_
end

--- 切换 SFX 开关
---@return boolean 当前启用状态
function GameAudio.toggleSFX()
    sfxEnabled_ = not sfxEnabled_
    if not sfxEnabled_ then
        GameAudio.stopAllLoops()
    end
    return sfxEnabled_
end

--- 获取 SFX 启用状态
function GameAudio.isSfxEnabled()
    return sfxEnabled_
end

--- 恢复主BGM（返回菜单时）
function GameAudio.resumeMainBGM()
    if bgmSource_ and bgmSound_ then
        bgmSource_:Play(bgmSound_)
        bgmSource_.gain = bgmEnabled_ and 0.5 or 0.0
    end
end

--- 静音主BGM（进入游戏时）
function GameAudio.muteMainBGM()
    if bgmSource_ then
        bgmSource_.gain = 0.0
    end
end

--- 播放结局BGM
---@param endingKey string 结局标识
function GameAudio.playEnding(endingKey)
    -- 停止主BGM
    GameAudio.muteMainBGM()
    -- 停止之前的结局BGM
    GameAudio.stopEnding()

    local file = endingBgmFiles_[endingKey]
    if not file then return end

    local sound = resourceCache_:GetResource("Sound", file)
    if sound == nil then
        print("[EndingBGM] Failed to load " .. file)
        return
    end
    sound.looped = false

    endingBgmNode_ = scene_:CreateChild("EndingBGM")
    endingBgmSource_ = endingBgmNode_:CreateComponent("SoundSource")
    endingBgmSource_.soundType = SOUND_MUSIC
    endingBgmSource_.gain = 0.5
    endingBgmSource_:Play(sound)
    endingBgmEnabled_ = true
end

--- 停止结局BGM
function GameAudio.stopEnding()
    if endingBgmSource_ then
        endingBgmSource_:Stop()
        endingBgmSource_ = nil
    end
    if endingBgmNode_ then
        endingBgmNode_:Remove()
        endingBgmNode_ = nil
    end
end

--- 切换结局BGM开关
---@return boolean 当前启用状态
function GameAudio.toggleEndingBGM()
    if endingBgmSource_ == nil then return endingBgmEnabled_ end
    endingBgmEnabled_ = not endingBgmEnabled_
    if endingBgmEnabled_ then
        endingBgmSource_.gain = 0.5
    else
        endingBgmSource_.gain = 0.0
    end
    return endingBgmEnabled_
end

--- 获取结局BGM启用状态
function GameAudio.isEndingBgmEnabled()
    return endingBgmEnabled_
end

return GameAudio
