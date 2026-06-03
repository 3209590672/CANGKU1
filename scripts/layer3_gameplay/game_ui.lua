-- ============================================================================
-- Layer3: 游戏 UI 界面（菜单、游戏中仪表盘、结算、剧情选择/结局）
-- 职责：纯 UI 构建与布局，通过 ctx 注入游戏状态和回调
-- ============================================================================

local UI = require("urhox-libs/UI")

local math_floor = math.floor
local table_insert = table.insert

local GameUI = {}

-- ============================================================================
-- 菜单界面
-- ============================================================================

--- 显示主菜单
--- @param ctx table { bgmEnabled, onStart, onToggleBGM }
--- @return table refs { menuStartLabel, menuStartBtn, menuMusicBtn }
function GameUI.showMenu(ctx)
    local menuStartLabel = UI.Label {
        text = "START",
        fontSize = 22,
        fontColor = { 120, 220, 255, 255 },
        textAlign = "center",
        letterSpacing = 4,
    }
    local menuStartBtn = UI.Panel {
        width = 200,
        height = 52,
        backgroundColor = { 10, 30, 60, 180 },
        borderRadius = 12,
        borderWidth = 2,
        borderColor = { 80, 200, 255, 200 },
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "auto",
        onClick = function() ctx.onStart() end,
        children = { menuStartLabel },
    }

    local menuChildren = {}
    -- 标题图片
    table_insert(menuChildren, UI.Panel {
        position = "absolute",
        top = "5%",
        left = 0,
        width = "100%",
        height = "25%",
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = "45%",
                height = "100%",
                backgroundImage = "image/标题.png",
                backgroundFit = "contain",
            },
        },
    })

    -- 渐变蒙版
    for step = 0, 24 do
        local pct = 75 + step
        local alpha = math_floor(step * (255 / 25))
        table_insert(menuChildren, UI.Panel {
            position = "absolute",
            top = pct .. "%",
            left = 0,
            width = "100%",
            height = "1%",
            backgroundColor = { 5, 5, 20, alpha },
        })
    end

    -- START 按钮
    table_insert(menuChildren, UI.Panel {
        position = "absolute",
        top = "75%",
        left = 0,
        width = "100%",
        alignItems = "center",
        children = { menuStartBtn },
    })

    -- 底部操作提示
    table_insert(menuChildren, UI.Panel {
        position = "absolute",
        bottom = 30,
        left = 0,
        width = "100%",
        alignItems = "center",
        children = {
            UI.Label {
                text = "WASD/方向键 移动 | Shift 减速 | 收集5水晶+长按空格 折跃",
                fontSize = 13,
                fontColor = { 160, 160, 170, 150 },
                marginBottom = 6,
            },
            UI.Label {
                text = "左键 射击 | 右键 护盾",
                fontSize = 13,
                fontColor = { 160, 160, 170, 150 },
            },
        },
    })

    -- 音乐按钮
    local menuMusicBtn = UI.Label {
        id = "musicBtn",
        text = ctx.bgmEnabled and "🔊" or "🔇",
        fontSize = 22,
        fontColor = ctx.bgmEnabled and { 120, 220, 255, 220 } or { 120, 120, 140, 150 },
        textAlign = "center",
    }
    table_insert(menuChildren, UI.Panel {
        position = "absolute",
        top = 16,
        left = 16,
        width = 44,
        height = 44,
        backgroundColor = { 10, 30, 60, 160 },
        borderRadius = 22,
        borderWidth = 1,
        borderColor = { 80, 200, 255, 120 },
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "auto",
        onClick = function() ctx.onToggleBGM() end,
        children = { menuMusicBtn },
    })

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        children = menuChildren,
    }
    UI.SetRoot(root)

    return {
        menuStartLabel = menuStartLabel,
        menuStartBtn = menuStartBtn,
        menuMusicBtn = menuMusicBtn,
    }
end

-- ============================================================================
-- 游戏中仪表盘
-- ============================================================================

