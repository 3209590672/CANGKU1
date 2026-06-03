--[[
Layer 3 - 游戏音频管理
封装主BGM和结局BGM的播放、停止、切换逻辑
--]]

local GameAudio = {}

-- 内部状态
local scene_ = nil
local resourceCache_ = nil
local bgmNode_ = nil
local bgmSource_ = nil
local bgmEnabled_ = true
local bgmSound_ = nil

local endingBgmNode_ = nil
local endingBgmSource_ = nil
local endingBgmEnabled_ = true

-- 结局BGM文件映射
local endingBgmFiles_ = {
    ["最后的希望"] = "BGM/ending_last_hope.ogg",
    ["黑暗森林"]   = "BGM/ending_dark_forest.ogg",
    ["故土尘埃"]   = "BGM/ending_homeland_dust.ogg",
    ["新生"]       = "BGM/ending_new_dawn.ogg",
    ["永恒漂泊"]   = "BGM/ending_eternal_drift.ogg",
}

--- 初始化主BGM
---@param scene userdata
---@param resourceCache userdata
function GameAudio.init(scene, resourceCache)
    scene_ = scene
    resourceCache_ = resourceCache
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
