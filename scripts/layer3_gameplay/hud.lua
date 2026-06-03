--[[
Layer 3 - 游戏逻辑层：HUD 更新模块
职责：游戏中 HUD 控件数据更新 + NanoVG 充能圆环渲染
依赖：UI 控件引用通过 setWidgets() 注入，gs/Weapons 通过 update() 参数传入
--]]

local math_floor = math.floor
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local math_pi = math.pi

local M = {}

-- UI 控件引用
local scoreLabel_
local livesLabel_
local speedLabel_
local speedUnit_
local speedBar_
local heatLabel_
local heatBar_
local shieldLabel_
local warpLabel_
local warpBar_
local warpStatus_
local warpCountLabel_
local rollLeftLabel_
local rollRightLabel_
local rollLeftIcon_
local rollLeftPanel_
local rollRightIcon_
local rollRightPanel_

-- 脏标记缓存（避免每帧重复设置）
local hudState_ = {
    speedMode = "",
    speedBarMode = "",
    heatMode = "",
    shieldMode = "",
    warpMode = "",
    warpBarMode = "",
    lastCountSec = 0,
    lastWarpEnergy = -1,
    lastWarpBarVal = -1,
}

-- NanoVG 上下文
local vg_ = nil

--- 注入 UI 控件引用
---@param refs table ShowPlayingUI 返回的控件引用表
function M.setWidgets(refs)
    scoreLabel_ = refs.scoreLabel
    livesLabel_ = refs.livesLabel
    speedLabel_ = refs.speedLabel
    speedUnit_ = refs.speedUnit
    speedBar_ = refs.speedBar
    heatLabel_ = refs.heatLabel
    heatBar_ = refs.heatBar
    shieldLabel_ = refs.shieldLabel
    warpLabel_ = refs.warpLabel
    warpBar_ = refs.warpBar
    warpStatus_ = refs.warpStatus
    warpCountLabel_ = refs.warpCountLabel
    rollLeftLabel_ = refs.rollLeftLabel
    rollRightLabel_ = refs.rollRightLabel
    rollLeftIcon_ = refs.rollLeftIcon
    rollLeftPanel_ = refs.rollLeftPanel
    rollRightIcon_ = refs.rollRightIcon
    rollRightPanel_ = refs.rollRightPanel
end

--- 设置 NanoVG 上下文
function M.setNanoVG(nvgCtx)
    vg_ = nvgCtx
end

--- 重置脏标记（切换状态时调用）
function M.resetCache()
    hudState_.speedMode = ""
    hudState_.speedBarMode = ""
    hudState_.heatMode = ""
    hudState_.shieldMode = ""
    hudState_.warpMode = ""
    hudState_.warpBarMode = ""
    hudState_.lastCountSec = 0
    hudState_.lastWarpEnergy = -1
    hudState_.lastWarpBarVal = -1
end