--- 显示游戏中 HUD
--- @param ctx table { warpSpeed }
--- @return table refs { scoreLabel, livesLabel, speedLabel, speedUnit, speedBar, heatLabel, heatBar, shieldLabel, warpLabel, warpBar, warpStatus, warpCountLabel, rollLeftLabel, rollRightLabel, rollLeftIcon, rollLeftPanel, rollRightIcon, rollRightPanel }
function GameUI.showPlaying(ctx)
    local scoreLabel = UI.Label {
        text = "得分: 0",
        fontSize = 18,
        fontColor = { 255, 220, 100, 255 },
    }
    local livesLabel = UI.Label {
        text = "✈✈✈✈✈",
        fontSize = 18,
        fontColor = { 180, 210, 240, 255 },
    }

    -- 速度仪表
    local speedLabel = UI.Label {
        text = "20",
        fontSize = 26,
        fontColor = { 220, 250, 255, 255 },
        textAlign = "center",
    }
    local speedUnit = UI.Label {
        text = "um/s",
        fontSize = 9,
        fontColor = { 100, 160, 200, 160 },
        textAlign = "center",
        marginTop = -2,
    }
    local speedBar = UI.ProgressBar {
        value = 20 / ctx.warpSpeed,
        width = "100%",
        height = 3,
        borderRadius = 2,
        fillGradient = {
            direction = "to-right",
            from = { 40, 160, 255, 255 },
            to = { 100, 255, 220, 255 },
        },
        backgroundColor = { 20, 40, 70, 120 },
        marginTop = 3,
    }

    -- 热量仪表
    local heatLabel = UI.Label {
        text = "0%",
        fontSize = 12,
        fontColor = { 100, 230, 120, 255 },
        textAlign = "center",
    }
    local heatBar = UI.ProgressBar {
        value = 0,
        width = "100%",
        height = 2,
        borderRadius = 1,
        fillGradient = {
            direction = "to-right",
            from = { 60, 200, 80, 255 },
            to = { 200, 220, 50, 255 },
        },
        backgroundColor = { 20, 40, 20, 100 },
        marginTop = 2,
    }

    -- 护盾仪表
    local shieldLabel = UI.Label {
        text = "就绪",
        fontSize = 12,
        fontColor = { 80, 200, 255, 255 },
        textAlign = "center",
    }

    -- 折跃仪表
    local warpLabel = UI.Label {
        text = "WARP",
        fontSize = 9,
        fontColor = { 140, 110, 200, 180 },
        textAlign = "center",
    }
    local warpBar = UI.ProgressBar {
        value = 0,
        width = "100%",
        height = 2,
        borderRadius = 1,
        fillGradient = {
            direction = "to-right",
            from = { 120, 60, 220, 255 },
            to = { 200, 130, 255, 255 },
        },
        backgroundColor = { 30, 15, 50, 100 },
        marginTop = 2,
    }
    local warpStatus = UI.Label {
        text = "◇◇◇◇◇",
        fontSize = 11,
        fontColor = { 160, 120, 240, 200 },
        textAlign = "center",
        marginTop = 1,
    }

    -- 翻滚技能
    local rollLeftLabel = UI.Label {
        text = "Q", fontSize = 14,
        fontColor = { 200, 200, 200, 255 }, textAlign = "center",
    }
    local rollRightLabel = UI.Label {
        text = "E", fontSize = 14,
        fontColor = { 200, 200, 200, 255 }, textAlign = "center",
    }

    -- 蓄能倒计时
    local warpCountLabel = UI.Label {
        text = "",
        fontSize = 64,
        fontColor = { 255, 255, 255, 255 },
        textAlign = "center",
        verticalAlign = "middle",
        position = "absolute",
        top = "38%",
        left = "0%",
        width = "100%",
        height = 120,
        justifyContent = "center",
        alignItems = "center",
    }

    -- 翻滚技能面板
    local rollLeftIcon = UI.Label { text = "↺", fontSize = 16, fontColor = { 60, 140, 255, 200 }, textAlign = "center" }
    local rollLeftPanel = UI.Panel {
        width = 52, height = 52,
        borderRadius = 8, borderWidth = 2,
        borderColor = { 60, 140, 255, 200 },
        backgroundColor = { 10, 10, 20, 140 },
        alignItems = "center", justifyContent = "center",
        marginRight = 12,
        children = { rollLeftIcon, rollLeftLabel },
    }
    local rollRightIcon = UI.Label { text = "↻", fontSize = 16, fontColor = { 60, 140, 255, 200 }, textAlign = "center" }
    local rollRightPanel = UI.Panel {
        width = 52, height = 52,
        borderRadius = 8, borderWidth = 2,
        borderColor = { 60, 140, 255, 200 },
        backgroundColor = { 10, 10, 20, 140 },
        alignItems = "center", justifyContent = "center",
        marginLeft = 12,
        children = { rollRightIcon, rollRightLabel },
    }

    -- 底部仪表盘
    local root = UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            warpCountLabel,
            -- 顶部状态栏
            UI.Panel {
                width = "100%",
                paddingTop = 12, paddingLeft = 20, paddingRight = 20,
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = { scoreLabel, livesLabel },
            },
            -- 底部仪表盘
            UI.Panel {
                width = "100%",
                position = "absolute",
                bottom = 0,
                alignItems = "center",
                justifyContent = "center",
                paddingBottom = 16,
                flexDirection = "row",
                children = {
                    rollLeftPanel,
                    -- 外壳
                    UI.Panel {
                        width = 480,
                        backgroundColor = { 3, 6, 16, 140 },
                        borderRadius = 14, borderWidth = 1,
                        borderColor = { 40, 100, 180, 70 },
                        paddingTop = 2, paddingBottom = 2,
                        paddingLeft = 3, paddingRight = 3,
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row",
                                alignItems = "stretch",
                                children = {
                                    -- 左翼面板
                                    UI.Panel {
                                        width = 130,
                                        backgroundColor = { 8, 14, 30, 140 },
                                        borderRadius = 10,
                                        paddingTop = 5, paddingBottom = 5,
                                        paddingLeft = 10, paddingRight = 10,
                                        alignItems = "center", justifyContent = "center",
                                        children = {
                                            UI.Label { text = "⬡ HEAT", fontSize = 8, fontColor = { 60, 160, 100, 180 }, textAlign = "center", marginBottom = 2 },
                                            heatLabel, heatBar,
                                            UI.Panel { width = "70%", height = 1, backgroundColor = { 40, 100, 140, 60 }, marginTop = 4, marginBottom = 3 },
                                            UI.Label { text = "⬡ SHIELD", fontSize = 8, fontColor = { 50, 140, 200, 180 }, textAlign = "center", marginBottom = 2 },
                                            shieldLabel,
                                        },
                                    },
                                    UI.Panel { width = 1, backgroundColor = { 40, 100, 180, 50 }, marginTop = 8, marginBottom = 8 },
                                    -- 中央速度面板
                                    UI.Panel {
                                        flexGrow = 1,
                                        backgroundColor = { 5, 10, 24, 160 },
                                        borderRadius = 10,
                                        marginLeft = 2, marginRight = 2,
                                        paddingTop = 5, paddingBottom = 5,
                                        paddingLeft = 14, paddingRight = 14,
                                        alignItems = "center", justifyContent = "center",
                                        children = {
                                            UI.Label { text = "◈ VELOCITY ◈", fontSize = 8, fontColor = { 60, 140, 220, 160 }, textAlign = "center", marginBottom = 1 },
                                            speedLabel, speedUnit, speedBar,
                                        },
                                    },
                                    UI.Panel { width = 1, backgroundColor = { 40, 100, 180, 50 }, marginTop = 8, marginBottom = 8 },
                                    -- 右翼面板
                                    UI.Panel {
                                        width = 130,
                                        backgroundColor = { 8, 14, 30, 140 },
                                        borderRadius = 10,
                                        paddingTop = 5, paddingBottom = 5,
                                        paddingLeft = 10, paddingRight = 10,
                                        alignItems = "center", justifyContent = "center",
                                        children = {
                                            UI.Label { text = "⬡ WARP", fontSize = 8, fontColor = { 140, 100, 220, 180 }, textAlign = "center", marginBottom = 2 },
                                            warpStatus, warpBar,
                                            UI.Panel { width = "70%", height = 1, backgroundColor = { 40, 100, 140, 60 }, marginTop = 4, marginBottom = 3 },
                                            UI.Label { text = "⬡ ENGAGE", fontSize = 8, fontColor = { 100, 80, 180, 180 }, textAlign = "center", marginBottom = 2 },
                                            UI.Label { text = "[SPACE]", fontSize = 10, fontColor = { 130, 110, 200, 200 }, textAlign = "center" },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    rollRightPanel,
                },
            },
        },
    }
    UI.SetRoot(root)

    return {
        scoreLabel = scoreLabel,
        livesLabel = livesLabel,
        speedLabel = speedLabel,
        speedUnit = speedUnit,
        speedBar = speedBar,
        heatLabel = heatLabel,
        heatBar = heatBar,
        shieldLabel = shieldLabel,
        warpLabel = warpLabel,
        warpBar = warpBar,
        warpStatus = warpStatus,
        warpCountLabel = warpCountLabel,
        rollLeftLabel = rollLeftLabel,
        rollRightLabel = rollRightLabel,
        rollLeftIcon = rollLeftIcon,
        rollLeftPanel = rollLeftPanel,
        rollRightIcon = rollRightIcon,
        rollRightPanel = rollRightPanel,
    }
end

-- ============================================================================
-- 游戏结束界面
-- ============================================================================

--- 显示 Game Over 界面（永恒漂泊）
--- @param ctx table { score, gameTime, speed, endingBgmEnabled, onReturnMenu, onToggleEndingBGM }
--- @return table refs { endingMusicBtn }
function GameUI.showGameOver(ctx)
    local endingMusicBtn = UI.Label {
        text = ctx.endingBgmEnabled and "🔊" or "🔇",
        fontSize = 22,
        fontColor = ctx.endingBgmEnabled and { 120, 220, 255, 220 } or { 120, 120, 140, 150 },
        textAlign = "center",
    }

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 5, 235 },
        children = {
            -- 音乐按钮
            UI.Panel {
                position = "absolute",
                top = 16, left = 16,
                width = 44, height = 44,
                backgroundColor = { 10, 30, 60, 160 },
                borderRadius = 22, borderWidth = 1,
                borderColor = { 80, 200, 255, 120 },
                justifyContent = "center", alignItems = "center",
                pointerEvents = "auto",
                onClick = function() ctx.onToggleEndingBGM() end,
                children = { endingMusicBtn },
            },
            UI.Panel {
                width = "88%",
                maxWidth = 560, maxHeight = "92%",
                backgroundColor = { 8, 12, 28, 245 },
                borderRadius = 16, borderWidth = 1,
                borderColor = { 80, 140, 220, 100 },
                paddingTop = 28, paddingBottom = 28,
                paddingLeft = 28, paddingRight = 28,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "结局：永恒漂泊",
                        fontSize = 22,
                        fontColor = { 255, 100, 100, 255 },
                        marginBottom = 16, textAlign = "center", width = "100%",
                    },
                    UI.Panel {
                        width = "100%", height = 180,
                        borderRadius = 10, marginBottom = 16,
                        backgroundImage = "image/结局5.png",
                        backgroundFit = "cover",
                        borderWidth = 1, borderColor = { 60, 100, 180, 80 },
                    },
                    UI.Label {
                        text = "陨石猛击舰体，引擎瞬间瘫痪。飞船彻底失去动力，从此被困在茫茫深空，如陨石一般于无边黑暗中独自漂泊......",
                        fontSize = 14,
                        fontColor = { 200, 210, 230, 230 },
                        marginBottom = 20, width = "100%",
                        textAlign = "center", whiteSpace = "normal", lineHeight = 1.8,
                    },
                    UI.Label {
                        text = string.format("最终得分: %d | 飞行距离: %.1f km",
                            ctx.score, ctx.gameTime * ctx.speed / 1000),
                        fontSize = 12,
                        fontColor = { 120, 140, 170, 160 },
                        marginBottom = 20, textAlign = "center", width = "100%",
                    },
                    UI.Panel {
                        width = 200, height = 52,
                        backgroundColor = { 10, 30, 60, 180 },
                        borderRadius = 12, borderWidth = 2,
                        borderColor = { 80, 200, 255, 200 },
                        justifyContent = "center", alignItems = "center",
                        pointerEvents = "auto",
                        onClick = function() ctx.onReturnMenu() end,
                        children = {
                            UI.Label {
                                id = "endingBtn",
                                text = "再次航行",
                                fontSize = 20,
                                fontColor = { 120, 220, 255, 255 },
                                textAlign = "center", letterSpacing = 4,
                            },
                        },
                    },
                },
            },
        },
    }
    UI.SetRoot(root)

    return { endingMusicBtn = endingMusicBtn }
end

-- ============================================================================
-- 剧情选项弹窗
-- ============================================================================

--- 显示剧情选择界面
--- @param ctx table { thresholdIdx, score, story, onChoiceMade }
function GameUI.showStoryChoice(ctx)
    local titleText = string.format("— 第 %d 次航行抉择 —", ctx.thresholdIdx)

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 2, 2, 15, 220 },
        children = {
            UI.Panel {
                width = 420,
                backgroundColor = { 10, 15, 35, 240 },
                borderRadius = 16, borderWidth = 1,
                borderColor = { 60, 120, 200, 120 },
                paddingTop = 30, paddingBottom = 30,
                paddingLeft = 30, paddingRight = 30,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = titleText,
                        fontSize = 20,
                        fontColor = { 180, 220, 255, 255 },
                        marginBottom = 8,
                    },
                    UI.Label {
                        text = string.format("当前得分: %d", ctx.score),
                        fontSize = 14,
                        fontColor = { 150, 180, 200, 180 },
                        marginBottom = 24,
                    },
                    -- 选项 1：修复飞船
                    UI.Button {
                        text = "修复飞船（恢复满生命值）",
                        width = "100%", height = 48,
                        fontSize = 16, variant = "primary",
                        marginBottom = 12,
                        onClick = function()
                            ctx.onChoiceMade("repair", ctx.thresholdIdx)
                        end,
                    },
                    -- 选项 2：生命探索
                    UI.Button {
                        text = "进行一次生命探索",
                        width = "100%", height = 48,
                        fontSize = 16, variant = "default",
                        marginBottom = 12,
                        onClick = function()
                            ctx.onChoiceMade("explore", ctx.thresholdIdx)
                        end,
                    },
                    -- 选项 3：位置广播
                    UI.Button {
                        text = "进行一次位置广播",
                        width = "100%", height = 48,
                        fontSize = 16, variant = "default",
                        onClick = function()
                            ctx.onChoiceMade("broadcast", ctx.thresholdIdx)
                        end,
                    },
                    -- 当前记录
                    UI.Panel {
                        width = "100%", marginTop = 20, paddingTop = 12,
                        borderColor = { 40, 80, 140, 60 },
                        children = {
                            UI.Label {
                                text = ctx.story:getRecordText(),
                                fontSize = 12,
                                fontColor = { 120, 150, 180, 160 },
                                textAlign = "center", width = "100%",
                            },
                        },
                    },
                },
            },
        },
    }
    UI.SetRoot(root)