--- 更新 HUD 显示
---@param gs table 游戏状态
---@param Weapons table 武器模块（获取热量数据）
function M.update(gs, Weapons)
    -- 得分
    if scoreLabel_ then
        scoreLabel_:SetText(string.format("得分: %d", gs.score))
    end

    -- 生命
    if livesLabel_ then
        local icons = ""
        for i = 1, gs.lives do icons = icons .. "✈" end
        for i = gs.lives + 1, 5 do icons = icons .. "✧" end
        livesLabel_:SetText(icons)
    end

    -- === 速度仪表 ===
    if speedLabel_ then
        speedLabel_:SetText(string.format("%.0f", gs.speed))
        local sMode = gs.warpActive and "warp" or "normal"
        if hudState_.speedMode ~= sMode then
            hudState_.speedMode = sMode
            if sMode == "warp" then
                speedLabel_:SetFontColor({ 255, 200, 80, 255 })
                speedUnit_:SetText("WARP!")
                speedUnit_:SetFontColor({ 255, 180, 50, 220 })
            else
                speedLabel_:SetFontColor({ 200, 240, 255, 255 })
                speedUnit_:SetText("um/s")
                speedUnit_:SetFontColor({ 120, 160, 200, 180 })
            end
        end
    end
    if speedBar_ then
        speedBar_:SetValue(gs.speed / gs.warpSpeed)
        local sbMode = gs.warpActive and "warp" or (gs.speed > gs.maxSpeed * 0.8 and "high" or "normal")
        if hudState_.speedBarMode ~= sbMode then
            hudState_.speedBarMode = sbMode
            if sbMode == "warp" then
                speedBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 255, 180, 50, 255 }, to = { 255, 100, 30, 255 } } })
            elseif sbMode == "high" then
                speedBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 100, 200, 255, 255 }, to = { 255, 200, 100, 255 } } })
            else
                speedBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 60, 180, 255, 255 }, to = { 120, 255, 200, 255 } } })
            end
        end
    end

    -- === 热量仪表 ===
    local heat_ = Weapons.getHeat()
    local overheated_ = Weapons.isOverheated()
    local overheatTimer_ = Weapons.getOverheatTimer()
    local heatMax_ = Weapons.getHeatMax()
    if heatLabel_ then
        if overheated_ then
            heatLabel_:SetText(string.format("%.0fs", overheatTimer_))
            if hudState_.heatMode ~= "overheated" then
                hudState_.heatMode = "overheated"
                heatLabel_:SetFontColor({ 255, 60, 60, 255 })
            end
        else
            heatLabel_:SetText(string.format("%d%%", math_floor(heat_)))
            local hm = heat_ > 70 and "high" or "normal"
            if hudState_.heatMode ~= hm then
                hudState_.heatMode = hm
                if hm == "high" then
                    heatLabel_:SetFontColor({ 255, 150, 50, 255 })
                else
                    heatLabel_:SetFontColor({ 100, 255, 100, 255 })
                end
            end
        end
    end
    if heatBar_ then
        heatBar_:SetValue(heat_ / heatMax_)
        local hbMode = overheated_ and "overheated" or (heat_ > 70 and "high" or "normal")
        if hudState_.heatMode ~= hbMode then
            if hbMode == "overheated" then
                heatBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 255, 60, 60, 255 }, to = { 255, 30, 30, 255 } } })
            elseif hbMode == "high" then
                heatBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 255, 180, 50, 255 }, to = { 255, 80, 30, 255 } } })
            else
                heatBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 80, 200, 80, 255 }, to = { 255, 200, 50, 255 } } })
            end
        end
    end

    -- === 护盾状态 ===
    if shieldLabel_ then
        local sm = gs.shieldActive and "active" or (gs.shieldCoolTimer > 0 and "cooldown" or "ready")
        if gs.shieldActive then
            shieldLabel_:SetText(string.format("%.1fs", gs.shieldTimer))
        elseif gs.shieldCoolTimer > 0 then
            shieldLabel_:SetText(string.format("%.0fs", gs.shieldCoolTimer))
        else
            shieldLabel_:SetText("就绪")
        end
        if hudState_.shieldMode ~= sm then
            hudState_.shieldMode = sm
            if sm == "active" then
                shieldLabel_:SetFontColor({ 80, 240, 255, 255 })
            elseif sm == "cooldown" then
                shieldLabel_:SetFontColor({ 80, 80, 100, 160 })
            else
                shieldLabel_:SetFontColor({ 80, 200, 255, 220 })
            end
        end
    end

    -- === 折跃仪表 ===
    if warpLabel_ then
        local wm = gs.warpActive and "warping" or (gs.warpCharging and "charging" or (gs.warpEnergy >= gs.warpMaxEnergy and "ready" or "idle"))
        if hudState_.warpMode ~= wm then
            hudState_.warpMode = wm
            if wm == "warping" then
                warpLabel_:SetText("WARPING")
                warpLabel_:SetFontColor({ 255, 200, 50, 255 })
            elseif wm == "charging" then
                warpLabel_:SetText("CHARGING")
                warpLabel_:SetFontColor({ 255, 150, 255, 255 })
            elseif wm == "ready" then
                warpLabel_:SetText("READY")
                warpLabel_:SetFontColor({ 150, 255, 150, 255 })
            else
                warpLabel_:SetText("WARP")
                warpLabel_:SetFontColor({ 160, 130, 220, 200 })
            end
        end
    end

    -- 屏幕中央蓄能倒计时（仅秒数变化时更新）
    if warpCountLabel_ then
        if gs.warpCharging then
            local sec = math_ceil(gs.warpChargeTimer)
            if sec < 1 then sec = 1 end
            if hudState_.lastCountSec ~= sec then
                hudState_.lastCountSec = sec
                warpCountLabel_:SetText(tostring(sec))
            end
        elseif hudState_.lastCountSec ~= 0 then
            hudState_.lastCountSec = 0
            warpCountLabel_:SetText("")
        end
    end

    if warpStatus_ then
        if hudState_.lastWarpEnergy ~= gs.warpEnergy then
            hudState_.lastWarpEnergy = gs.warpEnergy
            local filled = string.rep("◆", gs.warpEnergy)
            local empty = string.rep("◇", gs.warpMaxEnergy - gs.warpEnergy)
            warpStatus_:SetText(filled .. empty)
        end
    end

    if warpBar_ then
        local wbMode = gs.warpActive and "warp" or (gs.warpCharging and "charge" or "normal")
        if gs.warpActive then
            local val = math_floor(gs.warpTimer / gs.warpDuration * 50) / 50
            if hudState_.lastWarpBarVal ~= val then
                hudState_.lastWarpBarVal = val
                warpBar_:SetValue(val)
            end
        elseif gs.warpCharging then
            -- 充能期间进度由 NanoVG 圆环展示，不更新进度条
        else
            local val = math_floor(gs.warpEnergy / gs.warpMaxEnergy * 50) / 50
            if hudState_.lastWarpBarVal ~= val then
                hudState_.lastWarpBarVal = val
                warpBar_:SetValue(val)
            end
        end
        if hudState_.warpBarMode ~= wbMode then
            hudState_.warpBarMode = wbMode
            if wbMode == "warp" then
                warpBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 255, 200, 50, 255 }, to = { 255, 120, 20, 255 } } })
            elseif wbMode == "charge" then
                warpBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 200, 100, 255, 255 }, to = { 255, 180, 255, 255 } } })
            else
                warpBar_:SetStyle({ fillGradient = { direction = "to-right", from = { 140, 80, 255, 255 }, to = { 220, 150, 255, 255 } } })
            end
        end
    end

    -- === 翻滚技能 CD 显示 ===
    if rollLeftLabel_ then
        if gs.rollCdLeftTimer > 0 then
            rollLeftLabel_:SetText(string.format("%.1f", gs.rollCdLeftTimer))
            rollLeftLabel_:SetFontColor({ 120, 120, 140, 180 })
            if rollLeftPanel_ then rollLeftPanel_:SetBorderColor({ 220, 60, 60, 200 }) end
            if rollLeftIcon_ then rollLeftIcon_:SetFontColor({ 220, 60, 60, 200 }) end
        else
            rollLeftLabel_:SetText("Q")
            rollLeftLabel_:SetFontColor({ 200, 200, 200, 255 })
            if rollLeftPanel_ then rollLeftPanel_:SetBorderColor({ 60, 140, 255, 200 }) end
            if rollLeftIcon_ then rollLeftIcon_:SetFontColor({ 60, 140, 255, 200 }) end
        end
    end
    if rollRightLabel_ then
        if gs.rollCdRightTimer > 0 then
            rollRightLabel_:SetText(string.format("%.1f", gs.rollCdRightTimer))
            rollRightLabel_:SetFontColor({ 120, 120, 140, 180 })
            if rollRightPanel_ then rollRightPanel_:SetBorderColor({ 220, 60, 60, 200 }) end
            if rollRightIcon_ then rollRightIcon_:SetFontColor({ 220, 60, 60, 200 }) end
        else
            rollRightLabel_:SetText("E")
            rollRightLabel_:SetFontColor({ 200, 200, 200, 255 })
            if rollRightPanel_ then rollRightPanel_:SetBorderColor({ 60, 140, 255, 200 }) end
            if rollRightIcon_ then rollRightIcon_:SetFontColor({ 60, 140, 255, 200 }) end
        end
    end
end

--- NanoVG 渲染：折跃充能圆环
---@param gs table 游戏状态
function M.renderChargeRing(gs)
    if not vg_ then return end
    if not gs.warpCharging then return end

    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    nvgBeginFrame(vg_, w, h, 1.0)

    -- 圆环参数（与倒计时文字位置对齐）
    local cx = w * 0.5
    local cy = h * 0.38 + 60 * dpr
    local radius = 52 * dpr
    local lineWidth = 5 * dpr

    -- 充能进度（0→1）
    local progress = 1.0 - (gs.warpChargeTimer / gs.warpChargeTime)
    progress = math_max(0, math_min(1, progress))

    -- 起始角度：12 点钟方向（-PI/2），顺时针填充
    local startAngle = -math_pi / 2
    local endAngle = startAngle + progress * math_pi * 2

    -- 底层轨道（暗色）
    nvgBeginPath(vg_)
    nvgArc(vg_, cx, cy, radius, 0, math_pi * 2, NVG_CW)
    nvgStrokeColor(vg_, nvgRGBA(255, 255, 255, 40))
    nvgStrokeWidth(vg_, lineWidth)
    nvgStroke(vg_)

    -- 前景进度弧
    if progress > 0.001 then
        nvgBeginPath(vg_)
        nvgArc(vg_, cx, cy, radius, startAngle, endAngle, NVG_CW)
        nvgStrokeColor(vg_, nvgRGBA(255, 255, 255, 220))
        nvgStrokeWidth(vg_, lineWidth)
        nvgLineCap(vg_, NVG_ROUND)
        nvgStroke(vg_)
    end

    nvgEndFrame(vg_)
end

return M