end

-- ============================================================================
-- 剧情结局界面
-- ============================================================================

--- 显示剧情结局界面
--- @param ctx table { ending, score, story, endingBgmEnabled, onReturnMenu, onToggleEndingBGM }
--- @return table refs { endingMusicBtn }
function GameUI.showStoryEnding(ctx)
    local ending = ctx.ending

    local endingMusicBtn = UI.Label {
        text = ctx.endingBgmEnabled and "🔊" or "🔇",
        fontSize = 22,
        fontColor = ctx.endingBgmEnabled and { 120, 220, 255, 220 } or { 120, 120, 140, 150 },
        textAlign = "center",
    }

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 5, 235 },
        children = {
            -- 音乐按钮
            UI.Panel {
                position = "absolute",
                top = 16, left = 16,
                width = 44, height = 44,
                backgroundColor = { 10, 30, 60, 160 },
                borderRadius = 22, borderWidth = 1,
                borderColor = { 80, 200, 255, 120 },
                justifyContent = "center", alignItems = "center",
                pointerEvents = "auto",
                onClick = function() ctx.onToggleEndingBGM() end,
                children = { endingMusicBtn },
            },
            UI.Panel {
                width = "88%",
                maxWidth = 560, maxHeight = "92%",
                backgroundColor = { 8, 12, 28, 245 },
                borderRadius = 16, borderWidth = 1,
                borderColor = { 80, 140, 220, 100 },
                paddingTop = 28, paddingBottom = 28,
                paddingLeft = 28, paddingRight = 28,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = ending.title,
                        fontSize = 22,
                        fontColor = ending.color,
                        marginBottom = 16, textAlign = "center", width = "100%",
                    },
                    UI.Panel {
                        width = "100%", height = 180,
                        borderRadius = 10, marginBottom = 16,
                        backgroundImage = ending.image,
                        backgroundFit = "cover",
                        borderWidth = 1, borderColor = { 60, 100, 180, 80 },
                    },
                    UI.Label {
                        text = ending.text,
                        fontSize = 14,
                        fontColor = { 200, 210, 230, 230 },
                        marginBottom = 20, width = "100%",
                        textAlign = "center", whiteSpace = "normal", lineHeight = 1.8,
                    },
                    UI.Label {
                        text = string.format("%s | 得分: %d", ctx.story:getRecordText(), ctx.score),
                        fontSize = 12,
                        fontColor = { 120, 140, 170, 160 },
                        marginBottom = 20, textAlign = "center", width = "100%",
                    },
                    UI.Panel {
                        width = 200, height = 52,
                        backgroundColor = { 10, 30, 60, 180 },
                        borderRadius = 12, borderWidth = 2,
                        borderColor = { 80, 200, 255, 200 },
                        justifyContent = "center", alignItems = "center",
                        pointerEvents = "auto",
                        onClick = function() ctx.onReturnMenu() end,
                        children = {
                            UI.Label {
                                id = "endingBtn",
                                text = "重新航行",
                                fontSize = 20,
                                fontColor = { 120, 220, 255, 255 },
                                textAlign = "center", letterSpacing = 4,
                            },
                        },
                    },
                },
            },
        },
    }
    UI.SetRoot(root)

    return { endingMusicBtn = endingMusicBtn }
end

return GameUI
