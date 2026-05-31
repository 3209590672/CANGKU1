-- ============================================================================
-- 宇宙航行 (Space Voyager)
-- 玩法：驾驶飞船在宇宙中穿梭，闪避小行星，收集能量水晶
-- 操作：WASD/方向键移动飞船，Shift减速，收集5水晶长按空格折跃，左键射击，右键护盾
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- 性能：本地化 math 函数（消除全局表查找开销）
-- ============================================================================
local math_sin = math.sin
local math_cos = math.cos
local math_tan = math.tan
local math_sqrt = math.sqrt
local math_random = math.random
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local math_ceil = math.ceil
local math_abs = math.abs
local math_atan = math.atan
local math_deg = math.deg
local math_pi = math.pi
local table_insert = table.insert
local table_remove = table.remove

-- ============================================================================
-- 全局变量
-- ============================================================================
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Node
local shipNode_ = nil

-- 游戏状态
local STATE_MENU = 1
local STATE_PLAYING = 2
local STATE_GAMEOVER = 3
local STATE_STORY_CHOICE = 4   -- 剧情选项弹窗（暂停游戏）
local STATE_STORY_ENDING = 5   -- 结局剧情展示
local gameState_ = STATE_MENU

-- 游戏数据
local score_ = 0
local lives_ = 5
local speed_ = 20.0
local maxSpeed_ = 80.0
local speedIncrement_ = 0.5
local shipX_ = 0.0
local shipY_ = 0.0
local shipMoveSpeed_ = 6.5
local moveRangeX_ = 6.0
local moveRangeY_ = 3.2
local currentTiltX_ = 0.0
local currentTiltZ_ = 0.0
local frameCount_ = 0
-- 速度平滑（丝滑手感）
local shipVelX_ = 0.0
local shipVelY_ = 0.0
local shipAccel_ = 60.0      -- 加速度
local shipDecel_ = 40.0      -- 减速摩擦

-- 小行星系统
local asteroids_ = {}
local asteroidSpawnTimer_ = 0
local asteroidSpawnInterval_ = 0.4
local asteroidMinInterval_ = 0.12

-- 能量水晶系统
local crystals_ = {}
local crystalSpawnTimer_ = 0
local crystalSpawnInterval_ = 1.5

-- 星尘粒子
local starDusts_ = {}
local starDustCount_ = 50

-- 碰撞参数
local shipRadius_ = 0.8
local asteroidRadius_ = 1.2
local crystalRadius_ = 0.8

-- 无敌时间
local invincibleTimer_ = 0
local invincibleDuration_ = 1.5

-- 射击系统
local bullets_ = {}
local bulletSpeed_ = 120.0
local fireRate_ = 0.12          -- 射击间隔（秒）
local fireTimer_ = 0

-- 过热系统
local heat_ = 0                 -- 当前热量 0~100
local heatPerShot_ = 8          -- 每发子弹增加的热量
local heatCoolRate_ = 15        -- 正常散热速率（每秒）
local heatMax_ = 100
local overheated_ = false       -- 是否过热
local overheatCooldown_ = 5.0   -- 过热冷却时间（秒）
local overheatTimer_ = 0        -- 过热倒计时

-- 护盾系统
local shieldActive_ = false
local shieldNode_ = nil
local shieldDuration_ = 5.0     -- 护盾持续时间
local shieldTimer_ = 0
local shieldCooldown_ = 5.0     -- 护盾冷却时间
local shieldCoolTimer_ = 0      -- 护盾冷却计时（0=可用）
local shieldAnimTime_ = 0.75    -- 护盾展开/收回动画时长
local shieldAnimTimer_ = 0      -- 动画计时器
local shieldAnimState_ = "none" -- "expanding" / "collapsing" / "none"

-- 翻滚技能系统
local rollActive_ = false       -- 翻滚是否激活
local rollTimer_ = 0            -- 翻滚剩余时间
local rollDuration_ = 0.5      -- 翻滚持续时间
local rollDirection_ = 0        -- 1=右翻滚(E), -1=左翻滚(Q)
local rollAngle_ = 0            -- 当前翻滚累计角度
local rollCd_ = 5.0             -- 翻滚冷却时间
local rollCdLeftTimer_ = 0      -- 左翻滚冷却剩余
local rollCdRightTimer_ = 0     -- 右翻滚冷却剩余
local rollWobbleTimer_ = 0      -- 翻滚结束后摇晃剩余时间
local rollWobbleDuration_ = 1.0 -- 摇晃持续时间
local rollWobbleDir_ = 0        -- 摇晃初始方向（继承翻滚方向）

-- 爆炸特效系统
local explosions_ = {}

-- 折跃系统
local warpEnergy_ = 0           -- 当前折跃能量（收集水晶积累）
local warpMaxEnergy_ = 5        -- 需要 5 个水晶充满
local warpCharging_ = false     -- 是否正在长按充能
local warpChargeTime_ = 5.0     -- 需要长按 5 秒
local warpChargeTimer_ = 0      -- 当前充能倒计时
local warpActive_ = false       -- 折跃是否激活中
local warpDuration_ = 10.0      -- 折跃持续时间
local warpTimer_ = 0            -- 折跃剩余时间
local warpSpeed_ = 150.0        -- 折跃速度
local warpStreaks_ = {}         -- 穿越光条节点
local warpStreakCount_ = 32     -- 光条数量
local warpGlowNode_ = nil      -- 飞船折跃发光
local warpWingTrailBBS_ = nil   -- 翼尖warp拖尾（BillboardSet）
local warpWingTrailNode_ = nil  -- 翼尖拖尾节点（控制显示/隐藏）
local warpWingTrailData_ = {}   -- 翼尖拖尾历史位置

-- 游戏时间
local gameTime_ = 0
local zone_ = nil  -- Zone引用（用于雾动画）

-- ============================================================================
-- 剧情系统
-- ============================================================================
local storyRepairCount_ = 0      -- 修复飞船记录
local storyExploreCount_ = 0     -- 生命探索记录
local storyBroadcastCount_ = 0   -- 位置广播记录

-- 剧情触发分数阈值
local storyThresholds_ = { 1000, 2000, 3000, 4000, 5000 }
local storyTriggeredIndex_ = 0   -- 已触发到第几个阈值（0=未触发过）

-- 菜单按钮动画引用
local menuStartLabel_ = nil
local menuStartBtn_ = nil

-- BGM 相关
local bgmNode_ = nil
local bgmSource_ = nil
local bgmEnabled_ = true
local bgmSound_ = nil
local menuMusicBtn_ = nil

-- ============================================================================
-- 预缓存材质（性能优化：避免每帧/每次生成时创建 Material）
-- ============================================================================
-- 护盾脉冲材质（复用单实例，只更新 shader 参数）
local shieldPulseMat_ = nil
local shieldFillMat_ = nil

-- 子弹材质（所有子弹共享）
local bulletCoreMat_ = nil
local bulletGlowMat_ = nil
local bulletTrailMats_ = {}   -- [1..5] 按距离渐隐
local bulletTipMat_ = nil

-- 爆炸材质模板
local explosionRayMat_ = nil
local explosionDebrisMat_ = nil
local explosionGlowBaseMat_ = nil  -- 光球基础材质（Clone 用）

-- 水晶材质（3种颜色变体）
local crystalMats_ = {}

-- 小行星共享材质
local asteroidRockMats_ = {}      -- 6种岩石色调
local asteroidDebrisMats_ = {}    -- 对应碎石材质
local asteroidCrackMat_ = nil     -- 熔岩裂缝
local asteroidOreMat_ = nil       -- 冰晶矿脉
local asteroidMeshPool_ = {}      -- 预生成岩石网格数据池（6组）
local asteroidMeshPoolSize_ = 6

-- 航道外装饰陨石（纯视觉，无碰撞）
local decoAsteroids_ = {}
local decoAsteroidMat_ = nil      -- 共享暗色材质（单个）

-- 流星系统（菜单背景 - 彩虹弧线）
local meteors_ = {}
local meteorMat_ = nil             -- 流星自发光材质
local meteorNextGroupTime_ = 0     -- 下一群触发时间

-- 尾焰火花粒子（BillboardSet，单draw call）
local exhaustSparkBBS_ = nil
local exhaustSparkNode_ = nil
local exhaustSparkData_ = {}       -- 每个火花的状态{life, maxLife, vz, vx, vy}

-- 深空星河背景（BillboardSet，大部分静态）
local starfieldNode_ = nil
local starfieldBBS_ = nil          -- BillboardSet 引用（避免 GetComponent）
local starBreathIndices_ = {}      -- 呼吸星点索引列表
local starBreathBaseSize_ = {}     -- 对应基础尺寸
local starBreathPhase_ = {}        -- 对应相位偏移

-- 星尘共享材质
local starDustMat_ = nil

-- 预缓存模型引用（避免每帧/每次生成时重复查找）
local mdlBox_ = nil
local mdlSphere_ = nil
local mdlCylinder_ = nil



-- NanoVG 充能圆环
local vg_ = nil                -- NanoVG 上下文

-- HUD 控件引用（游戏中需要动态更新）
---@type Widget|nil
local scoreLabel_ = nil
---@type Widget|nil
local livesLabel_ = nil
---@type Widget|nil
local speedLabel_ = nil
---@type Widget|nil
local speedBar_ = nil
---@type Widget|nil
local speedUnit_ = nil
---@type Widget|nil
local heatLabel_ = nil
---@type Widget|nil
local heatBar_ = nil
---@type Widget|nil
local shieldLabel_ = nil
---@type Widget|nil
local warpLabel_ = nil
---@type Widget|nil
local warpBar_ = nil
---@type Widget|nil
local warpStatus_ = nil
local warpCountLabel_ = nil    -- 屏幕中央倒计时数字
local rollLeftLabel_ = nil     -- 左翻滚技能CD显示
local rollRightLabel_ = nil    -- 右翻滚技能CD显示
local rollLeftPanel_ = nil     -- 左翻滚技能框Panel
local rollRightPanel_ = nil    -- 右翻滚技能框Panel
local rollLeftIcon_ = nil      -- 左翻滚图标Label
local rollRightIcon_ = nil     -- 右翻滚图标Label

-- HUD 状态缓存（避免每帧重复 SetStyle/SetFontColor 造成性能抖动）
local hudState_ = {
    speedMode = "",     -- "warp" / "normal"
    speedBarMode = "",  -- "warp" / "high" / "normal"
    heatMode = "",      -- "overheated" / "high" / "normal"
    shieldMode = "",    -- "active" / "cooldown" / "ready"
    warpMode = "",      -- "warping" / "charging" / "ready" / "idle"
    warpBarMode = "",   -- "warp" / "charge" / "normal"
    lastCountSec = 0,   -- 倒计时缓存（避免每帧 SetText）
    lastWarpEnergy = -1, -- 能量钻石缓存
    lastWarpBarVal = -1, -- 进度条值缓存（量化到 2% 步进）
}

-- ============================================================================
-- 入口
-- ============================================================================

function Start()
    engine.maxFps = 60
    graphics.windowTitle = "Space Voyager"

    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    InitCachedMaterials()

    CreateScene()

    CreateShip()
    CreateStarDusts()
    CreateWarpStreaks()
    CalculateVisibleRange()
    CreateStarfield()
    CreateDecoAsteroids()
    CreateMeteors()

    -- 显示菜单 UI
    ShowMenuUI()

    -- 初始化BGM
    InitBGM()

    -- NanoVG 初始化（充能圆环 + 倒计时文字）
    vg_ = nvgCreate(1)
    nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(vg_, "NanoVGRender", "HandleNanoVGRender")
    print("=== Space Voyager Started ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 根据相机 FOV 和屏幕比例动态计算可见范围
-- ============================================================================

function CalculateVisibleRange()
    local camZ = cameraNode_.position.z
    local shipZ = 0.0
    local dist = shipZ - camZ
    local fovRad = 70.0 * math_pi / 180.0
    local halfHeight = math_tan(fovRad / 2) * dist
    local aspect = graphics:GetWidth() / graphics:GetHeight()
    local halfWidth = halfHeight * aspect
    moveRangeX_ = halfWidth - 1.0
    moveRangeY_ = halfHeight - 0.8
    print(string.format("=== Visible range: X=%.1f Y=%.1f (aspect=%.2f) ===", moveRangeX_, moveRangeY_, aspect))
end

-- ============================================================================
-- BGM 初始化与控制
-- ============================================================================

function InitBGM()
    local sound = cache:GetResource("Sound", "BGM/cosmic_drift.ogg")
    if sound == nil then
        print("[BGM] ERROR: Failed to load BGM/cosmic_drift.ogg")
        return
    end
    sound.looped = true

    bgmNode_ = scene_:CreateChild("BGM")
    bgmSource_ = bgmNode_:CreateComponent("SoundSource")
    bgmSource_.soundType = SOUND_MUSIC
    bgmSource_.gain = 0.5
    bgmSource_:Play(sound)
    bgmEnabled_ = true

    -- 浏览器自动播放策略：首次交互后恢复音频
    bgmSound_ = sound
    SubscribeToEvent("MouseButtonDown", "HandleAudioResume")
    SubscribeToEvent("TouchBegin", "HandleAudioResume")
end

--- 浏览器首次交互后恢复BGM播放
function HandleAudioResume(eventType, eventData)
    -- 仅在菜单状态且BGM开启时恢复播放
    if gameState_ ~= STATE_MENU then return end
    if bgmSource_ and bgmEnabled_ and bgmSound_ then
        bgmSource_:Play(bgmSound_)
        bgmSource_.gain = 0.5
    end
    -- 取消监听，避免重复触发
    UnsubscribeFromEvent("MouseButtonDown")
    UnsubscribeFromEvent("TouchBegin")
end

function ToggleBGM()
    if bgmSource_ == nil then return end
    bgmEnabled_ = not bgmEnabled_
    if bgmEnabled_ then
        -- 如果音频因浏览器策略未播放，尝试恢复
        if not bgmSource_.playing and bgmSound_ then
            bgmSource_:Play(bgmSound_)
        end
        bgmSource_.gain = 0.5
    else
        bgmSource_.gain = 0.0
    end
    -- 更新按钮图标
    if menuMusicBtn_ then
        menuMusicBtn_:SetText(bgmEnabled_ and "🔊" or "🔇")
        menuMusicBtn_:SetFontColor(bgmEnabled_ and { 120, 220, 255, 220 } or { 120, 120, 140, 150 })
    end
end

-- 结局BGM
local endingBgmNode_ = nil
local endingBgmSource_ = nil
local endingBgmEnabled_ = true
local endingMusicBtn_ = nil

-- 结局BGM文件映射
local endingBgmFiles_ = {
    ["最后的希望"] = "BGM/ending_last_hope.ogg",
    ["黑暗森林"]   = "BGM/ending_dark_forest.ogg",
    ["故土尘埃"]   = "BGM/ending_homeland_dust.ogg",
    ["新生"]       = "BGM/ending_new_dawn.ogg",
    ["永恒漂泊"]   = "BGM/ending_eternal_drift.ogg",
}

function PlayEndingBGM(endingKey)
    -- 停止主BGM
    if bgmSource_ then bgmSource_.gain = 0.0 end

    -- 停止之前的结局BGM
    StopEndingBGM()

    local file = endingBgmFiles_[endingKey]
    if not file then return end

    local sound = cache:GetResource("Sound", file)
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

function StopEndingBGM()
    if endingBgmSource_ then
        endingBgmSource_:Stop()
        endingBgmSource_ = nil
    end
    if endingBgmNode_ then
        endingBgmNode_:Remove()
        endingBgmNode_ = nil
    end
    endingMusicBtn_ = nil
end

function ToggleEndingBGM()
    if endingBgmSource_ == nil then return end
    endingBgmEnabled_ = not endingBgmEnabled_
    if endingBgmEnabled_ then
        endingBgmSource_.gain = 0.5
    else
        endingBgmSource_.gain = 0.0
    end
    if endingMusicBtn_ then
        endingMusicBtn_:SetText(endingBgmEnabled_ and "🔊" or "🔇")
        endingMusicBtn_:SetFontColor(endingBgmEnabled_ and { 120, 220, 255, 220 } or { 120, 120, 140, 150 })
    end
end

-- ============================================================================
-- UI：每个状态一个独立的 SetRoot 调用
-- ============================================================================

function ShowMenuUI()
    -- 科幻风格 Start 按钮
    menuStartLabel_ = UI.Label {
        text = "START",
        fontSize = 22,
        fontColor = { 120, 220, 255, 255 },
        textAlign = "center",
        letterSpacing = 4,
    }
    menuStartBtn_ = UI.Panel {
        width = 200,
        height = 52,
        backgroundColor = { 10, 30, 60, 180 },
        borderRadius = 12,
        borderWidth = 2,
        borderColor = { 80, 200, 255, 200 },
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "auto",
        onClick = function()
            StartGame()
        end,
        children = { menuStartLabel_ },
    }

    -- 标题图片（中上部分）
    local menuChildren = {}
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

    -- 构建渐变蒙版：0%~75% 完全透明，75%~100% 每1%加深一档（25条）
    for step = 0, 24 do
        local pct = 75 + step       -- 75% ~ 99%
        local alpha = math_floor(step * (255 / 25))  -- 0 ~ 244
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
        children = { menuStartBtn_ },
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

    -- 左上角音乐开关按钮
    menuMusicBtn_ = UI.Label {
        id = "musicBtn",
        text = bgmEnabled_ and "🔊" or "🔇",
        fontSize = 22,
        fontColor = bgmEnabled_ and { 120, 220, 255, 220 } or { 120, 120, 140, 150 },
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
        onClick = function()
            ToggleBGM()
        end,
        children = { menuMusicBtn_ },
    })

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        children = menuChildren,
    }
    UI.SetRoot(root)
end

function ShowPlayingUI()
    -- 顶部信息
    scoreLabel_ = UI.Label {
        text = "得分: 0",
        fontSize = 18,
        fontColor = { 255, 220, 100, 255 },
    }
    livesLabel_ = UI.Label {
        text = "✈✈✈✈✈",
        fontSize = 18,
        fontColor = { 180, 210, 240, 255 },
    }

    -- === 速度仪表（中央核心） ===
    speedLabel_ = UI.Label {
        text = "20",
        fontSize = 26,
        fontColor = { 220, 250, 255, 255 },
        textAlign = "center",
    }
    speedUnit_ = UI.Label {
        text = "um/s",
        fontSize = 9,
        fontColor = { 100, 160, 200, 160 },
        textAlign = "center",
        marginTop = -2,
    }
    speedBar_ = UI.ProgressBar {
        value = 20 / warpSpeed_,
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

    -- === 左翼：热量仪表 ===
    heatLabel_ = UI.Label {
        text = "0%",
        fontSize = 12,
        fontColor = { 100, 230, 120, 255 },
        textAlign = "center",
    }
    heatBar_ = UI.ProgressBar {
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

    -- === 左翼：护盾仪表 ===
    shieldLabel_ = UI.Label {
        text = "就绪",
        fontSize = 12,
        fontColor = { 80, 200, 255, 255 },
        textAlign = "center",
    }

    -- === 右翼：折跃仪表 ===
    warpLabel_ = UI.Label {
        text = "WARP",
        fontSize = 9,
        fontColor = { 140, 110, 200, 180 },
        textAlign = "center",
    }
    warpBar_ = UI.ProgressBar {
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
    warpStatus_ = UI.Label {
        text = "◇◇◇◇◇",
        fontSize = 11,
        fontColor = { 160, 120, 240, 200 },
        textAlign = "center",
        marginTop = 1,
    }

    -- === 翻滚技能 CD 标签 ===
    rollLeftLabel_ = UI.Label {
        text = "Q",
        fontSize = 14,
        fontColor = { 200, 200, 200, 255 },
        textAlign = "center",
    }
    rollRightLabel_ = UI.Label {
        text = "E",
        fontSize = 14,
        fontColor = { 200, 200, 200, 255 },
        textAlign = "center",
    }

    -- === 蓄能倒计时（屏幕中央，默认隐藏） ===
    warpCountLabel_ = UI.Label {
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

    -- === 底部仪表盘（对称圆角科技风） ===
    local root = UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            -- 蓄能倒计时
            warpCountLabel_,
            -- 顶部状态栏
            UI.Panel {
                width = "100%",
                paddingTop = 12,
                paddingLeft = 20,
                paddingRight = 20,
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    scoreLabel_,
                    livesLabel_,
                }
            },
            -- 底部仪表盘区域
            UI.Panel {
                width = "100%",
                position = "absolute",
                bottom = 0,
                alignItems = "center",
                justifyContent = "center",
                paddingBottom = 16,
                flexDirection = "row",
                children = {
                    -- ═══ 左翻滚技能框 ═══
                    (function()
                        rollLeftIcon_ = UI.Label { text = "↺", fontSize = 16, fontColor = { 60, 140, 255, 200 }, textAlign = "center" }
                        rollLeftPanel_ = UI.Panel {
                            width = 52,
                            height = 52,
                            borderRadius = 8,
                            borderWidth = 2,
                            borderColor = { 60, 140, 255, 200 },
                            backgroundColor = { 10, 10, 20, 140 },
                            alignItems = "center",
                            justifyContent = "center",
                            marginRight = 12,
                            children = {
                                rollLeftIcon_,
                                rollLeftLabel_,
                            }
                        }
                        return rollLeftPanel_
                    end)(),
                    -- 外壳：大圆角科技边框（紧凑+底部半透明）
                    UI.Panel {
                        width = 480,
                        backgroundColor = { 3, 6, 16, 140 },
                        borderRadius = 14,
                        borderWidth = 1,
                        borderColor = { 40, 100, 180, 70 },
                        paddingTop = 2,
                        paddingBottom = 2,
                        paddingLeft = 3,
                        paddingRight = 3,
                        children = {
                            -- 内层容器（三段式）
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row",
                                alignItems = "stretch",
                                children = {
                                    -- ═══ 左翼面板 ═══
                                    UI.Panel {
                                        width = 130,
                                        backgroundColor = { 8, 14, 30, 140 },
                                        borderRadius = 10,
                                        paddingTop = 5,
                                        paddingBottom = 5,
                                        paddingLeft = 10,
                                        paddingRight = 10,
                                        alignItems = "center",
                                        justifyContent = "center",
                                        children = {
                                            -- 热量标题
                                            UI.Label { text = "⬡ HEAT", fontSize = 8, fontColor = { 60, 160, 100, 180 }, textAlign = "center", marginBottom = 2 },
                                            heatLabel_,
                                            heatBar_,
                                            -- 分隔线
                                            UI.Panel { width = "70%", height = 1, backgroundColor = { 40, 100, 140, 60 }, marginTop = 4, marginBottom = 3 },
                                            -- 护盾标题
                                            UI.Label { text = "⬡ SHIELD", fontSize = 8, fontColor = { 50, 140, 200, 180 }, textAlign = "center", marginBottom = 2 },
                                            shieldLabel_,
                                        }
                                    },
                                    -- ═══ 中央竖分隔 ═══
                                    UI.Panel { width = 1, backgroundColor = { 40, 100, 180, 50 }, marginTop = 8, marginBottom = 8 },
                                    -- ═══ 中央速度面板 ═══
                                    UI.Panel {
                                        flexGrow = 1,
                                        backgroundColor = { 5, 10, 24, 160 },
                                        borderRadius = 10,
                                        marginLeft = 2,
                                        marginRight = 2,
                                        paddingTop = 5,
                                        paddingBottom = 5,
                                        paddingLeft = 14,
                                        paddingRight = 14,
                                        alignItems = "center",
                                        justifyContent = "center",
                                        children = {
                                            UI.Label { text = "◈ VELOCITY ◈", fontSize = 8, fontColor = { 60, 140, 220, 160 }, textAlign = "center", marginBottom = 1 },
                                            speedLabel_,
                                            speedUnit_,
                                            speedBar_,
                                        }
                                    },
                                    -- ═══ 右翼竖分隔 ═══
                                    UI.Panel { width = 1, backgroundColor = { 40, 100, 180, 50 }, marginTop = 8, marginBottom = 8 },
                                    -- ═══ 右翼面板（与左翼完全对称） ═══
                                    UI.Panel {
                                        width = 130,
                                        backgroundColor = { 8, 14, 30, 140 },
                                        borderRadius = 10,
                                        paddingTop = 5,
                                        paddingBottom = 5,
                                        paddingLeft = 10,
                                        paddingRight = 10,
                                        alignItems = "center",
                                        justifyContent = "center",
                                        children = {
                                            -- 折跃标题
                                            UI.Label { text = "⬡ WARP", fontSize = 8, fontColor = { 140, 100, 220, 180 }, textAlign = "center", marginBottom = 2 },
                                            warpStatus_,
                                            warpBar_,
                                            -- 分隔线
                                            UI.Panel { width = "70%", height = 1, backgroundColor = { 40, 100, 140, 60 }, marginTop = 4, marginBottom = 3 },
                                            -- 操作提示
                                            UI.Label { text = "⬡ ENGAGE", fontSize = 8, fontColor = { 100, 80, 180, 180 }, textAlign = "center", marginBottom = 2 },
                                            UI.Label { text = "[SPACE]", fontSize = 10, fontColor = { 130, 110, 200, 200 }, textAlign = "center" },
                                        }
                                    },
                                }
                            },
                        }
                    },
                    -- ═══ 右翻滚技能框 ═══
                    (function()
                        rollRightIcon_ = UI.Label { text = "↻", fontSize = 16, fontColor = { 60, 140, 255, 200 }, textAlign = "center" }
                        rollRightPanel_ = UI.Panel {
                            width = 52,
                            height = 52,
                            borderRadius = 8,
                            borderWidth = 2,
                            borderColor = { 60, 140, 255, 200 },
                            backgroundColor = { 10, 10, 20, 140 },
                            alignItems = "center",
                            justifyContent = "center",
                            marginLeft = 12,
                            children = {
                                rollRightIcon_,
                                rollRightLabel_,
                            }
                        }
                        return rollRightPanel_
                    end)(),
                }
            },
        }
    }
    UI.SetRoot(root)
end

function ShowGameOverUI()
    -- 播放永恒漂泊结局BGM
    PlayEndingBGM("永恒漂泊")

    -- 结局音乐按钮
    endingMusicBtn_ = UI.Label {
        text = endingBgmEnabled_ and "🔊" or "🔇",
        fontSize = 22,
        fontColor = endingBgmEnabled_ and { 120, 220, 255, 220 } or { 120, 120, 140, 150 },
        textAlign = "center",
    }

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 5, 235 },
        children = {
            -- 左上角音乐按钮
            UI.Panel {
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
                onClick = function()
                    ToggleEndingBGM()
                end,
                children = { endingMusicBtn_ },
            },
            UI.Panel {
                width = "88%",
                maxWidth = 560,
                maxHeight = "92%",
                backgroundColor = { 8, 12, 28, 245 },
                borderRadius = 16,
                borderWidth = 1,
                borderColor = { 80, 140, 220, 100 },
                paddingTop = 28,
                paddingBottom = 28,
                paddingLeft = 28,
                paddingRight = 28,
                alignItems = "center",
                children = {
                    -- 结局标题
                    UI.Label {
                        text = "结局：永恒漂泊",
                        fontSize = 22,
                        fontColor = { 255, 100, 100, 255 },
                        marginBottom = 16,
                        textAlign = "center",
                        width = "100%",
                    },
                    -- 结局图片区域
                    UI.Panel {
                        width = "100%",
                        height = 180,
                        borderRadius = 10,
                        marginBottom = 16,
                        backgroundImage = "image/结局5.png",
                        backgroundFit = "cover",
                        borderWidth = 1,
                        borderColor = { 60, 100, 180, 80 },
                    },
                    -- 结局文本区域
                    UI.Label {
                        text = "陨石猛击舰体，引擎瞬间瘫痪。飞船彻底失去动力，从此被困在茫茫深空，如陨石一般于无边黑暗中独自漂泊......",
                        fontSize = 14,
                        fontColor = { 200, 210, 230, 230 },
                        marginBottom = 20,
                        width = "100%",
                        textAlign = "center",
                        whiteSpace = "normal",
                        lineHeight = 1.8,
                    },
                    -- 记录摘要
                    UI.Label {
                        text = string.format("最终得分: %d | 飞行距离: %.1f km",
                            score_, gameTime_ * speed_ / 1000),
                        fontSize = 12,
                        fontColor = { 120, 140, 170, 160 },
                        marginBottom = 20,
                        textAlign = "center",
                        width = "100%",
                    },
                    UI.Panel {
                        width = 200,
                        height = 52,
                        backgroundColor = { 10, 30, 60, 180 },
                        borderRadius = 12,
                        borderWidth = 2,
                        borderColor = { 80, 200, 255, 200 },
                        justifyContent = "center",
                        alignItems = "center",
                        pointerEvents = "auto",
                        onClick = function()
                            ReturnToMenu()
                        end,
                        children = {
                            UI.Label {
                                id = "endingBtn",
                                text = "再次航行",
                                fontSize = 20,
                                fontColor = { 120, 220, 255, 255 },
                                textAlign = "center",
                                letterSpacing = 4,
                            },
                        },
                    },
                }
            },
        }
    }
    UI.SetRoot(root)
end

-- ============================================================================
-- 剧情选项弹窗 UI
-- ============================================================================

function ShowStoryChoiceUI(thresholdIdx)
    gameState_ = STATE_STORY_CHOICE

    local titleText = string.format("— 第 %d 次航行抉择 —", thresholdIdx)

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
                borderRadius = 16,
                borderWidth = 1,
                borderColor = { 60, 120, 200, 120 },
                paddingTop = 30,
                paddingBottom = 30,
                paddingLeft = 30,
                paddingRight = 30,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = titleText,
                        fontSize = 20,
                        fontColor = { 180, 220, 255, 255 },
                        marginBottom = 8,
                    },
                    UI.Label {
                        text = string.format("当前得分: %d", score_),
                        fontSize = 14,
                        fontColor = { 150, 180, 200, 180 },
                        marginBottom = 24,
                    },
                    -- 选项 1：修复飞船
                    UI.Button {
                        text = "修复飞船（恢复满生命值）",
                        width = "100%",
                        height = 48,
                        fontSize = 16,
                        variant = "primary",
                        marginBottom = 12,
                        onClick = function()
                            storyRepairCount_ = storyRepairCount_ + 1
                            lives_ = 5
                            OnStoryChoiceMade(thresholdIdx)
                        end
                    },
                    -- 选项 2：生命探索
                    UI.Button {
                        text = "进行一次生命探索",
                        width = "100%",
                        height = 48,
                        fontSize = 16,
                        variant = "default",
                        marginBottom = 12,
                        onClick = function()
                            storyExploreCount_ = storyExploreCount_ + 1
                            OnStoryChoiceMade(thresholdIdx)
                        end
                    },
                    -- 选项 3：位置广播
                    UI.Button {
                        text = "进行一次位置广播",
                        width = "100%",
                        height = 48,
                        fontSize = 16,
                        variant = "default",
                        onClick = function()
                            storyBroadcastCount_ = storyBroadcastCount_ + 1
                            OnStoryChoiceMade(thresholdIdx)
                        end
                    },
                    -- 当前记录展示
                    UI.Panel {
                        width = "100%",
                        marginTop = 20,
                        paddingTop = 12,
                        borderColor = { 40, 80, 140, 60 },
                        children = {
                            UI.Label {
                                text = string.format("修复: %d | 探索: %d | 广播: %d",
                                    storyRepairCount_, storyExploreCount_, storyBroadcastCount_),
                                fontSize = 12,
                                fontColor = { 120, 150, 180, 160 },
                                textAlign = "center",
                                width = "100%",
                            },
                        }
                    },
                }
            },
        }
    }
    UI.SetRoot(root)
end

function OnStoryChoiceMade(thresholdIdx)
    -- 第 5 次选择后触发结局
    if thresholdIdx >= 5 then
        ShowStoryEndingUI()
    else
        -- 返回游戏
        gameState_ = STATE_PLAYING
        ShowPlayingUI()
    end
end

-- ============================================================================
-- 结局剧情弹窗 UI
-- ============================================================================

function ShowStoryEndingUI()
    gameState_ = STATE_STORY_ENDING

    -- 判断结局
    local endingTitle = ""
    local endingText = ""
    local endingColor = { 200, 220, 255, 255 }
    local endingImage = ""

    local endingKey = ""

    if storyExploreCount_ > 2 then
        endingTitle = "结局：最后的希望"
        endingText = "跟随信号你来到了一片残骸遍布的区域，昔日远征舰队已成漂浮废铁。就在这片悲壮的遗迹间，断断续续的生命脉冲悄然响起，于黑暗之中，留住了最后一缕希望。"
        endingColor = { 100, 255, 180, 255 }
        endingImage = "image/结局1.jpg"
        endingKey = "最后的希望"
    elseif storyBroadcastCount_ > 2 then
        endingTitle = "结局：黑暗森林"
        endingText = "你反复广播的坐标穿透了黑暗森林的迷雾。高能粒子束如猎枪般精准袭来，舰体在熵增的烈焰中崩解为原子尘埃。没有遗言，没有回响，只有冰冷的宇宙会记住：一旦暴露，便只有毁灭。"
        endingColor = { 255, 80, 80, 255 }
        endingImage = "image/结局2.jpg"
        endingKey = "黑暗森林"
    elseif storyRepairCount_ > 2 then
        endingTitle = "结局：故土尘埃"
        endingText = "你循着星图，终于落至 U546 号灰蓝色星球。轨道之上，废弃航天器缠绕成锈蚀星环，大陆皲裂如旧伤，蔚蓝早已蒙尘。所有频段只剩白噪音，没有应答，没有生命。这颗熟悉又陌生的星球，在黑暗中静静旋转，只留无尽猜想。"
        endingColor = { 150, 180, 220, 255 }
        endingImage = "image/结局3.jpg"
        endingKey = "故土尘埃"
    else
        endingTitle = "结局：新生"
        endingText = "黑洞的恐怖引力牢牢攫住飞船，身躯濒临彻底瓦解，意识沉沦之际，一片缥缈乐园骤然映入视野，真切触手可及，却又处处透着虚妄。越过黑洞视界，混沌骤然消散。飞船平稳抵达一颗宜居星球，船员依次走下舷梯，摘下头盔，呼吸着澄澈的新生空气，人类全新的文明，自此破土启程。"
        endingColor = { 255, 220, 100, 255 }
        endingImage = "image/结局4.jpg"
        endingKey = "新生"
    end

    -- 播放对应结局BGM
    PlayEndingBGM(endingKey)

    -- 结局音乐按钮
    endingMusicBtn_ = UI.Label {
        text = endingBgmEnabled_ and "🔊" or "🔇",
        fontSize = 22,
        fontColor = endingBgmEnabled_ and { 120, 220, 255, 220 } or { 120, 120, 140, 150 },
        textAlign = "center",
    }

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 5, 235 },
        children = {
            -- 左上角结局音乐按钮
            UI.Panel {
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
                onClick = function()
                    ToggleEndingBGM()
                end,
                children = { endingMusicBtn_ },
            },
            UI.Panel {
                width = "88%",
                maxWidth = 560,
                maxHeight = "92%",
                backgroundColor = { 8, 12, 28, 245 },
                borderRadius = 16,
                borderWidth = 1,
                borderColor = { 80, 140, 220, 100 },
                paddingTop = 28,
                paddingBottom = 28,
                paddingLeft = 28,
                paddingRight = 28,
                alignItems = "center",
                children = {
                    -- 结局标题
                    UI.Label {
                        text = endingTitle,
                        fontSize = 22,
                        fontColor = endingColor,
                        marginBottom = 16,
                        textAlign = "center",
                        width = "100%",
                    },
                    -- 结局图片区域
                    UI.Panel {
                        width = "100%",
                        height = 180,
                        borderRadius = 10,
                        marginBottom = 16,
                        backgroundImage = endingImage,
                        backgroundFit = "cover",
                        borderWidth = 1,
                        borderColor = { 60, 100, 180, 80 },
                    },
                    -- 结局文本区域
                    UI.Label {
                        text = endingText,
                        fontSize = 14,
                        fontColor = { 200, 210, 230, 230 },
                        marginBottom = 20,
                        width = "100%",
                        textAlign = "center",
                        whiteSpace = "normal",
                        lineHeight = 1.8,
                    },
                    -- 记录摘要
                    UI.Label {
                        text = string.format("修复: %d | 探索: %d | 广播: %d | 得分: %d",
                            storyRepairCount_, storyExploreCount_, storyBroadcastCount_, score_),
                        fontSize = 12,
                        fontColor = { 120, 140, 170, 160 },
                        marginBottom = 20,
                        textAlign = "center",
                        width = "100%",
                    },
                    UI.Panel {
                        width = 200,
                        height = 52,
                        backgroundColor = { 10, 30, 60, 180 },
                        borderRadius = 12,
                        borderWidth = 2,
                        borderColor = { 80, 200, 255, 200 },
                        justifyContent = "center",
                        alignItems = "center",
                        pointerEvents = "auto",
                        onClick = function()
                            ReturnToMenu()
                        end,
                        children = {
                            UI.Label {
                                id = "endingBtn",
                                text = "重新航行",
                                fontSize = 20,
                                fontColor = { 120, 220, 255, 255 },
                                textAlign = "center",
                                letterSpacing = 4,
                            },
                        },
                    },
                }
            },
        }
    }
    UI.SetRoot(root)
end

-- ============================================================================
-- 预缓存材质初始化
-- ============================================================================

function InitCachedMaterials()
    -- 预缓存常用模型引用
    mdlBox_ = cache:GetResource("Model", "Models/Box.mdl")
    mdlSphere_ = cache:GetResource("Model", "Models/Sphere.mdl")
    mdlCylinder_ = cache:GetResource("Model", "Models/Cylinder.mdl")

    local pbrNoTex = cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml")
    local pbrNoTexAlpha = cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml")

    -- === 护盾脉冲材质 ===
    shieldPulseMat_ = Material:new()
    shieldPulseMat_:SetTechnique(0, pbrNoTexAlpha)
    shieldPulseMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.7, 1.0, 0.08)))
    shieldPulseMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8, 2.0, 5.0)))
    shieldPulseMat_:SetShaderParameter("Metallic", Variant(0.0))
    shieldPulseMat_:SetShaderParameter("Roughness", Variant(1.0))

    -- === 子弹材质（共享） ===
    bulletCoreMat_ = Material:new()
    bulletCoreMat_:SetTechnique(0, pbrNoTex)
    bulletCoreMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 1.0, 0.9, 1.0)))
    bulletCoreMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(1.5, 3.5, 2.0)))
    bulletCoreMat_:SetShaderParameter("Metallic", Variant(0.0))
    bulletCoreMat_:SetShaderParameter("Roughness", Variant(0.0))

    bulletGlowMat_ = Material:new()
    bulletGlowMat_:SetTechnique(0, pbrNoTexAlpha)
    bulletGlowMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.9, 0.5, 0.25)))
    bulletGlowMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.4, 1.8, 0.8)))
    bulletGlowMat_:SetShaderParameter("Metallic", Variant(0.0))
    bulletGlowMat_:SetShaderParameter("Roughness", Variant(0.0))

    for i = 1, 5 do
        local fade = 1.0 - (i / 6)
        local tMat = Material:new()
        tMat:SetTechnique(0, pbrNoTexAlpha)
        tMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.8, 0.4, 0.2 * fade)))
        tMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3 * fade, 1.5 * fade, 0.6 * fade)))
        tMat:SetShaderParameter("Metallic", Variant(0.0))
        tMat:SetShaderParameter("Roughness", Variant(0.0))
        bulletTrailMats_[i] = tMat
    end

    bulletTipMat_ = Material:new()
    bulletTipMat_:SetTechnique(0, pbrNoTex)
    bulletTipMat_:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 1.0)))
    bulletTipMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(2.0, 4.0, 2.5)))
    bulletTipMat_:SetShaderParameter("Metallic", Variant(0.0))
    bulletTipMat_:SetShaderParameter("Roughness", Variant(0.0))

    -- === 爆炸材质（共享基础版本，SpawnExplosion 仍需按颜色克隆） ===
    explosionRayMat_ = Material:new()
    explosionRayMat_:SetTechnique(0, pbrNoTexAlpha)
    explosionRayMat_:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.85, 0.4, 0.95)))
    explosionRayMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(9.0, 3.5, 0.6)))
    explosionRayMat_:SetShaderParameter("Metallic", Variant(0.0))
    explosionRayMat_:SetShaderParameter("Roughness", Variant(0.0))

    explosionDebrisMat_ = Material:new()
    explosionDebrisMat_:SetTechnique(0, pbrNoTex)
    explosionDebrisMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.15, 0.08, 1.0)))
    explosionDebrisMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(1.8, 0.4, 0.0)))
    explosionDebrisMat_:SetShaderParameter("Metallic", Variant(0.2))
    explosionDebrisMat_:SetShaderParameter("Roughness", Variant(0.85))

    -- 爆炸光球基础材质（预缓存，避免每次 cache:GetResource）
    explosionGlowBaseMat_ = cache:GetResource("Material", "Materials/DefaultGrey.xml")

    -- === 水晶材质（3色） ===
    local crystalColors = {
        { 0.2, 1.0, 0.4 },
        { 0.3, 0.6, 1.0 },
        { 1.0, 0.8, 0.2 },
    }
    for idx, c in ipairs(crystalColors) do
        local mat = Material:new()
        mat:SetTechnique(0, pbrNoTexAlpha)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(c[1], c[2], c[3], 0.7)))
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(c[1] * 2.5, c[2] * 2.5, c[3] * 2.5)))
        mat:SetShaderParameter("Metallic", Variant(0.95))
        mat:SetShaderParameter("Roughness", Variant(0.02))
        crystalMats_[idx] = mat
    end

    -- === 小行星材质（6种岩石色调，50%金属矿物感） ===
    local colorPresets = {
        { 0.165, 0.145, 0.12 },
        { 0.235, 0.20, 0.165 },
        { 0.12, 0.12, 0.14 },
        { 0.20, 0.185, 0.145 },
        { 0.095, 0.08, 0.075 },
        { 0.27, 0.215, 0.135 },
    }
    for idx, c in ipairs(colorPresets) do
        local mat = Material:new()
        mat:SetTechnique(0, pbrNoTex)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(c[1], c[2], c[3], 1.0)))
        mat:SetShaderParameter("Metallic", Variant(0.38))
        mat:SetShaderParameter("Roughness", Variant(0.64))
        asteroidRockMats_[idx] = mat

        -- 对应碎石材质（稍微偏色）
        local dMat = Material:new()
        dMat:SetTechnique(0, pbrNoTex)
        dMat:SetShaderParameter("MatDiffColor", Variant(Color(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85, 1.0)))
        dMat:SetShaderParameter("Metallic", Variant(0.29))
        dMat:SetShaderParameter("Roughness", Variant(0.73))
        asteroidDebrisMats_[idx] = dMat
    end

    -- 熔岩裂缝材质
    asteroidCrackMat_ = Material:new()
    asteroidCrackMat_:SetTechnique(0, pbrNoTex)
    asteroidCrackMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.5, 0.15, 0.02, 1.0)))
    asteroidCrackMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(2.0, 0.5, 0.05)))
    asteroidCrackMat_:SetShaderParameter("Metallic", Variant(0.0))
    asteroidCrackMat_:SetShaderParameter("Roughness", Variant(0.95))

    -- 冰晶矿脉材质
    asteroidOreMat_ = Material:new()
    asteroidOreMat_:SetTechnique(0, pbrNoTex)
    asteroidOreMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.3, 0.5, 1.0)))
    asteroidOreMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3, 0.7, 1.5)))
    asteroidOreMat_:SetShaderParameter("Metallic", Variant(0.6))
    asteroidOreMat_:SetShaderParameter("Roughness", Variant(0.2))

    -- === 星尘共享材质 ===
    starDustMat_ = Material:new()
    starDustMat_:SetTechnique(0, pbrNoTex)
    starDustMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.75, 0.75, 0.75, 1.0)))
    starDustMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(1.5, 1.5, 1.5)))
    starDustMat_:SetShaderParameter("Metallic", Variant(0.0))
    starDustMat_:SetShaderParameter("Roughness", Variant(1.0))

    -- === 航道外装饰陨石共享材质（暗色，无自发光） ===
    decoAsteroidMat_ = Material:new()
    decoAsteroidMat_:SetTechnique(0, pbrNoTex)
    decoAsteroidMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.12, 0.10, 0.09, 1.0)))
    decoAsteroidMat_:SetShaderParameter("Metallic", Variant(0.3))
    decoAsteroidMat_:SetShaderParameter("Roughness", Variant(0.8))

    -- === 流星自发光材质（亮白微蓝，强自发光） ===
    meteorMat_ = Material:new()
    meteorMat_:SetTechnique(0, pbrNoTex)
    meteorMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.6, 0.7, 0.9, 1.0)))
    meteorMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(3.0, 3.5, 5.0)))
    meteorMat_:SetShaderParameter("Metallic", Variant(0.0))
    meteorMat_:SetShaderParameter("Roughness", Variant(1.0))
end

-- ============================================================================
-- 场景创建
-- ============================================================================

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 夜晚光照
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/DarkNight.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    local zone = lightGroup:GetComponent("Zone", true)
    zone.fogStart = 80
    zone.fogEnd = 400
    zone.fogColor = Color(0.02, 0.015, 0.05, 1.0)
    zone_ = zone  -- 保存引用供动画使用
    zone.ambientColor = Color(0.35, 0.35, 0.55)

    -- 星云背景（大面片，陨石飞来方向）
    local nebulaNode = scene_:CreateChild("Nebula")
    nebulaNode.position = Vector3(0, 5, 280)
    nebulaNode.scale = Vector3(200, 140, 1)
    local nebulaMat = Material:new()
    nebulaMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml"))
    nebulaMat:SetTexture(TU_DIFFUSE, cache:GetResource("Texture2D", "image/R.jpg"))
    nebulaMat:SetShaderParameter("MatDiffColor", Variant(Color(2.0, 1.8, 2.2, 1.0)))
    local nebulaModel = nebulaNode:CreateComponent("StaticModel")
    nebulaModel:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
    nebulaModel:SetMaterial(nebulaMat)
    nebulaNode.rotation = Quaternion(90, Vector3.RIGHT)

    -- 摄像机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 0.2, -4.5)
    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 600.0
    camera.fov = 70.0
    -- 音频监听器（确保音频正常输出）
    cameraNode_:CreateComponent("SoundListener")
    audio.listener = cameraNode_:GetComponent("SoundListener")

    -- 左上角光照效果（模拟恒星光源）
    local ulLightNode = cameraNode_:CreateChild("UpperLeftGlow")
    ulLightNode.position = Vector3(-3.5, 2.5, 8.0)
    local ulLight = ulLightNode:CreateComponent("Light")
    ulLight.lightType = LIGHT_POINT
    ulLight.color = Color(1.0, 0.9, 0.7)
    ulLight.brightness = 3.5
    ulLight.range = 18.0
    ulLight.specularIntensity = 0.6

    -- 主聚光灯（从相机方向照亮飞船和前方物体）
    local glowNode = cameraNode_:CreateChild("CenterSpot")
    glowNode.position = Vector3(0, 0, 0)
    glowNode.rotation = Quaternion(0, 0, 0)
    local spotLight = glowNode:CreateComponent("Light")
    spotLight.lightType = LIGHT_SPOT
    spotLight.color = Color(0.85, 0.9, 1.0)
    spotLight.brightness = 4.0
    spotLight.range = 300
    spotLight.fov = 55.0
    spotLight.specularIntensity = 0.3

    -- 暖色背光（从前方照向飞船背面，模拟爆炸/星光逆光）
    local backLightNode = scene_:CreateChild("BackLight")
    backLightNode.position = Vector3(0, 3, 60)
    backLightNode.rotation = Quaternion(175, Vector3.RIGHT)
    local backLight = backLightNode:CreateComponent("Light")
    backLight.lightType = LIGHT_DIRECTIONAL
    backLight.color = Color(1.0, 0.6, 0.25)
    backLight.brightness = 1.2
    backLight.specularIntensity = 0.8

    -- 顶部冷蓝补光（增加层次感）
    local topLightNode = scene_:CreateChild("TopFill")
    topLightNode.rotation = Quaternion(60, Vector3.RIGHT)
    local topLight = topLightNode:CreateComponent("Light")
    topLight.lightType = LIGHT_DIRECTIONAL
    topLight.color = Color(0.4, 0.5, 0.9)
    topLight.brightness = 0.6
    topLight.specularIntensity = 0.1

    -- 边缘高光（左后方 rim light）
    local rimLeftNode = scene_:CreateChild("RimLeft")
    rimLeftNode.rotation = Quaternion(160, Vector3.UP) * Quaternion(10, Vector3.RIGHT)
    local rimLeft = rimLeftNode:CreateComponent("Light")
    rimLeft.lightType = LIGHT_DIRECTIONAL
    rimLeft.color = Color(0.6, 0.75, 1.0)
    rimLeft.brightness = 1.8
    rimLeft.specularIntensity = 2.5

    -- 边缘高光（右后方 rim light）
    local rimRightNode = scene_:CreateChild("RimRight")
    rimRightNode.rotation = Quaternion(-160, Vector3.UP) * Quaternion(10, Vector3.RIGHT)
    local rimRight = rimRightNode:CreateComponent("Light")
    rimRight.lightType = LIGHT_DIRECTIONAL
    rimRight.color = Color(0.6, 0.75, 1.0)
    rimRight.brightness = 1.8
    rimRight.specularIntensity = 2.5

    -- 平滑环境补光（正前方偏下，柔和照亮所有陨石表面）
    local frontFillNode = scene_:CreateChild("FrontFill")
    frontFillNode.rotation = Quaternion(-15, Vector3.RIGHT)
    local frontFill = frontFillNode:CreateComponent("Light")
    frontFill.lightType = LIGHT_DIRECTIONAL
    frontFill.color = Color(0.5, 0.55, 0.7)
    frontFill.brightness = 0.8
    frontFill.specularIntensity = 0.05

    -- 底部暖色反弹光（模拟星云反射的漫射光）
    local bottomBounceNode = scene_:CreateChild("BottomBounce")
    bottomBounceNode.rotation = Quaternion(-130, Vector3.RIGHT)
    local bottomBounce = bottomBounceNode:CreateComponent("Light")
    bottomBounce.lightType = LIGHT_DIRECTIONAL
    bottomBounce.color = Color(0.4, 0.3, 0.5)
    bottomBounce.brightness = 0.5
    bottomBounce.specularIntensity = 0.0

    -- 侧面柔光（从左侧45°照入，增加立体感过渡）
    local sideFillNode = scene_:CreateChild("SideFill")
    sideFillNode.rotation = Quaternion(45, Vector3.UP) * Quaternion(20, Vector3.RIGHT)
    local sideFill = sideFillNode:CreateComponent("Light")
    sideFill.lightType = LIGHT_DIRECTIONAL
    sideFill.color = Color(0.45, 0.5, 0.65)
    sideFill.brightness = 0.6
    sideFill.specularIntensity = 0.1

    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
    renderer.hdrRendering = true

    -- 后效：Bloom 泛光
    local renderPath = viewport:GetRenderPath()
    renderPath:Append(cache:GetResource("XMLFile", "PostProcess/Bloom.xml"))
    renderPath:SetShaderParameter("BloomMix", Variant(Vector2(1.0, 0.8)))
    renderPath:SetShaderParameter("BloomThreshold", Variant(0.6))
end

-- ============================================================================
-- 飞船创建
-- ============================================================================

function CreateShip()
    shipNode_ = scene_:CreateChild("Ship")
    shipNode_.position = Vector3(0, 0, 0)

    -- 材质工具
    local function MakeHullMat(r, g, b, metallic, roughness)
        local m = Material:new()
        m:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        m:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, 1.0)))
        m:SetShaderParameter("Metallic", Variant(metallic))
        m:SetShaderParameter("Roughness", Variant(roughness))
        return m
    end
    local function MakeGlowMat(r, g, b, er, eg, eb)
        local m = Material:new()
        m:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        m:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, 1.0)))
        m:SetShaderParameter("MatEmissiveColor", Variant(Color(er, eg, eb)))
        m:SetShaderParameter("Metallic", Variant(0.0))
        m:SetShaderParameter("Roughness", Variant(0.2))
        return m
    end

    -- 多边形辅助：三角面片添加
    local function AddTri(geom, p1, p2, p3, normal)
        geom:DefineVertex(p1); geom:DefineNormal(normal); geom:DefineTexCoord(Vector2(0, 0))
        geom:DefineVertex(p2); geom:DefineNormal(normal); geom:DefineTexCoord(Vector2(1, 0))
        geom:DefineVertex(p3); geom:DefineNormal(normal); geom:DefineTexCoord(Vector2(0, 1))
    end
    -- 计算面法线
    local function FaceNormal(p1, p2, p3)
        local e1 = p2 - p1
        local e2 = p3 - p1
        return e1:CrossProduct(e2):Normalized()
    end
    -- 四边形（两个三角面）
    local function AddQuad(geom, p1, p2, p3, p4)
        local n = FaceNormal(p1, p2, p3)
        AddTri(geom, p1, p2, p3, n)
        AddTri(geom, p1, p3, p4, n)
    end

    -- 六边形贴面灯（CustomGeometry，贴合飞船表面）
    -- pos: 位置, normal: 表面法线方向, radius: 半径, mat: 材质, parent: 父节点
    local function CreateHexLight(parent, name, pos, normal, radius, mat)
        local node = parent:CreateChild(name)
        node.position = pos
        local geom = node:CreateComponent("CustomGeometry")
        geom:BeginGeometry(0, TRIANGLE_LIST)
        -- 计算六边形所在平面的切线/副切线
        local up = (math_abs(normal.y) < 0.99) and Vector3.UP or Vector3.RIGHT
        local tangent = normal:CrossProduct(up):Normalized()
        local bitangent = tangent:CrossProduct(normal):Normalized()
        -- 六边形6个顶点
        local hexPts = {}
        for i = 0, 5 do
            local angle = (i / 6) * math_pi * 2
            local dx = math_cos(angle) * radius
            local dy = math_sin(angle) * radius
            hexPts[i + 1] = tangent * dx + bitangent * dy
        end
        -- 正面6个三角形（扇形）
        local center = Vector3(0, 0, 0)
        for i = 1, 6 do
            local i2 = (i % 6) + 1
            AddTri(geom, center, hexPts[i], hexPts[i2], normal)
        end
        -- 背面（微偏移，双面可见）
        local backOff = normal * (-0.002)
        local backN = normal * (-1)
        for i = 1, 6 do
            local i2 = (i % 6) + 1
            AddTri(geom, backOff, hexPts[i2] + backOff, hexPts[i] + backOff, backN)
        end
        geom:Commit()
        geom:SetMaterial(mat)
        geom.castShadows = false
        return node
    end

    -- ========== 材质库 ==========
    local hullMain = MakeHullMat(0.09, 0.10, 0.13, 0.95, 0.12)       -- 主装甲 (50%增强)
    local hullLight = MakeHullMat(0.20, 0.22, 0.26, 0.90, 0.10)      -- 浅色面板 (50%增强)
    local hullDark = MakeHullMat(0.025, 0.025, 0.045, 0.96, 0.23)    -- 暗结构 (50%增强)
    local hullAccent = MakeHullMat(0.125, 0.145, 0.185, 0.92, 0.16)  -- 面板点缀 (50%增强)
    local cockpitMat = MakeGlowMat(0.01, 0.06, 0.18, 0.12, 0.35, 1.0)
    local engineGlow = MakeGlowMat(0.1, 0.4, 1.0, 0.8, 1.5, 4.0)
    local energyLine = MakeGlowMat(0.0, 0.6, 1.0, 0.0, 0.8, 2.2)
    local warnMat = MakeGlowMat(1.0, 0.4, 0.0, 1.8, 0.6, 0.0)
    local reactorMat = MakeGlowMat(0.2, 0.5, 1.0, 0.5, 1.5, 4.0)
    local shieldEmit = MakeGlowMat(0.1, 0.3, 0.8, 0.2, 0.6, 2.0)

    -- ================================================================
    -- 主机身 - 高多边形流线建模（12边截面 × 10段，消除断裂感）
    -- ================================================================
    local hullNode = shipNode_:CreateChild("Hull")
    local hullGeom = hullNode:CreateComponent("CustomGeometry")
    hullGeom:BeginGeometry(0, TRIANGLE_LIST)

    -- 生成12边形截面轮廓（椭圆近似，上凸下平，可按段参数化变形）
    -- params: w=半宽, hTop=顶高, hBot=底深, flatness=底部平坦度(0~1)
    local function MakeSection12(z, w, hTop, hBot, flatness)
        local pts = {}
        local n = 12
        for i = 0, n - 1 do
            local angle = (i / n) * math_pi * 2  -- 从顶部0度开始
            local rawX = math_sin(angle)
            local rawY = math_cos(angle)
            -- 上半椭圆用hTop，下半用hBot，底部压扁
            local px, py
            px = rawX * w
            if rawY >= 0 then
                py = rawY * hTop
            else
                -- 底部压扁效果：混合圆弧和平面
                py = rawY * hBot * (1.0 - flatness * 0.5 * (1 + rawY))
            end
            pts[i + 1] = Vector3(px, py, z)
        end
        return pts
    end

    -- 10个截面，从机首到机尾平滑过渡
    local sections = {
        MakeSection12(1.70, 0.015, 0.015, 0.015, 0),    -- #1 极尖鼻锥
        MakeSection12(1.45, 0.05,  0.04,  0.03,  0),    -- #2 鼻锥扩张
        MakeSection12(1.15, 0.14,  0.07,  0.07,  0.2),  -- #3 前段渐宽
        MakeSection12(0.80, 0.22,  0.11,  0.09,  0.3),  -- #4 座舱前
        MakeSection12(0.45, 0.28,  0.14,  0.12,  0.4),  -- #5 座舱区
        MakeSection12(0.05, 0.34,  0.15,  0.14,  0.5),  -- #6 最宽肩部
        MakeSection12(-0.30, 0.32, 0.14,  0.13,  0.4),  -- #7 肩后过渡
        MakeSection12(-0.60, 0.25, 0.12,  0.10,  0.3),  -- #8 收腰段
        MakeSection12(-0.90, 0.18, 0.10,  0.08,  0.2),  -- #9 引擎过渡
        MakeSection12(-1.15, 0.13, 0.08,  0.07,  0.1),  -- #10 尾端
    }

    -- 连接相邻截面形成船体（平滑法线：用相邻顶点近似顶点法线）
    for s = 1, #sections - 1 do
        local cur = sections[s]
        local nxt = sections[s + 1]
        local n = #cur
        for i = 1, n do
            local i2 = (i % n) + 1
            -- 计算近似平滑法线（取四边形中心到外的方向）
            local center = (cur[i] + cur[i2] + nxt[i] + nxt[i2]) * 0.25
            local outDir = Vector3(center.x, center.y, 0):Normalized()
            if outDir:Length() < 0.01 then outDir = Vector3.UP end
            AddQuad(hullGeom, cur[i], nxt[i], nxt[i2], cur[i2])
        end
    end

    -- 封闭前端面（扇形细分）
    local frontPts = sections[1]
    local frontCenter = Vector3(0, 0, frontPts[1].z)
    local nFront = Vector3(0, 0, 1)
    for i = 1, #frontPts do
        local i2 = (i % #frontPts) + 1
        AddTri(hullGeom, frontCenter, frontPts[i], frontPts[i2], nFront)
    end

    -- 封闭后端面
    local backPts = sections[#sections]
    local backCenter = Vector3(0, 0, backPts[1].z)
    local nBack = Vector3(0, 0, -1)
    for i = 1, #backPts do
        local i2 = (i % #backPts) + 1
        AddTri(hullGeom, backCenter, backPts[i2], backPts[i], nBack)
    end

    hullGeom:Commit()
    hullGeom:SetMaterial(hullMain)
    hullGeom.castShadows = true

    -- ================================================================
    -- 座舱顶盖 - 多边形平面板罩（仿战斗机多面体座舱盖）
    -- ================================================================
    local canopyNode = shipNode_:CreateChild("Canopy")
    local canopyGeom = canopyNode:CreateComponent("CustomGeometry")
    canopyGeom:BeginGeometry(0, TRIANGLE_LIST)

    -- 多边形座舱盖：4纵段 × 3横面（左斜面、顶面、右斜面），每面是平板
    -- 形成有明显棱角的多面体罩子
    local cBaseY = 0.11
    -- 纵向关键截面（z位置, 半宽, 顶高）
    local canopyProfiles = {
        { z = 0.98, w = 0.04, h = 0.02 },  -- 最前端（尖锥）
        { z = 0.78, w = 0.10, h = 0.08 },  -- 前段展开
        { z = 0.55, w = 0.15, h = 0.13 },  -- 中段最高
        { z = 0.35, w = 0.16, h = 0.12 },  -- 后段
        { z = 0.18, w = 0.14, h = 0.06 },  -- 尾缘（矮平，过渡到机身）
    }

    -- 每个截面生成5个关键点：左下、左上、顶、右上、右下
    local canopyVerts = {}
    for i, p in ipairs(canopyProfiles) do
        canopyVerts[i] = {
            Vector3(-p.w, cBaseY, p.z),                        -- 1: 左下
            Vector3(-p.w * 0.65, cBaseY + p.h * 0.7, p.z),    -- 2: 左上
            Vector3(0, cBaseY + p.h, p.z),                     -- 3: 顶中
            Vector3(p.w * 0.65, cBaseY + p.h * 0.7, p.z),     -- 4: 右上
            Vector3(p.w, cBaseY, p.z),                         -- 5: 右下
        }
    end

    -- 连接相邻截面的对应面板（形成平面多边形）
    for s = 1, #canopyVerts - 1 do
        local cur = canopyVerts[s]
        local nxt = canopyVerts[s + 1]
        -- 每对相邻点连成四边形面板
        for f = 1, 4 do
            AddQuad(canopyGeom, cur[f], nxt[f], nxt[f + 1], cur[f + 1])
        end
    end

    -- 前端封面（三角形收拢到尖点）
    local frontV = canopyVerts[1]
    local fCenter = Vector3(0, cBaseY + canopyProfiles[1].h * 0.5, canopyProfiles[1].z + 0.03)
    for f = 1, 4 do
        local n = FaceNormal(fCenter, frontV[f], frontV[f + 1])
        AddTri(canopyGeom, fCenter, frontV[f], frontV[f + 1], n)
    end

    -- 后端封面
    local backV = canopyVerts[#canopyVerts]
    local bCenter = Vector3(0, cBaseY + canopyProfiles[#canopyProfiles].h * 0.3, canopyProfiles[#canopyProfiles].z - 0.02)
    for f = 1, 4 do
        local n = FaceNormal(bCenter, backV[f + 1], backV[f])
        AddTri(canopyGeom, bCenter, backV[f + 1], backV[f], n)
    end

    canopyGeom:Commit()
    canopyGeom:SetMaterial(cockpitMat)

    -- 座舱框架棱线（沿纵向截面轮廓，用细条模拟金属框架）
    for i, verts in ipairs(canopyVerts) do
        -- 顶部纵向棱脊（连接各段顶点）
        if i < #canopyVerts then
            local nxtVerts = canopyVerts[i + 1]
            -- 顶脊线
            local ribTop = shipNode_:CreateChild("CRibT")
            local midZ = (verts[3].z + nxtVerts[3].z) * 0.5
            local midY = (verts[3].y + nxtVerts[3].y) * 0.5
            local lenZ = math_abs(verts[3].z - nxtVerts[3].z)
            ribTop.position = Vector3(0, midY + 0.003, midZ)
            ribTop.scale = Vector3(0.008, 0.008, lenZ)
            local rtM = ribTop:CreateComponent("StaticModel")
            rtM:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            rtM:SetMaterial(hullDark)
        end
        -- 横向框架（每段截面处的环形框架线）
        if i >= 2 and i <= #canopyVerts - 1 then
            for f = 1, 4 do
                local p1 = verts[f]
                local p2 = verts[f + 1]
                local mx = (p1.x + p2.x) * 0.5
                local my = (p1.y + p2.y) * 0.5
                local mz = (p1.z + p2.z) * 0.5
                local dx = p2.x - p1.x
                local dy = p2.y - p1.y
                local segLen = math_sqrt(dx * dx + dy * dy)
                local rib = shipNode_:CreateChild("CRibH")
                rib.position = Vector3(mx, my + 0.003, mz)
                local angle = math_deg(math_atan(dy, dx))
                rib.rotation = Quaternion(angle, Vector3.FORWARD)
                rib.scale = Vector3(segLen, 0.006, 0.006)
                local rM = rib:CreateComponent("StaticModel")
                rM:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
                rM:SetMaterial(hullDark)
            end
        end
    end

    -- ================================================================
    -- 主翼 - 多截面翼型（6段展向 × 翼型轮廓，消除平板感）
    -- ================================================================
    for side = -1, 1, 2 do
        local wingNode = shipNode_:CreateChild("Wing")
        local wGeom = wingNode:CreateComponent("CustomGeometry")
        wGeom:BeginGeometry(0, TRIANGLE_LIST)

        -- 6段展向截面，从翼根到翼尖渐变
        local wSegs = 6
        -- 翼型参数随展向变化
        local function WingSection(t)
            -- t: 0=翼根（深入机身内部）, 1=翼尖
            local span = 0.18 + t * 1.37   -- 翼根从X=0.18开始，深入机身内部（机身宽约0.34）
            local dropY = -0.03 * t          -- 翼尖微下垂
            local chord = 0.75 - t * 0.25    -- 翼根弦长更大，深入范围更广
            -- 翼根厚实，向翼尖快速收薄（指数衰减）
            local thick = 0.035 + 0.045 * (1.0 - t) * (1.0 - t)  -- 翼根0.08，翼尖0.035
            local sweep = -0.15 * t          -- 后掠偏移
            local zFront = 0.15 + sweep
            local zBack = zFront - chord
            -- 翼型6点轮廓（NACA类椭圆翼型近似）
            local pts = {}
            local nPts = 8  -- 翼型轮廓点数
            for i = 0, nPts - 1 do
                local a = (i / nPts) * math_pi * 2
                local cx = math_cos(a) * 0.5  -- -0.5~0.5 弦向
                local cy = math_sin(a)        -- 翼型厚度
                -- 上厚下薄的翼型修正
                if cy > 0 then cy = cy * 1.0 else cy = cy * 0.5 end
                local pz = zFront + (zBack - zFront) * (cx + 0.5)
                local py = dropY + cy * thick
                pts[i + 1] = Vector3(side * span, py, pz)
            end
            return pts
        end

        -- 生成各截面
        local wingSections = {}
        for i = 0, wSegs do
            wingSections[i] = WingSection(i / wSegs)
        end

        -- 连接相邻截面
        for s = 0, wSegs - 1 do
            local cur = wingSections[s]
            local nxt = wingSections[s + 1]
            local n = #cur
            for i = 1, n do
                local i2 = (i % n) + 1
                AddQuad(wGeom, cur[i], nxt[i], nxt[i2], cur[i2])
            end
        end

        -- 封闭翼根（深入机身内部，封面朝内）
        local rootPts = wingSections[0]
        local rootC = Vector3(side * 0.18, 0, -0.2)
        for i = 1, #rootPts do
            local i2 = (i % #rootPts) + 1
            local n = FaceNormal(rootC, rootPts[i2], rootPts[i])
            AddTri(wGeom, rootC, rootPts[i2], rootPts[i], n)
        end

        -- 封闭翼尖
        local tipPts = wingSections[wSegs]
        local tipC = Vector3(side * 1.55, -0.03, -0.45)
        for i = 1, #tipPts do
            local i2 = (i % #tipPts) + 1
            local n = FaceNormal(tipC, tipPts[i], tipPts[i2])
            AddTri(wGeom, tipC, tipPts[i], tipPts[i2], n)
        end

        wGeom:Commit()
        wGeom:SetMaterial(hullMain)
        wGeom.castShadows = true

        -- 翼面能量脊（发光条）
        local spine = shipNode_:CreateChild("WSpine")
        spine.position = Vector3(side * 0.8, 0.035, -0.2)
        spine.scale = Vector3(0.7, 0.012, 0.025)
        local spM = spine:CreateComponent("StaticModel")
        spM:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        spM:SetMaterial(energyLine)

        -- 翼端导航灯（六边形贴面，法线朝翼尖外侧）
        local navNormal = Vector3(side, -0.1, 0):Normalized()
        local navMat = side < 0 and MakeGlowMat(1,0,0, 2.5,0.2,0) or MakeGlowMat(0,1,0, 0.2,2.5,0.2)
        CreateHexLight(shipNode_, "NavL", Vector3(side * 1.55, -0.02, -0.45), navNormal, 0.035, navMat)
    end

    -- ================================================================
    -- 垂直双尾翼 - 从机身表面平滑延伸（6段高度，底部宽基座融入机身）
    -- ================================================================
    for side = -1, 1, 2 do
        local tailNode = shipNode_:CreateChild("VTail")
        local tGeom = tailNode:CreateComponent("CustomGeometry")
        tGeom:BeginGeometry(0, TRIANGLE_LIST)

        -- 6段高度截面（底→顶）
        -- 底部（t=0）是宽扁基座，完全贴合机身顶面
        -- 逐渐收窄变高，形成翼面
        local tSegs = 6
        local function TailSection(t)
            -- t: 0=底（深入机身内部）, 1=顶端
            local baseX = side * (0.12 + t * 0.16)  -- 底部更靠近中心，深入机身
            -- 底部Y设为-0.02，深入机身内部（机身顶面约Y=0.10~0.12）
            -- 这样底部完全被机身包裹，不会出现缝隙
            local baseY = -0.02 + t * 0.54
            -- 底部弦长更大，覆盖范围更广（深入机身内部）
            local chord = (0.65 - t * 0.35)  -- 0.65→0.30 弦长
            local thick = 0.04 * (1.0 - t * 0.6) -- 底部更厚
            -- 底部前后范围更大，深入机身
            local zFront = -0.45 + t * (-0.20)
            local zBack = zFront - chord
            local pts = {}
            local nPts = 8
            for i = 0, nPts - 1 do
                local a = (i / nPts) * math_pi * 2
                local cx = math_cos(a) * 0.5
                local cy = math_sin(a)
                -- 底部完全压扁（深入机身时不要有底部凸出）
                local flatFactor = 1.0 - (1.0 - t) * 0.7
                if cy < 0 then cy = cy * flatFactor end
                local pz = zFront + (zBack - zFront) * (cx + 0.5)
                local px = baseX + cy * thick * side
                pts[i + 1] = Vector3(px, baseY, pz)
            end
            return pts
        end

        local tailSections = {}
        for i = 0, tSegs do
            tailSections[i] = TailSection(i / tSegs)
        end

        -- 连接截面
        for s = 0, tSegs - 1 do
            local cur = tailSections[s]
            local nxt = tailSections[s + 1]
            local n = #cur
            for i = 1, n do
                local i2 = (i % n) + 1
                AddQuad(tGeom, cur[i], nxt[i], nxt[i2], cur[i2])
            end
        end

        -- 不封闭底端（底端深入机身内部，视觉融为一体）
        -- 仅封闭顶端
        local topPts = tailSections[tSegs]
        local topC = Vector3(side * 0.28, 0.52, -0.85)
        for i = 1, #topPts do
            local i2 = (i % #topPts) + 1
            local n = FaceNormal(topC, topPts[i], topPts[i2])
            AddTri(tGeom, topC, topPts[i], topPts[i2], n)
        end

        tGeom:Commit()
        tGeom:SetMaterial(hullAccent)
        tGeom.castShadows = true

        -- 尾翼顶灯（六边形贴面）
        local tailLampNormal = Vector3(side * 0.3, 0.95, 0):Normalized()
        CreateHexLight(shipNode_, "TLamp", Vector3(side * 0.28, 0.53, -0.88), tailLampNormal, 0.025, warnMat)
    end

    -- ================================================================
    -- 引擎舱 - 双引擎吊舱（八边形结构，仿真实飞机引擎）
    -- ================================================================
    -- 八边形截面生成器
    local function MakeOctRing(cx, cy, cz, radius, radiusY, zOff)
        local pts = {}
        for i = 0, 7 do
            local a = (i / 8) * math_pi * 2
            local px = cx + math_cos(a) * radius
            local py = cy + math_sin(a) * (radiusY or radius)
            pts[i + 1] = Vector3(px, py, cz + (zOff or 0))
        end
        return pts
    end

    for side = -1, 1, 2 do
        local ex, ey = side * 0.42, -0.05  -- 引擎中心

        -- 引擎吊舱外壳（八边形多段锥体，仿真实涡扇引擎）
        local nacNode = shipNode_:CreateChild("Nacelle")
        local nacGeom = nacNode:CreateComponent("CustomGeometry")
        nacGeom:BeginGeometry(0, TRIANGLE_LIST)

        -- 5段截面：进气唇口 → 风扇段 → 中段 → 收窄段 → 喷口
        local nacSections = {
            MakeOctRing(ex, ey, -0.32, 0.10, 0.09),   -- 进气唇口（稍大）
            MakeOctRing(ex, ey, -0.45, 0.09, 0.08),   -- 风扇段
            MakeOctRing(ex, ey, -0.70, 0.085, 0.075),  -- 中段（最粗）
            MakeOctRing(ex, ey, -0.95, 0.08, 0.07),   -- 收窄段
            MakeOctRing(ex, ey, -1.15, 0.095, 0.085),  -- 喷口外缘（略扩张）
        }
        -- 连接相邻截面
        for s = 1, #nacSections - 1 do
            local cur = nacSections[s]
            local nxt = nacSections[s + 1]
            for i = 1, 8 do
                local i2 = (i % 8) + 1
                AddQuad(nacGeom, cur[i], nxt[i], nxt[i2], cur[i2])
            end
        end
        -- 封闭进气口前面（八边形环面，中心留空模拟进气道）
        do
            local fPts = nacSections[1]
            local inF = MakeOctRing(ex, ey, -0.32, 0.05, 0.045)
            for i = 1, 8 do
                local i2 = (i % 8) + 1
                AddQuad(nacGeom, fPts[i], inF[i], inF[i2], fPts[i2])
            end
        end
        -- 封闭喷口后面（八边形环面，中心留空）
        do
            local bPts = nacSections[#nacSections]
            local inB = MakeOctRing(ex, ey, -1.15, 0.055, 0.05)
            for i = 1, 8 do
                local i2 = (i % 8) + 1
                AddQuad(nacGeom, bPts[i2], inB[i2], inB[i], bPts[i])
            end
        end
        nacGeom:Commit()
        nacGeom:SetMaterial(hullDark)
        nacGeom.castShadows = true

        -- 进气口发光环（八边形）
        local intakeNode = shipNode_:CreateChild("Intake")
        local intGeom = intakeNode:CreateComponent("CustomGeometry")
        intGeom:BeginGeometry(0, TRIANGLE_LIST)
        local intOuter = MakeOctRing(ex, ey, -0.31, 0.105, 0.095)
        local intInner = MakeOctRing(ex, ey, -0.31, 0.095, 0.085)
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            AddQuad(intGeom, intOuter[i], intInner[i], intInner[i2], intOuter[i2])
        end
        intGeom:Commit()
        intGeom:SetMaterial(energyLine)
        intGeom.castShadows = false

        -- 喷口外环（八边形加厚环，发光暗蓝色）
        local nozNode = shipNode_:CreateChild("Nozzle")
        local nozGeom = nozNode:CreateComponent("CustomGeometry")
        nozGeom:BeginGeometry(0, TRIANGLE_LIST)
        local nozOuter = MakeOctRing(ex, ey, -1.16, 0.105, 0.095)
        local nozInner = MakeOctRing(ex, ey, -1.16, 0.065, 0.06)
        local nozOuterB = MakeOctRing(ex, ey, -1.20, 0.10, 0.09)
        local nozInnerB = MakeOctRing(ex, ey, -1.20, 0.06, 0.055)
        -- 前面环
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            AddQuad(nozGeom, nozOuter[i], nozInner[i], nozInner[i2], nozOuter[i2])
        end
        -- 外侧面
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            AddQuad(nozGeom, nozOuter[i], nozOuterB[i], nozOuterB[i2], nozOuter[i2])
        end
        -- 内侧面
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            AddQuad(nozGeom, nozInner[i2], nozInnerB[i2], nozInnerB[i], nozInner[i])
        end
        -- 后面环
        for i = 1, 8 do
            local i2 = (i % 8) + 1
            AddQuad(nozGeom, nozOuterB[i2], nozInnerB[i2], nozInnerB[i], nozOuterB[i])
        end
        nozGeom:Commit()
        nozGeom:SetMaterial(hullDark)
        nozGeom.castShadows = true

        -- 引擎焰芯
        local flame = shipNode_:CreateChild("Flame")
        flame.position = Vector3(side * 0.42, -0.05, -1.24)
        flame.scale = Vector3(0.09, 0.09, 0.14)
        local flM = flame:CreateComponent("StaticModel")
        flM:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        flM:SetMaterial(engineGlow)

        -- 引擎外焰
        local flame2 = shipNode_:CreateChild("Flame2")
        flame2.position = Vector3(side * 0.42, -0.05, -1.36)
        flame2.scale = Vector3(0.06, 0.06, 0.10)
        local fl2M = flame2:CreateComponent("StaticModel")
        fl2M:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        fl2M:SetMaterial(MakeGlowMat(0.4, 0.7, 1.0, 1.0, 2.0, 5.0))

        -- 引擎光源
        local eLt = shipNode_:CreateChild("ELt")
        eLt.position = Vector3(side * 0.42, -0.05, -1.4)
        local el = eLt:CreateComponent("Light")
        el.lightType = LIGHT_POINT
        el.color = Color(0.3, 0.6, 1.0)
        el.brightness = 22
        el.range = 4.0
    end

    -- 中央辅助引擎
    local cEng = shipNode_:CreateChild("CEng")
    cEng.position = Vector3(0, -0.08, -1.05)
    cEng.scale = Vector3(0.10, 0.10, 0.40)
    local ceM = cEng:CreateComponent("StaticModel")
    ceM:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    ceM:SetMaterial(hullDark)

    local cFlame = shipNode_:CreateChild("CFlame")
    cFlame.position = Vector3(0, -0.08, -1.28)
    cFlame.scale = Vector3(0.06, 0.06, 0.08)
    local cfM = cFlame:CreateComponent("StaticModel")
    cfM:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    cfM:SetMaterial(reactorMat)

    -- ================================================================
    -- 细节装饰
    -- ================================================================
    -- 能量管线（机身侧面发光线）
    for side = -1, 1, 2 do
        local pipe = shipNode_:CreateChild("Pipe")
        pipe.position = Vector3(side * 0.26, 0.06, 0.0)
        pipe.scale = Vector3(0.012, 0.012, 1.5)
        local pM = pipe:CreateComponent("StaticModel")
        pM:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pM:SetMaterial(energyLine)
    end

    -- 反应堆核心（机腹六边形贴面发光）
    CreateHexLight(shipNode_, "Reactor", Vector3(0, -0.14, -0.2), Vector3(0, -1, 0), 0.06, reactorMat)

    local rctLight = shipNode_:CreateChild("RLight")
    rctLight.position = Vector3(0, -0.14, -0.2)
    local rl = rctLight:CreateComponent("Light")
    rl.lightType = LIGHT_POINT
    rl.color = Color(0.6, 0.7, 1.0)
    rl.brightness = 1.5
    rl.range = 0.8

    -- 武器挂点（翼下脉冲炮）
    for side = -1, 1, 2 do
        local pylon = shipNode_:CreateChild("Pylon")
        pylon.position = Vector3(side * 0.65, -0.06, 0.0)
        pylon.scale = Vector3(0.03, 0.05, 0.2)
        local pyM = pylon:CreateComponent("StaticModel")
        pyM:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pyM:SetMaterial(hullDark)

        for offset = -0.018, 0.018, 0.036 do
            local gun = shipNode_:CreateChild("Gun")
            gun.position = Vector3(side * 0.65 + offset, -0.12, 0.25)
            gun.rotation = Quaternion(90, Vector3.RIGHT)
            gun.scale = Vector3(0.015, 0.30, 0.015)
            local gM = gun:CreateComponent("StaticModel")
            gM:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
            gM:SetMaterial(hullDark)
        end

        -- 炮口光环
        local mRing = shipNode_:CreateChild("MRing")
        mRing.position = Vector3(side * 0.65, -0.12, 0.42)
        mRing.rotation = Quaternion(90, Vector3.RIGHT)
        mRing.scale = Vector3(0.03, 0.008, 0.03)
        local mrM = mRing:CreateComponent("StaticModel")
        mrM:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        mrM:SetMaterial(energyLine)
    end

    -- 护盾发生器（六边形贴面，法线朝上外侧）
    for side = -1, 1, 2 do
        local sgNormal = Vector3(side * 0.2, 0.98, 0):Normalized()
        CreateHexLight(shipNode_, "SGen", Vector3(side * 0.18, 0.15, -0.35), sgNormal, 0.035, shieldEmit)
    end

    -- 腹部散热灯（六边形贴面，法线朝下，4个排列）
    local ventMat = MakeGlowMat(0.8, 0.3, 0.0, 0.6, 0.15, 0.0)
    for i = 0, 3 do
        CreateHexLight(shipNode_, "Vent", Vector3(0, -0.14, -0.3 + i * 0.22), Vector3(0, -1, 0), 0.03, ventMat)
    end

    -- ========== 蜂巢护盾（CustomGeometry 六边形网格球面） ==========
    shieldNode_ = shipNode_:CreateChild("Shield")
    shieldNode_.position = Vector3(0, 0, 1.8)  -- 飞船正前方

    -- 前方半球六边形蜂窝护盾（镶嵌网格，边缘渐隐）
    local geom = shieldNode_:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local shieldR = 2.0       -- 半球半径
    local hexEdge = 0.38      -- 六边形边长（平面空间）
    local fadeStart = 1.7     -- 开始渐隐的平面距离
    local fadeEnd = 2.4       -- 完全消失的平面距离
    local sqrt3 = math_sqrt(3)

    -- 轴坐标(q, r) → 平面坐标(x, y)，flat-top 六边形
    local function AxialToXY(q, r)
        local x = hexEdge * (1.5 * q)
        local y = hexEdge * (sqrt3 * 0.5 * q + sqrt3 * r)
        return x, y
    end

    -- 平面坐标 → 半球面3D点（Z方向凸出）
    local function FlatToHemi(x, y)
        local dist = math_sqrt(x * x + y * y)
        local theta = math_atan(y, x)
        -- 将平面距离线性映射到半球角度 phi
        local phi = (dist / shieldR) * (math_pi * 0.5)
        local z = math_cos(phi)
        local r = math_sin(phi)
        return Vector3(
            r * math_cos(theta) * shieldR,
            r * math_sin(theta) * shieldR,
            z * shieldR
        ), dist
    end

    -- 计算透明度（基于平面距离）
    local function GetAlpha(dist)
        if dist <= fadeStart then return 1.0 end
        if dist >= fadeEnd then return 0.0 end
        return 1.0 - (dist - fadeStart) / (fadeEnd - fadeStart)
    end

    -- 绘制带透明度的线段
    local function AddLineAlpha(p1, d1, p2, d2)
        local a1 = GetAlpha(d1)
        local a2 = GetAlpha(d2)
        -- 两端都完全透明则跳过
        if a1 <= 0.01 and a2 <= 0.01 then return end
        geom:DefineVertex(p1)
        geom:DefineNormal(p1:Normalized())
        geom:DefineColor(Color(0.4, 0.75, 1.0, a1))
        geom:DefineTexCoord(Vector2(0, 0))
        geom:DefineVertex(p2)
        geom:DefineNormal(p2:Normalized())
        geom:DefineColor(Color(0.4, 0.75, 1.0, a2))
        geom:DefineTexCoord(Vector2(1, 1))
    end

    -- 六边形顶点偏移（flat-top：顶点从0°开始，间隔60°）
    local hexDirs = {}
    for i = 0, 5 do
        local angle = math_pi / 3.0 * i
        hexDirs[i] = { math_cos(angle) * hexEdge, math_sin(angle) * hexEdge }
    end

    -- 生成镶嵌六边形网格（轴坐标遍历）
    -- 覆盖足够大的范围，让超出半球的六边形能渐隐
    local gridRadius = math_ceil(fadeEnd / (hexEdge * 1.5)) + 1

    -- 记录已绘制的边，避免重复（共享边只画一次）
    local drawnEdges = {}
    local function EdgeKey(x1, y1, x2, y2)
        -- 用四舍五入避免浮点精度问题
        local k1 = string.format("%.2f,%.2f", x1, y1)
        local k2 = string.format("%.2f,%.2f", x2, y2)
        if k1 < k2 then return k1 .. "|" .. k2
        else return k2 .. "|" .. k1 end
    end

    for q = -gridRadius, gridRadius do
        for r = -gridRadius, gridRadius do
            local s = -q - r
            -- 限制在六边形范围内（立方坐标约束）
            if math_abs(q) <= gridRadius and math_abs(r) <= gridRadius and math_abs(s) <= gridRadius then
                local cx, cy = AxialToXY(q, r)
                local centerDist = math_sqrt(cx * cx + cy * cy)
                -- 太远的六边形完全不画
                if centerDist < fadeEnd + hexEdge then
                    -- 绘制该六边形的6条边
                    for i = 0, 5 do
                        local j = (i + 1) % 6
                        local vx1 = cx + hexDirs[i][1]
                        local vy1 = cy + hexDirs[i][2]
                        local vx2 = cx + hexDirs[j][1]
                        local vy2 = cy + hexDirs[j][2]

                        local key = EdgeKey(vx1, vy1, vx2, vy2)
                        if not drawnEdges[key] then
                            drawnEdges[key] = true
                            local p1, d1 = FlatToHemi(vx1, vy1)
                            local p2, d2 = FlatToHemi(vx2, vy2)
                            AddLineAlpha(p1, d1, p2, d2)
                        end
                    end
                end
            end
        end
    end

    geom:Commit()
    geom:SetMaterial(shieldPulseMat_)

    -- 护盾六边形填充面（淡蓝色25%透明）
    local fillNode = shieldNode_:CreateChild("ShieldFill")
    local fillGeom = fillNode:CreateComponent("CustomGeometry")
    fillGeom:BeginGeometry(0, TRIANGLE_LIST)

    for q = -gridRadius, gridRadius do
        for r = -gridRadius, gridRadius do
            local s = -q - r
            if math_abs(q) <= gridRadius and math_abs(r) <= gridRadius and math_abs(s) <= gridRadius then
                local cx, cy = AxialToXY(q, r)
                local centerDist = math_sqrt(cx * cx + cy * cy)
                if centerDist < fadeStart then
                    -- 完整六边形填充（6个三角形，fan方式）
                    local centerP, centerD = FlatToHemi(cx, cy)
                    local centerAlpha = 0.5
                    for i = 0, 5 do
                        local j = (i + 1) % 6
                        local vx1 = cx + hexDirs[i][1]
                        local vy1 = cy + hexDirs[i][2]
                        local vx2 = cx + hexDirs[j][1]
                        local vy2 = cy + hexDirs[j][2]
                        local p1, d1 = FlatToHemi(vx1, vy1)
                        local p2, d2 = FlatToHemi(vx2, vy2)

                        -- 三角形：center → v1 → v2
                        fillGeom:DefineVertex(centerP)
                        fillGeom:DefineNormal(centerP:Normalized())
                        fillGeom:DefineColor(Color(0.3, 0.6, 1.0, centerAlpha))
                        fillGeom:DefineTexCoord(Vector2(0.5, 0.5))

                        fillGeom:DefineVertex(p1)
                        fillGeom:DefineNormal(p1:Normalized())
                        fillGeom:DefineColor(Color(0.3, 0.6, 1.0, centerAlpha))
                        fillGeom:DefineTexCoord(Vector2(0, 0))

                        fillGeom:DefineVertex(p2)
                        fillGeom:DefineNormal(p2:Normalized())
                        fillGeom:DefineColor(Color(0.3, 0.6, 1.0, centerAlpha))
                        fillGeom:DefineTexCoord(Vector2(1, 0))
                    end
                end
            end
        end
    end

    fillGeom:Commit()
    shieldFillMat_ = Material:new()
    shieldFillMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    shieldFillMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.7, 0.9, 0.5)))
    shieldFillMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.12, 0.3)))
    shieldFillMat_:SetShaderParameter("Metallic", Variant(0.0))
    shieldFillMat_:SetShaderParameter("Roughness", Variant(0.95))
    fillGeom:SetMaterial(shieldFillMat_)

    -- 护盾前方发光点光源
    local shieldGlow = shieldNode_:CreateChild("ShieldGlow")
    shieldGlow.position = Vector3(0, 0, 0.5)
    local gl = shieldGlow:CreateComponent("Light")
    gl.lightType = LIGHT_POINT
    gl.color = Color(0.4, 0.7, 1.0)
    gl.brightness = 6.0
    gl.range = 5.0

    shieldNode_:SetEnabled(false)

    -- ================================================================
    -- 引擎拖尾（极简：少段长条 + 固定偏移，无链式追踪）
    -- ================================================================
    local trailMat = Material:new()
    trailMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    trailMat:SetShaderParameter("Metallic", Variant(0.0))
    trailMat:SetShaderParameter("Roughness", Variant(1.0))

    engineTrails_ = {}
    local trailCount = 24  -- 24段光带
    local segSpacing = 0.075 -- 间距适配24段
    local boxMdl = cache:GetResource("Model", "Models/Box.mdl")  -- Box比Sphere少90%顶点
    -- 双引擎各一条拖尾
    for side = -1, 1, 2 do
        local trail = { nodes = {}, baseX = side * 0.42, baseY = -0.05, baseZ = -1.4 }
        for i = 1, trailCount do
            local tn = scene_:CreateChild("Trail")
            local s = 1.0 - (i - 1) / trailCount  -- 1.0 → ~0.04
            -- 扁平长条Box，Z轴大幅超过间距确保无缝重叠
            local thickness = 0.028 * s + 0.005
            local zLen = 0.22 + 0.12 * s  -- 0.22~0.34，超间距0.075的3~4.5倍（消除断裂）
            tn.scale = Vector3(thickness, thickness, zLen)
            local tm = tn:CreateComponent("StaticModel")
            tm:SetModel(boxMdl)
            local segMat = trailMat:Clone("")
            segMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.4, 1.0, 0.45 * s)))
            segMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3 * s, 0.8 * s, 3.0 * s)))
            tm:SetMaterial(segMat)
            tm.castShadows = false
            trail.nodes[i] = tn
        end
        trail.segSpacing = segSpacing
        table_insert(engineTrails_, trail)
    end

    -- 引擎拖尾微粒（每侧20个极细小光点，向后释放飘散）
    engineTrailParticles_ = {}
    local particleCount = 20  -- 每侧20个粒子，共40个（性能优化：72→40）
    local sphereMdl = cache:GetResource("Model", "Models/Sphere.mdl")
    for side = -1, 1, 2 do
        for p = 1, particleCount do
            local pn = scene_:CreateChild("TrailParticle")
            local pSize = 0.005 + math_random() * 0.008  -- 0.005~0.013 极细小
            pn.scale = Vector3(pSize, pSize, pSize)
            local pm = pn:CreateComponent("StaticModel")
            pm:SetModel(sphereMdl)
            local pMat = trailMat:Clone("")
            local brightness = 0.4 + math_random() * 0.6
            pMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.3, 1.0, 0.25 * brightness)))
            pMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3 * brightness, 0.7 * brightness, 3.0 * brightness)))
            pm:SetMaterial(pMat)
            pm.castShadows = false
            -- 分布在引擎后方，模拟向后喷射
            local zOffset = -1.4 - math_random() * 2.5  -- 延伸到后方(-1.4 ~ -3.9)
            local xSpread = (math_random() - 0.5) * 0.12  -- 水平轻微扩散
            table_insert(engineTrailParticles_, {
                node = pn,
                baseX = side * 0.42 + xSpread,
                baseY = -0.05 + (math_random() - 0.5) * 0.06,
                baseZ = zOffset,
                phase = math_random() * 6.28,
                freq = 2.0 + math_random() * 3.0,
                amp = 0.02 + math_random() * 0.03,
                driftZ = -0.3 - math_random() * 0.7,
            })
        end
    end

    -- ================================================================
    -- 程序化生成16x16柔边圆形纹理（共用，一次性）
    -- ================================================================
    local circleImg = Image:new()
    circleImg:SetSize(16, 16, 4)
    for y = 0, 15 do
        for x = 0, 15 do
            local dx = (x - 7.5) / 7.5
            local dy = (y - 7.5) / 7.5
            local dist = math_sqrt(dx * dx + dy * dy)
            local alpha = math_max(0.0, math_min(1.0, (1.0 - dist) * 2.0))
            circleImg:SetPixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
        end
    end
    local circleTex = Texture2D:new()
    circleTex:SetData(circleImg, false)

    -- ================================================================
    -- 翼尖 warp 拖尾（BillboardSet，仅warp时显示）
    -- ================================================================
    warpWingTrailNode_ = scene_:CreateChild("WarpWingTrail")
    warpWingTrailBBS_ = warpWingTrailNode_:CreateComponent("BillboardSet")
    local wingTrailSegs = 16  -- 每侧16段，共32个billboard
    warpWingTrailBBS_.numBillboards = wingTrailSegs * 2
    warpWingTrailBBS_.sorted = false
    warpWingTrailBBS_.relative = false
    warpWingTrailBBS_.scaled = false
    warpWingTrailBBS_.faceCameraMode = FC_ROTATE_XYZ

    local wingTrailMat = Material:new()
    wingTrailMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml"))
    wingTrailMat:SetTexture(0, circleTex)
    wingTrailMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.7, 1.0, 0.8)))
    wingTrailMat:SetShaderParameter("MatEmissiveColor", Variant(Color(1.0, 2.0, 5.0)))
    warpWingTrailBBS_:SetMaterial(wingTrailMat)

    -- 初始化所有billboard为隐藏
    warpWingTrailData_ = {}
    for side = -1, 1, 2 do
        local sideData = { positions = {} }
        local baseIdx = (side == -1) and 0 or wingTrailSegs
        for i = 0, wingTrailSegs - 1 do
            local bb = warpWingTrailBBS_:GetBillboard(baseIdx + i)
            bb.enabled = false
            bb.size = Vector2(0.03, 0.03)
            bb.color = Color(0.5, 0.8, 1.0, 0.0)
            bb.position = Vector3(0, 0, 0)
            sideData.positions[i + 1] = Vector3(0, 0, 0)
        end
        sideData.baseIdx = baseIdx
        sideData.wingX = side * 1.55   -- 翼尖X坐标
        sideData.wingY = -0.03         -- 翼尖Y
        sideData.wingZ = -0.1          -- 翼尖Z（后缘附近）
        table_insert(warpWingTrailData_, sideData)
    end
    warpWingTrailBBS_:Commit()
    warpWingTrailNode_:SetEnabled(false)  -- 初始隐藏

    -- ================================================================
    -- 尾焰火花粒子（BillboardSet：单 draw call，30个微小火花）
    -- ================================================================
    exhaustSparkNode_ = shipNode_:CreateChild("ExhaustSparks")
    exhaustSparkNode_.position = Vector3(0, 0, 0)
    exhaustSparkBBS_ = exhaustSparkNode_:CreateComponent("BillboardSet")
    local sparkCount = 30
    exhaustSparkBBS_.numBillboards = sparkCount
    exhaustSparkBBS_.sorted = false
    exhaustSparkBBS_.relative = false
    exhaustSparkBBS_.scaled = false
    exhaustSparkBBS_.faceCameraMode = FC_ROTATE_XYZ

    local sparkMat = Material:new()
    sparkMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml"))
    sparkMat:SetTexture(0, circleTex)
    sparkMat:SetShaderParameter("MatDiffColor", Variant(Color(0.5, 0.8, 1.0, 0.9)))
    sparkMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8, 1.5, 4.0)))
    exhaustSparkBBS_:SetMaterial(sparkMat)

    exhaustSparkData_ = {}
    local shipPos = shipNode_.position
    local shipRot = shipNode_.rotation
    for i = 0, sparkCount - 1 do
        local bb = exhaustSparkBBS_:GetBillboard(i)
        bb.enabled = true
        bb.size = Vector2(0.006, 0.006)
        bb.color = Color(0.5, 0.8, 1.0, 0.0)
        -- 初始化在引擎喷口附近
        local side = (i % 2 == 0) and 0.42 or -0.42
        local localPos = Vector3(side + (math_random() - 0.5) * 0.08, -0.05, -1.5)
        bb.position = shipPos + shipRot * localPos
        bb.rotation = math_random() * 360

        local maxLife = 0.3 + math_random() * 0.5
        exhaustSparkData_[i] = {
            life = math_random() * maxLife,  -- 错开初始相位
            maxLife = maxLife,
            side = side,
            vx = (math_random() - 0.5) * 0.4,
            vy = (math_random() - 0.5) * 0.3,
            vz = -2.0 - math_random() * 3.0,
        }
    end
    exhaustSparkBBS_:Commit()
end

-- ============================================================================
-- 背景星尘
-- ============================================================================

function CreateStarDusts()
    for i = 1, starDustCount_ do
        local dustNode = scene_:CreateChild("StarDust")
        local x = math_random() * 60 - 30
        local y = math_random() * 40 - 20
        local z = math_random() * 150 + 10
        dustNode.position = Vector3(x, y, z)
        dustNode.scale = Vector3(0.05, 0.05, 0.05)

        local model = dustNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        model:SetMaterial(starDustMat_)

        table_insert(starDusts_, { node = dustNode, speed = 10 + math_random() * 20 })
    end
end

-- ============================================================================
-- 折跃穿越视觉效果
-- ============================================================================

function CreateWarpStreaks()
    local streakMat = Material:new()
    streakMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    streakMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.7, 1.0, 0.6)))
    streakMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.6, 0.9, 2.5)))
    streakMat:SetShaderParameter("Metallic", Variant(0.0))
    streakMat:SetShaderParameter("Roughness", Variant(0.1))

    for i = 1, warpStreakCount_ do
        local node = scene_:CreateChild("WarpStreak")
        local x = math_random() * 16 - 8
        local y = math_random() * 10 - 5
        local z = math_random() * 80 + 20
        node.position = Vector3(x, y, z)
        -- 细长条：X/Y极小，Z方向拉长
        local thickness = 0.03 + math_random() * 0.06
        local length = 6.0 + math_random() * 10.0
        node.scale = Vector3(thickness, thickness, length)

        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        model:SetMaterial(streakMat)

        node:SetEnabled(false)
        table_insert(warpStreaks_, { node = node, speed = 120 + math_random() * 80, length = length })
    end

    -- 飞船折跃发光
    warpGlowNode_ = shipNode_:CreateChild("WarpGlow")
    warpGlowNode_.position = Vector3(0, 0, -0.5)
    local light = warpGlowNode_:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = Color(0.4, 0.7, 1.0)
    light.brightness = 60
    light.range = 8.0
    warpGlowNode_:SetEnabled(false)
end

function UpdateWarpVisuals(dt)
    local active = warpActive_

    -- 穿越光条（前3秒渐入，后3秒渐出）
    local visibleCount = 0
    if active then
        local elapsed = warpDuration_ - warpTimer_   -- 已经过时间
        local remaining = warpTimer_                  -- 剩余时间
        local fadeIn = 3.0
        local fadeOut = 3.0
        local ratio = 1.0
        if elapsed < fadeIn then
            ratio = elapsed / fadeIn
        end
        if remaining < fadeOut and remaining < elapsed then
            ratio = remaining / fadeOut
        end
        visibleCount = math_max(1, math_floor(warpStreakCount_ * ratio))
    end

    for i, streak in ipairs(warpStreaks_) do
        if active and i <= visibleCount then
            streak.node:SetEnabled(true)
            local pos = streak.node.position
            pos.z = pos.z - streak.speed * dt
            if pos.z < -15 then
                pos.z = 60 + math_random() * 40
                pos.x = math_random() * 16 - 8
                pos.y = math_random() * 10 - 5
            end
            streak.node.position = pos
        else
            streak.node:SetEnabled(false)
        end
    end

    -- 星尘拉伸（仅在warp状态切换时更新，避免每帧重复设置）
    if warpVisualDirty_ == nil then warpVisualDirty_ = true end
    if warpVisualDirty_ or (warpLastActive_ ~= active) then
        warpLastActive_ = active
        warpVisualDirty_ = false
        local sz = active and Vector3(0.05, 0.05, 1.5) or Vector3(0.05, 0.05, 0.05)
        for _, dust in ipairs(starDusts_) do
            dust.node.scale = sz
        end
    end

    -- 飞船发光
    if warpGlowNode_ then
        warpGlowNode_:SetEnabled(active)
    end

    -- 翼尖拖尾（仅warp时显示）
    if warpWingTrailNode_ then
        warpWingTrailNode_:SetEnabled(active)
        if active and shipNode_ then
            local shipPos = shipNode_.position
            local shipRot = shipNode_.rotation
            local wingTrailSegs = 16
            for _, sideData in ipairs(warpWingTrailData_) do
                -- 计算当前翼尖世界坐标
                local localTip = Vector3(sideData.wingX, sideData.wingY, sideData.wingZ)
                local worldTip = shipPos + shipRot * localTip
                -- 将新位置插入头部，旧位置往后推
                table_insert(sideData.positions, 1, worldTip)
                -- 保持长度不超过段数
                while #sideData.positions > wingTrailSegs do
                    table_remove(sideData.positions)
                end
                -- 更新billboard
                for i = 1, wingTrailSegs do
                    local bb = warpWingTrailBBS_:GetBillboard(sideData.baseIdx + i - 1)
                    if i <= #sideData.positions then
                        bb.enabled = true
                        bb.position = sideData.positions[i]
                        local ratio = (i - 1) / (wingTrailSegs - 1)  -- 0=头部, 1=尾部
                        local s = 0.04 * (1.0 - ratio * 0.7)
                        bb.size = Vector2(s, s)
                        local alpha = 0.85 * (1.0 - ratio)
                        bb.color = Color(0.4 + 0.4 * (1.0 - ratio), 0.7 + 0.3 * (1.0 - ratio), 1.0, alpha)
                    else
                        bb.enabled = false
                    end
                end
            end
            warpWingTrailBBS_:Commit()
        else
            -- warp结束时清空拖尾数据
            for _, sideData in ipairs(warpWingTrailData_) do
                sideData.positions = {}
                for i = 0, 15 do
                    local bb = warpWingTrailBBS_:GetBillboard(sideData.baseIdx + i)
                    bb.enabled = false
                end
            end
            warpWingTrailBBS_:Commit()
        end
    end
end

-- ============================================================================
-- 游戏状态管理
-- ============================================================================

function ReturnToMenu()
    -- 停止结局BGM
    StopEndingBGM()

    -- 恢复主BGM
    if bgmSource_ and bgmSound_ then
        bgmSource_:Play(bgmSound_)
        bgmSource_.gain = bgmEnabled_ and 0.5 or 0.0
    end

    -- 清除游戏物体
    ClearObjects()

    -- 重新生成装饰物
    CreateStarDusts()
    CreateDecoAsteroids()
    CreateMeteors()

    -- 重置飞船到菜单状态
    if shipNode_ then
        shipNode_:SetEnabled(true)
        shipNode_.position = Vector3(0, 0, 0)
        shipNode_.rotation = Quaternion(0, 0, 0)
    end

    -- 切换到菜单
    gameState_ = STATE_MENU
    ShowMenuUI()
end

function StartGame()
    -- 停止所有BGM（游戏中无音乐）
    StopEndingBGM()
    if bgmSource_ then
        bgmSource_.gain = 0.0
    end

    gameState_ = STATE_PLAYING
    score_ = 0
    lives_ = 5
    speed_ = 20.0
    shipX_ = 0.0
    shipY_ = 0.0
    gameTime_ = 0
    invincibleTimer_ = 0
    asteroidSpawnTimer_ = 0
    crystalSpawnTimer_ = 0

    -- 重置射击/过热
    heat_ = 0
    overheated_ = false
    overheatTimer_ = 0
    fireTimer_ = 0

    -- 重置护盾
    shieldActive_ = false
    shieldTimer_ = 0
    shieldCoolTimer_ = 0
    shieldAnimState_ = "none"
    shieldAnimTimer_ = 0
    if shieldNode_ then
        shieldNode_:SetEnabled(false)
        shieldNode_:SetScale(Vector3(1, 1, 1))
    end

    -- 重置折跃系统
    warpEnergy_ = 0
    warpCharging_ = false
    warpChargeTimer_ = 0
    warpActive_ = false
    warpTimer_ = 0
    -- 重置翼尖拖尾
    if warpWingTrailNode_ then
        warpWingTrailNode_:SetEnabled(false)
    end
    for _, sideData in ipairs(warpWingTrailData_) do
        sideData.positions = {}
    end

    -- 重置剧情系统
    storyRepairCount_ = 0
    storyExploreCount_ = 0
    storyBroadcastCount_ = 0
    storyTriggeredIndex_ = 0

    -- 重置倾斜和速度
    currentTiltX_ = 0.0
    currentTiltZ_ = 0.0
    rollActive_ = false
    rollTimer_ = 0
    rollAngle_ = 0
    rollCdLeftTimer_ = 0
    rollCdRightTimer_ = 0
    shipVelX_ = 0.0
    shipVelY_ = 0.0

    -- 清除所有障碍物
    ClearObjects()

    -- 重置飞船
    shipNode_:SetEnabled(true)
    shipNode_.position = Vector3(0, 0, 0)
    shipNode_.rotation = Quaternion(0, 0, 0)

    -- 重置拖尾位置（避免残留）
    if engineTrails_ then
        for _, trail in ipairs(engineTrails_) do
            local resetPos = Vector3(trail.baseX, trail.baseY, trail.baseZ)
            for _, tn in ipairs(trail.nodes) do
                tn.position = resetPos
            end
        end
    end
    if engineTrailParticles_ then
        for _, pt in ipairs(engineTrailParticles_) do
            pt.node.position = Vector3(pt.baseX, pt.baseY, pt.baseZ)
        end
    end

    -- 切换到游戏 HUD
    ShowPlayingUI()

    print("=== Game Started ===")
end

function GameOver()
    gameState_ = STATE_GAMEOVER
    print(string.format("=== Game Over | Score: %d ===", score_))

    -- 切换到结束 UI
    ShowGameOverUI()
end

function ClearObjects()
    for _, asteroid in ipairs(asteroids_) do
        if asteroid.node ~= nil then
            asteroid.node:Remove()
        end
    end
    asteroids_ = {}

    for _, crystal in ipairs(crystals_) do
        if crystal.node ~= nil then
            crystal.node:Remove()
        end
    end
    crystals_ = {}

    for _, bullet in ipairs(bullets_) do
        if bullet.node ~= nil then
            bullet.node:Remove()
        end
    end
    bullets_ = {}

    for _, exp in ipairs(explosions_) do
        for _, item in ipairs(exp.nodes) do
            if item.node ~= nil then
                item.node:Remove()
            end
        end
    end
    explosions_ = {}
end

-- ============================================================================
-- 更新循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    frameCount_ = frameCount_ + 1

    -- 雾景深循环动画（隔帧更新）
    if zone_ and frameCount_ % 2 == 0 then
        local t
        if gameState_ == STATE_PLAYING or gameState_ == STATE_GAMEOVER then
            -- 游戏中：全强度，跟随 gameTime_
            t = (math_sin(gameTime_ * 0.349 - math_pi * 0.5) + 1.0) * 0.5
        else
            -- 菜单/等待：半强度，跟随全局时间（呼吸周期为游戏内两倍 ~36秒）
            t = (math_sin(time.elapsedTime * 0.1745 - math_pi * 0.5) + 1.0) * 0.5 * 0.5
        end
        local r = 0.02 + t * 0.0925
        local g = 0.015 + t * 0.075
        local b = 0.05 + t * 0.1375
        zone_.fogColor = Color(r, g, b, 1.0)
        zone_.fogStart = 80 - t * 30
        zone_.fogEnd = 400 - t * 90
    end

    if gameState_ == STATE_PLAYING then
        gameTime_ = gameTime_ + dt
        UpdateShip(dt)
        UpdateWarp(dt)
        UpdateShooting(dt)
        UpdateShield(dt)
        UpdateBullets(dt)
        UpdateAsteroids(dt)
        UpdateCrystals(dt)
        UpdateStarDusts(dt)
        UpdateExplosions(dt)
        UpdateWarpVisuals(dt)
        CheckCollisions()
        UpdateDifficulty(dt)
        if frameCount_ % 3 == 0 then
            UpdateHUD()
        end

        -- 无敌闪烁
        if invincibleTimer_ > 0 then
            invincibleTimer_ = invincibleTimer_ - dt
            local visible = math_floor(invincibleTimer_ * 10) % 2 == 0
            shipNode_:SetEnabled(visible)
        else
            shipNode_:SetEnabled(true)
        end

    elseif gameState_ == STATE_MENU then
        UpdateStarDusts(dt)
        -- 菜单中飞船缓慢浮动
        if shipNode_ ~= nil then
            shipNode_.position = Vector3(
                math_sin(time.elapsedTime * 0.5) * 0.5,
                math_sin(time.elapsedTime * 0.8) * 0.3,
                0
            )
            shipNode_:SetEnabled(true)

            do
                local shipPos = shipNode_.position
                local shipRot = shipNode_.rotation
                local menuDt = dt

                -- 菜单呼吸速度驱动尾焰长度（与星尘同步）
                local menuBreath = (math_sin(time.elapsedTime * 0.4) + 1) * 0.5
                local menuSpeed = 20 + menuBreath * 40
                local speedLenScale = menuSpeed / 40.0

                -- 引擎拖尾段
                if engineTrails_ then
                    for _, trail in ipairs(engineTrails_) do
                        local spacing = trail.segSpacing
                        local nodes = trail.nodes
                        local trailCount = #nodes
                        for i, tn in ipairs(nodes) do
                            local localPos = Vector3(trail.baseX, trail.baseY, trail.baseZ - (i - 1) * spacing * speedLenScale)
                            local targetPos = shipPos + shipRot * localPos
                            local followSpeed = 60.0 / (0.3 + i * 0.28)
                            local lf = math_min(1.0, followSpeed * menuDt)
                            local curPos = tn.position
                            local newX = curPos.x + (targetPos.x - curPos.x) * lf
                            local newY = curPos.y + (targetPos.y - curPos.y) * lf
                            local newZ = curPos.z + (targetPos.z - curPos.z) * lf
                            local maxDrift = spacing * speedLenScale * 1.5
                            local dx = newX - targetPos.x
                            local dy = newY - targetPos.y
                            local dz = newZ - targetPos.z
                            local drift2 = dx*dx + dy*dy + dz*dz
                            if drift2 > maxDrift * maxDrift then
                                local s = maxDrift / math_sqrt(drift2)
                                newX = targetPos.x + dx * s
                                newY = targetPos.y + dy * s
                                newZ = targetPos.z + dz * s
                            end
                            tn.position = Vector3(newX, newY, newZ)
                            local rotLerp = math_min(1.0, (50.0 / (0.3 + i * 0.4)) * menuDt)
                            tn.rotation = tn.rotation:Slerp(shipRot, rotLerp)

                            -- 动态缩放每段尾焰（与游戏中逻辑一致）
                            local s2 = 1.0 - (i - 1) / trailCount
                            local baseThickness = 0.028 * s2 + 0.005
                            local baseZLen = 0.22 + 0.12 * s2
                            local scaleXY = baseThickness
                            local scaleZ = baseZLen * speedLenScale
                            tn.scale = Vector3(scaleXY, scaleXY, scaleZ)
                        end
                    end
                end

                -- 微粒（速度驱动飘散范围）
                if engineTrailParticles_ then
                    local t = time.elapsedTime
                    local ptLenScale = menuSpeed / 40.0
                    for _, pt in ipairs(engineTrailParticles_) do
                        local ox = math_sin(t * pt.freq + pt.phase) * pt.amp
                        local oy = math_cos(t * pt.freq * 0.7 + pt.phase + 1.0) * pt.amp * 0.6
                        local zCycle = 2.5 * ptLenScale
                        local zDrift = ((t * pt.driftZ + pt.phase * 0.5) % zCycle)
                        local localZ = pt.baseZ * ptLenScale + zDrift
                        local localPos = Vector3(pt.baseX + ox, pt.baseY + oy, localZ)
                        local targetPos = shipPos + shipRot * localPos
                        local curPos = pt.node.position
                        local lf = math_min(1.0, 20.0 * menuDt)
                        pt.node.position = Vector3(
                            curPos.x + (targetPos.x - curPos.x) * lf,
                            curPos.y + (targetPos.y - curPos.y) * lf,
                            curPos.z + (targetPos.z - curPos.z) * lf
                        )
                    end
                end

                -- 火花粒子
                if exhaustSparkBBS_ then
                    local spkDt = dt
                    for i = 0, exhaustSparkBBS_.numBillboards - 1 do
                        local d = exhaustSparkData_[i]
                        d.life = d.life + spkDt
                        if d.life >= d.maxLife then
                            d.life = 0
                            d.maxLife = 0.3 + math_random() * 0.5
                            d.vx = (math_random() - 0.5) * 0.3
                            d.vy = (math_random() - 0.5) * 0.2
                            d.vz = -2.0 - math_random() * 3.0
                            local localPos = Vector3(d.side + (math_random() - 0.5) * 0.06, -0.05, -1.5)
                            local bb = exhaustSparkBBS_:GetBillboard(i)
                            bb.position = shipPos + shipRot * localPos
                            bb.size = Vector2(0.006, 0.006)
                            bb.color = Color(0.6, 0.85, 1.0, 0.9)
                        else
                            local bb = exhaustSparkBBS_:GetBillboard(i)
                            local ratio = d.life / d.maxLife
                            local localOff = Vector3(d.vx * spkDt, d.vy * spkDt, d.vz * spkDt)
                            local worldOff = shipRot * localOff
                            local pos = bb.position
                            bb.position = Vector3(pos.x + worldOff.x, pos.y + worldOff.y, pos.z + worldOff.z)
                            local s = 0.006 * (1.0 - ratio * 0.8)
                            bb.size = Vector2(s, s)
                            local alpha = 0.9 * (1.0 - ratio)
                            bb.color = Color(0.2 + 0.4 * (1.0 - ratio), 0.5 + 0.4 * (1.0 - ratio), 1.0, alpha)
                        end
                    end
                    exhaustSparkBBS_:Commit()
                end
            end
        end
        -- Start 按钮呼吸闪烁动画
        if menuStartLabel_ ~= nil then
            local breath = (math_sin(time.elapsedTime * 2.5) + 1) * 0.5
            local alpha = math_floor(140 + breath * 115)
            local glow = math_floor(80 + breath * 175)
            menuStartLabel_:SetFontColor({ 120, 220, 255, alpha })
            menuStartBtn_:SetBorderColor({ glow, 220, 255, alpha })
        end
    else
        UpdateStarDusts(dt)
        -- 结局按钮呼吸闪烁动画（与 START 按钮同风格）
        local uiRoot = UI.GetRoot()
        if uiRoot then
            local endBtn = uiRoot:FindById("endingBtn")
            if endBtn then
                local breath = (math_sin(time.elapsedTime * 2.5) + 1) * 0.5
                local alpha = math_floor(140 + breath * 115)
                local glow = math_floor(80 + breath * 175)
                endBtn:SetFontColor({ 120, 220, 255, alpha })
                local parent = endBtn:GetParent()
                if parent then
                    parent:SetBorderColor({ glow, 220, 255, alpha })
                end
            end
        end
    end

    -- 航道外装饰陨石（所有状态都漂移）
    UpdateDecoAsteroids(dt)

    -- 流星划过
    UpdateMeteors(dt)

    -- 星河呼吸效果（每3帧更新25%星点）
    UpdateStarfieldBreath()
end

-- ============================================================================
-- 飞船控制
-- ============================================================================

function UpdateShip(dt)
    local moveX = 0
    local moveY = 0

    if not rollActive_ then
        if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then
            moveX = -1
        end
        if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then
            moveX = 1
        end
    end
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
        moveY = 1
    end
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
        moveY = -1
    end

    -- X键减速（折跃中不可减速）
    if not warpActive_ and input:GetKeyDown(KEY_X) then
        speed_ = math_max(10.0, speed_ - 40 * dt)
    end

    -- C键加速
    if not warpActive_ and input:GetKeyDown(KEY_C) then
        speed_ = math_min(maxSpeed_, speed_ + 60 * dt)
    end

    -- 速度平滑：有输入时加速，无输入时减速
    if moveX ~= 0 then
        shipVelX_ = shipVelX_ + moveX * shipAccel_ * dt
        shipVelX_ = math_max(-shipMoveSpeed_, math_min(shipMoveSpeed_, shipVelX_))
    else
        -- 摩擦减速
        if shipVelX_ > 0 then
            shipVelX_ = math_max(0, shipVelX_ - shipDecel_ * dt)
        elseif shipVelX_ < 0 then
            shipVelX_ = math_min(0, shipVelX_ + shipDecel_ * dt)
        end
    end

    if moveY ~= 0 then
        shipVelY_ = shipVelY_ + moveY * shipAccel_ * dt
        shipVelY_ = math_max(-shipMoveSpeed_, math_min(shipMoveSpeed_, shipVelY_))
    else
        if shipVelY_ > 0 then
            shipVelY_ = math_max(0, shipVelY_ - shipDecel_ * dt)
        elseif shipVelY_ < 0 then
            shipVelY_ = math_min(0, shipVelY_ + shipDecel_ * dt)
        end
    end

    -- 更新位置
    shipX_ = shipX_ + shipVelX_ * dt
    shipY_ = shipY_ + shipVelY_ * dt

    -- 限制范围（碰到边缘时清零速度）
    if shipX_ < -moveRangeX_ then shipX_ = -moveRangeX_; shipVelX_ = 0 end
    if shipX_ > moveRangeX_ then shipX_ = moveRangeX_; shipVelX_ = 0 end
    if shipY_ < -moveRangeY_ then shipY_ = -moveRangeY_; shipVelY_ = 0 end
    if shipY_ > moveRangeY_ then shipY_ = moveRangeY_; shipVelY_ = 0 end

    -- 待机微晃动（速度越小晃动越明显）
    local idleFactor = 1.0 - math_min(1.0, (math_abs(shipVelX_) + math_abs(shipVelY_)) / shipMoveSpeed_)
    local idleOffsetX = math_sin(time.elapsedTime * 1.2) * 0.06 * idleFactor
    local idleOffsetY = math_sin(time.elapsedTime * 0.9 + 1.5) * 0.04 * idleFactor

    -- 应用位置
    shipNode_.position = Vector3(shipX_ + idleOffsetX, shipY_ + idleOffsetY, 0)

    -- 倾斜视觉效果（基于速度比例，更自然）
    local tiltRatioX = shipVelX_ / shipMoveSpeed_
    local tiltRatioY = shipVelY_ / shipMoveSpeed_
    local targetTiltZ = -tiltRatioX * 30
    local targetTiltX = tiltRatioY * 12
    local lerpSpeed = 6.0 * dt
    currentTiltZ_ = currentTiltZ_ + (targetTiltZ - currentTiltZ_) * lerpSpeed
    currentTiltX_ = currentTiltX_ + (targetTiltX - currentTiltX_) * lerpSpeed

    -- 极小值归零，避免浮点抖动
    if math_abs(currentTiltZ_) < 0.01 then currentTiltZ_ = 0 end
    if math_abs(currentTiltX_) < 0.01 then currentTiltX_ = 0 end

    -- 翻滚冷却更新
    if rollCdLeftTimer_ > 0 then rollCdLeftTimer_ = rollCdLeftTimer_ - dt end
    if rollCdRightTimer_ > 0 then rollCdRightTimer_ = rollCdRightTimer_ - dt end

    -- 翻滚技能：Q/E 触发（需要冷却结束）
    if not rollActive_ then
        if input:GetKeyPress(KEY_Q) and rollCdLeftTimer_ <= 0 then
            rollActive_ = true
            rollTimer_ = rollDuration_
            rollDirection_ = -1  -- 左翻滚
            rollAngle_ = 0
            rollCdLeftTimer_ = rollCd_
        elseif input:GetKeyPress(KEY_E) and rollCdRightTimer_ <= 0 then
            rollActive_ = true
            rollTimer_ = rollDuration_
            rollDirection_ = 1   -- 右翻滚
            rollAngle_ = 0
            rollCdRightTimer_ = rollCd_
        end
    end

    -- 翻滚角度更新 + 方向位移
    if rollActive_ then
        rollTimer_ = rollTimer_ - dt
        if rollTimer_ <= 0 then
            rollActive_ = false
            rollAngle_ = 0
            -- 翻滚结束，触发摇晃
            rollWobbleTimer_ = rollWobbleDuration_
            rollWobbleDir_ = rollDirection_
        else
            -- 匀速旋转360度
            rollAngle_ = (1.0 - rollTimer_ / rollDuration_) * 360.0 * rollDirection_
            -- 翻滚期间向翻滚方向位移
            local rollSpeed = 8.0  -- 翻滚位移速度（米/秒）
            shipX_ = shipX_ + rollDirection_ * rollSpeed * dt
        end
    end

    -- 翻滚结束后摇晃衰减
    local wobbleAngle = 0
    if rollWobbleTimer_ > 0 then
        rollWobbleTimer_ = rollWobbleTimer_ - dt
        if rollWobbleTimer_ <= 0 then
            rollWobbleTimer_ = 0
        else
            -- 衰减因子（从1到0）
            local decay = rollWobbleTimer_ / rollWobbleDuration_
            -- 高频振荡 + 指数衰减，模拟水平仪回稳
            local freq = 14.0  -- 振荡频率
            local elapsed = rollWobbleDuration_ - rollWobbleTimer_
            wobbleAngle = math_sin(elapsed * freq) * decay * decay * 24.0 * rollWobbleDir_
        end
    end

    -- 叠加翻滚+摇晃到飞船旋转（Z轴）
    local finalTiltZ = currentTiltZ_ + rollAngle_ + wobbleAngle
    shipNode_.rotation = Quaternion(currentTiltX_, 0, finalTiltZ)

    -- 引擎拖尾更新（36段平滑跟随 + 最大偏移限制防断裂 + 旋转滞后弧度）
    if engineTrails_ then
        local shipPos = shipNode_.position
        local shipRot = shipNode_.rotation

        -- 速度驱动尾焰长度：以40为基准速度，速度越快越长，越慢越短
        local speedLenScale = speed_ / 40.0

        -- Warp 尾焰宽度缩放：前3秒渐大，结束前3秒渐原
        local warpWidthScale = 1.0
        if warpActive_ then
            local elapsed = warpDuration_ - warpTimer_  -- 已经过的时间
            local remaining = warpTimer_                 -- 剩余时间
            if elapsed < 3.0 then
                warpWidthScale = 1.0 + (elapsed / 3.0) * 2.0   -- 1.0 → 3.0
            elseif remaining < 3.0 then
                warpWidthScale = 1.0 + (remaining / 3.0) * 2.0 -- 3.0 → 1.0
            else
                warpWidthScale = 3.0  -- 中间阶段保持最大
            end
        end

        -- 缩放只在参数变化时更新（减少 Vector3 分配）
        local scaleChanged = (trailLastSpeedScale_ ~= speedLenScale) or (trailLastWarpScale_ ~= warpWidthScale)
        trailLastSpeedScale_ = speedLenScale
        trailLastWarpScale_ = warpWidthScale

        local shipPosX, shipPosY, shipPosZ = shipPos.x, shipPos.y, shipPos.z

        for _, trail in ipairs(engineTrails_) do
            local spacing = trail.segSpacing
            local nodes = trail.nodes
            local trailCount = #nodes
            local baseX = trail.baseX
            local baseY = trail.baseY
            local baseZ = trail.baseZ
            local maxDrift = spacing * speedLenScale * 1.5
            local maxDrift2 = maxDrift * maxDrift
            local spacingScaled = spacing * speedLenScale
            for i, tn in ipairs(nodes) do
                local localPos = Vector3(baseX, baseY, baseZ - (i - 1) * spacingScaled)
                local targetPos = shipRot * localPos
                local tx = targetPos.x + shipPosX
                local ty = targetPos.y + shipPosY
                local tz = targetPos.z + shipPosZ
                local followSpeed = 60.0 / (0.3 + i * 0.28)
                local lerpFactor = math_min(1.0, followSpeed * dt)
                local curPos = tn.position
                local cx, cy, cz = curPos.x, curPos.y, curPos.z
                local newX = cx + (tx - cx) * lerpFactor
                local newY = cy + (ty - cy) * lerpFactor
                local newZ = cz + (tz - cz) * lerpFactor
                -- 限制最大偏移，防止段间拉开
                local dx = newX - tx
                local dy = newY - ty
                local dz = newZ - tz
                local drift2 = dx*dx + dy*dy + dz*dz
                if drift2 > maxDrift2 then
                    local s = maxDrift / math_sqrt(drift2)
                    newX = tx + dx * s
                    newY = ty + dy * s
                    newZ = tz + dz * s
                end
                tn.position = Vector3(newX, newY, newZ)
                -- 旋转平滑跟随飞船（隔帧更新减少 Slerp 开销）
                if (frameCount_ + i) % 2 == 0 then
                    local rotLerp = math_min(1.0, (50.0 / (0.3 + i * 0.4)) * dt * 2.0)
                    tn.rotation = tn.rotation:Slerp(shipRot, rotLerp)
                end

                -- 动态缩放每段尾焰（仅参数变化时更新）
                if scaleChanged then
                    local s = 1.0 - (i - 1) / trailCount
                    local baseThickness = 0.028 * s + 0.005
                    local baseZLen = 0.22 + 0.12 * s
                    local scaleXY = baseThickness * warpWidthScale
                    local scaleZ = baseZLen * speedLenScale
                    tn.scale = Vector3(scaleXY, scaleXY, scaleZ)
                end
            end
        end
    end

    -- 拖尾微粒更新（极细光点向后释放飘散，隔帧更新）
    trailParticleFrame_ = (trailParticleFrame_ or 0) + 1
    if engineTrailParticles_ and trailParticleFrame_ % 2 == 0 then
        local shipPos = shipNode_.position
        local shipRot = shipNode_.rotation
        local t = time.elapsedTime

        -- 速度驱动微粒飘散范围
        local ptLenScale = speed_ / 40.0

        -- Warp 微粒宽度缩放（与拖尾宽度同步）
        local warpPtWidth = 1.0
        if warpActive_ then
            local elapsed = warpDuration_ - warpTimer_
            local remaining = warpTimer_
            if elapsed < 3.0 then
                warpPtWidth = 1.0 + (elapsed / 3.0) * 1.5   -- 1.0 → 2.5
            elseif remaining < 3.0 then
                warpPtWidth = 1.0 + (remaining / 3.0) * 1.5 -- 2.5 → 1.0
            else
                warpPtWidth = 2.5
            end
        end

        local spX, spY, spZ = shipPos.x, shipPos.y, shipPos.z
        local lf = math_min(1.0, 20.0 * dt)
        -- 缩放仅在 warpPtWidth 变化时批量更新
        local ptScaleChanged = (trailPtLastWarp_ ~= warpPtWidth)
        trailPtLastWarp_ = warpPtWidth

        for _, pt in ipairs(engineTrailParticles_) do
            local ox = math_sin(t * pt.freq + pt.phase) * pt.amp * warpPtWidth
            local oy = math_cos(t * pt.freq * 0.7 + pt.phase + 1.0) * pt.amp * 0.6 * warpPtWidth
            local zCycle = 2.5 * ptLenScale
            local zDrift = ((t * pt.driftZ + pt.phase * 0.5) % zCycle)
            local localZ = pt.baseZ * ptLenScale + zDrift
            local localPos = Vector3(pt.baseX + ox, pt.baseY + oy, localZ)
            local targetPos = shipRot * localPos
            local ttx = targetPos.x + spX
            local tty = targetPos.y + spY
            local ttz = targetPos.z + spZ
            local curPos = pt.node.position
            local cx, cy, cz = curPos.x, curPos.y, curPos.z
            pt.node.position = Vector3(
                cx + (ttx - cx) * lf,
                cy + (tty - cy) * lf,
                cz + (ttz - cz) * lf
            )
            -- 微粒尺寸随warp放大（仅变化时更新）
            if ptScaleChanged then
                local baseSize = 0.005 + 0.008 * ((pt.phase / 6.28) % 1.0)
                local pSize = baseSize * warpPtWidth
                pt.node.scale = Vector3(pSize, pSize, pSize)
            end
        end

    end

    -- 尾焰火花粒子更新（每帧，蓝色细小光点）
    if exhaustSparkBBS_ then
        local shipPos = shipNode_.position
        local shipRot = shipNode_.rotation
        local sparkCount = exhaustSparkBBS_.numBillboards
        for i = 0, sparkCount - 1 do
            local d = exhaustSparkData_[i]
            d.life = d.life + dt
            if d.life >= d.maxLife then
                -- 重生：回到喷口位置
                d.life = 0
                d.maxLife = 0.3 + math_random() * 0.5
                d.vx = (math_random() - 0.5) * 0.3
                d.vy = (math_random() - 0.5) * 0.2
                d.vz = -2.0 - math_random() * 3.0
                local localPos = Vector3(d.side + (math_random() - 0.5) * 0.06, -0.05, -1.5)
                local bb = exhaustSparkBBS_:GetBillboard(i)
                bb.position = shipPos + shipRot * localPos
                bb.size = Vector2(0.006, 0.006)
                bb.color = Color(0.6, 0.85, 1.0, 0.9)
            else
                local bb = exhaustSparkBBS_:GetBillboard(i)
                local ratio = d.life / d.maxLife  -- 0→1
                local localOff = Vector3(d.vx * dt, d.vy * dt, d.vz * dt * (1.0 + speed_ * 0.02))
                local worldOff = shipRot * localOff
                local pos = bb.position
                bb.position = Vector3(pos.x + worldOff.x, pos.y + worldOff.y, pos.z + worldOff.z)
                -- 尺寸从0.006递减
                local s = 0.006 * (1.0 - ratio * 0.8)
                bb.size = Vector2(s, s)
                local alpha = 0.9 * (1.0 - ratio)
                -- 颜色从亮蓝白→深蓝淡出
                bb.color = Color(0.2 + 0.4 * (1.0 - ratio), 0.5 + 0.4 * (1.0 - ratio), 1.0, alpha)
            end
        end
        exhaustSparkBBS_:Commit()
    end
end

-- ============================================================================
-- 折跃系统
-- ============================================================================

function UpdateWarp(dt)
    -- 折跃激活中
    if warpActive_ then
        warpTimer_ = warpTimer_ - dt
        speed_ = warpSpeed_
        if warpTimer_ <= 0 then
            warpActive_ = false
            speed_ = maxSpeed_ * 0.5  -- 折跃结束速度降为一半
        end
        return
    end

    -- 充能中（长按空格）
    if warpCharging_ then
        if input:GetKeyDown(KEY_SPACE) then
            warpChargeTimer_ = warpChargeTimer_ - dt
            if warpChargeTimer_ <= 0 then
                -- 充能完毕，启动折跃！
                warpActive_ = true
                warpTimer_ = warpDuration_
                warpCharging_ = false
                warpEnergy_ = 0  -- 消耗全部能量
            end
        else
            -- 松开按键，取消充能
            warpCharging_ = false
            warpChargeTimer_ = 0
        end
        return
    end

    -- 能量满时按空格开始充能
    if warpEnergy_ >= warpMaxEnergy_ and input:GetKeyDown(KEY_SPACE) then
        warpCharging_ = true
        warpChargeTimer_ = warpChargeTime_
    end
end

-- ============================================================================
-- 射击系统
-- ============================================================================

function UpdateShooting(dt)
    fireTimer_ = math_max(0, fireTimer_ - dt)

    -- 过热冷却中
    if overheated_ then
        overheatTimer_ = overheatTimer_ - dt
        if overheatTimer_ <= 0 then
            overheated_ = false
            heat_ = 0
        end
    else
        -- 正常散热
        heat_ = math_max(0, heat_ - heatCoolRate_ * dt)
    end

    -- 左键射击
    if not overheated_ and fireTimer_ <= 0 and input:GetMouseButtonDown(MOUSEB_LEFT) then
        FireBullet()
        fireTimer_ = fireRate_
        heat_ = heat_ + heatPerShot_

        -- 过热判断
        if heat_ >= heatMax_ then
            overheated_ = true
            overheatTimer_ = overheatCooldown_
        end
    end
end

function FireBullet()
    -- 双管射击：左右武器挂点同时发射
    local boxMdl = mdlBox_
    local sphereMdl = mdlSphere_

    for side = -1, 1, 2 do
        local node = scene_:CreateChild("Bullet")
        -- 从翼下武器挂点发射（与挂点位置 side*0.65 对应）
        node.position = Vector3(shipX_ + side * 0.65, shipY_ - 0.06, 2.0)

        -- ========== 子弹核心（明亮能量弹头） ==========
        local core = node:CreateChild("Core")
        core.scale = Vector3(0.07, 0.07, 0.45)
        local coreModel = core:CreateComponent("StaticModel")
        coreModel:SetModel(boxMdl)
        coreModel:SetMaterial(bulletCoreMat_)

        -- ========== 外层光晕（稍大半透明包裹） ==========
        local glow = node:CreateChild("Glow")
        glow.scale = Vector3(0.15, 0.15, 0.6)
        local glowModel = glow:CreateComponent("StaticModel")
        glowModel:SetModel(boxMdl)
        glowModel:SetMaterial(bulletGlowMat_)

        -- ========== 曳光拖尾（5段渐隐，性能优化） ==========
        local trails = {}
        for i = 1, 5 do
            local trail = node:CreateChild("Trail")
            local zOffset = -0.35 * i
            trail.position = Vector3(0, 0, zOffset)
            local fade = 1.0 - (i / 6)
            local trailWidth = 0.09 * fade * fade + 0.015
            local trailLen = 0.28 * fade + 0.06
            trail.scale = Vector3(trailWidth, trailWidth, trailLen)

            local trailModel = trail:CreateComponent("StaticModel")
            trailModel:SetModel(boxMdl)
            trailModel:SetMaterial(bulletTrailMats_[i])
            trails[i] = trail
        end

        -- ========== 曳光芯线（中心细长高亮线条） ==========
        local tracerLine = node:CreateChild("Tracer")
        tracerLine.scale = Vector3(0.02, 0.02, 2.2)
        tracerLine.position = Vector3(0, 0, -1.0)
        local tracerMdl = tracerLine:CreateComponent("StaticModel")
        tracerMdl:SetModel(boxMdl)
        tracerMdl:SetMaterial(bulletTipMat_)

        -- ========== 子弹尖端光点 ==========
        local tip = node:CreateChild("Tip")
        tip.position = Vector3(0, 0, 0.25)
        tip.scale = Vector3(0.05, 0.05, 0.05)
        local tipModel = tip:CreateComponent("StaticModel")
        tipModel:SetModel(sphereMdl)
        tipModel:SetMaterial(bulletTipMat_)

        -- 缓存子节点引用，避免每帧 GetChild 查找
        table_insert(bullets_, { node = node, age = 0, glowRef = glow, tracerRef = tracerLine, trailRefs = trails })
    end
end

function UpdateBullets(dt)
    local i = 1
    while i <= #bullets_ do
        local bullet = bullets_[i]
        local pos = bullet.node.position
        pos.z = pos.z + bulletSpeed_ * dt
        bullet.node.position = pos
        bullet.age = bullet.age + dt

        -- 曳光动态效果（三角波近似替代 sin，减少开销）
        local phase = (bullet.age * 35.0 + i * 5.0) % 6.2832
        local pulse = 0.85 + 0.15 * (1.0 - phase * 0.31831 * 2.0)  -- 近似三角波
        if phase > 3.1416 then pulse = 0.85 + 0.15 * ((phase - 3.1416) * 0.31831 * 2.0 - 1.0) end
        local glowRef = bullet.glowRef
        if glowRef then
            glowRef.scale = Vector3(0.15 * pulse, 0.15 * pulse, 0.6 + 0.08 * pulse)
        end

        -- 尾迹渐开（仅前0.2秒内计算）
        local trailRefs = bullet.trailRefs
        if trailRefs and bullet.age < 0.25 then
            local stretch = math_min(bullet.age * 5.0, 1.0)
            for ti = 1, 5 do
                local fade = 1.0 - (ti / 6)
                local tw = (0.09 * fade * fade + 0.015) * pulse
                local tl = (0.28 * fade + 0.06) * (0.4 + 0.6 * stretch)
                trailRefs[ti].scale = Vector3(tw, tw, tl)
            end
        end

        -- 超出范围移除
        if pos.z > 130 then
            bullet.node:Remove()
            table_remove(bullets_, i)
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 爆炸特效系统
-- ============================================================================

function SpawnExplosion(pos, size, color)
    local cr = color and color[1] or 0.9
    local cg = color and color[2] or 0.5
    local cb = color and color[3] or 0.2
    local sz = size or 1.0

    local explosion = { nodes = {}, age = 0, lifetime = 0.7 }

    -- 使用预缓存的爆炸材质（共享实例）
    local rayMat = explosionRayMat_
    local debrisMat = explosionDebrisMat_

    -- 1. 放射尖刺（4条，性能优化）
    local rayCount = 4
    local cylModel = mdlCylinder_
    for i = 1, rayCount do
        local n = scene_:CreateChild("ER")
        n.position = pos
        -- 均匀分布方向 + 少量随机偏移
        local a1 = (i - 1) / rayCount * 6.2832 + (math_random() - 0.5) * 0.6
        local a2 = (math_random() - 0.5) * 2.4
        local dx = math_cos(a1) * math_cos(a2)
        local dy = math_sin(a2)
        local dz = math_sin(a1) * math_cos(a2)
        -- 更大的初始尺寸
        local rayLen = (0.6 + math_random() * 0.5) * sz
        local rayThick = (0.04 + math_random() * 0.03) * sz
        n.scale = Vector3(rayThick, rayLen, rayThick)
        -- Cylinder 默认沿 Y 轴
        local dir = Vector3(dx, dy, dz):Normalized()
        n.rotation = Quaternion(Vector3.UP, dir)
        n.position = pos + dir * (rayLen * 0.5)

        local sm = n:CreateComponent("StaticModel")
        sm:SetModel(cylModel)
        sm:SetMaterial(rayMat)
        local spd = (6.0 + math_random() * 5.0) * sz
        table_insert(explosion.nodes, {
            node = n, type = "ray",
            dx = dx, dy = dy, dz = dz,
            spd = spd,
            baseLen = rayLen,
            thick = rayThick,
        })
    end

    -- 2. 中心光球（用发光模型替代动态点光源，大幅降低GPU开销）
    local lightNode = scene_:CreateChild("EL")
    lightNode.position = pos
    lightNode.scale = Vector3(0.8 * sz, 0.8 * sz, 0.8 * sz)
    local lgModel = lightNode:CreateComponent("StaticModel")
    lgModel:SetModel(mdlSphere_)
    local lgMat = explosionGlowBaseMat_:Clone("")
    lgMat:SetShaderParameter("MatDiffColor", Variant(Color(0, 0, 0, 0.3)))
    lgMat:SetShaderParameter("MatEmissiveColor", Variant(Color(cr * 8.0, cg * 8.0, cb * 8.0)))
    lgModel:SetMaterial(lgMat)
    lgModel.castShadows = false
    table_insert(explosion.nodes, { node = lightNode, type = "glow" })

    -- 3. 碎石（3块，够用即可）
    local boxModel = mdlBox_
    for i = 1, 3 do
        local n = scene_:CreateChild("ED")
        n.position = pos
        local a1 = math_random() * 6.2832
        local a2 = (math_random() - 0.5) * 2.8
        local spd = (4.0 + math_random() * 5.0) * sz
        local vx = math_cos(a1) * math_cos(a2) * spd
        local vy = math_sin(a2) * spd + math_random() * 2.5
        local vz = math_sin(a1) * math_cos(a2) * spd
        local ds = (0.06 + math_random() * 0.1) * sz
        n.scale = Vector3(ds * (0.5 + math_random()), ds * (0.4 + math_random() * 0.6), ds * (0.5 + math_random()))
        n.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)
        local sm = n:CreateComponent("StaticModel")
        sm:SetModel(boxModel)
        sm:SetMaterial(debrisMat)
        table_insert(explosion.nodes, {
            node = n, type = "rock",
            vx = vx, vy = vy, vz = vz,
            rotSpd = Vector3(math_random() * 400 - 200, math_random() * 400 - 200, math_random() * 400 - 200),
        })
    end

    table_insert(explosions_, explosion)
end

function UpdateExplosions(dt)
    local i = 1
    while i <= #explosions_ do
        local exp = explosions_[i]
        exp.age = exp.age + dt
        local p = exp.age / exp.lifetime  -- 0~1

        if p >= 1.0 then
            for _, item in ipairs(exp.nodes) do
                item.node:Remove()
            end
            table_remove(explosions_, i)
        else
            for _, item in ipairs(exp.nodes) do
                local itype = item.type
                if itype == "ray" then
                    -- 射线快速伸长后缩短消失
                    local grow = math_min(p * 10.0, 1.0) -- 前10%爆发伸长
                    local shrink = math_max(0, (p - 0.25) * 1.3333) -- 25%后缩短 (1/0.75)
                    local lenMul = grow * 3.5 * (1.0 - shrink * shrink)
                    local curLen = item.baseLen * lenMul
                    local curThick = item.thick * (1.0 - p * 0.7)
                    if curLen < 0.001 then curLen = 0.001 end
                    if curThick < 0.002 then curThick = 0.002 end
                    item.node.scale = Vector3(curThick, curLen, curThick)
                    -- 射线沿方向外移（dx/dy/dz 直接内联计算避免创建 Vector3）
                    local moveD = item.spd * dt * (1.0 - p * 0.5)
                    local pos = item.node.position
                    pos.x = pos.x + item.dx * moveD
                    pos.y = pos.y + item.dy * moveD
                    pos.z = pos.z + item.dz * moveD
                    item.node.position = pos

                elseif itype == "glow" then
                    -- 光球快速缩小淡出
                    local glowScale = 0.8 * (1.0 - p * p)
                    if glowScale < 0.01 then glowScale = 0.01 end
                    item.node.scale = Vector3(glowScale, glowScale, glowScale)

                elseif itype == "rock" then
                    -- 碎石飞散 + 旋转 + 重力 + 缩小
                    local slow = 1.0 - p * 0.5
                    local pos = item.node.position
                    pos.x = pos.x + item.vx * dt * slow
                    pos.y = pos.y + item.vy * dt * slow - 5.0 * dt * p
                    pos.z = pos.z + item.vz * dt * slow
                    item.node.position = pos
                    -- 旋转隔帧更新（减少 Quaternion 创建）
                    if frameCount_ % 2 == 0 then
                        local rs = item.rotSpd
                        item.node:Rotate(Quaternion(
                            rs.x * dt * 2.0, rs.y * dt * 2.0, rs.z * dt * 2.0))
                    end
                    if p > 0.4 then
                        local sc = item.node.scale
                        local shrinkF = 1.0 - dt * 3.0
                        item.node.scale = Vector3(sc.x * shrinkF, sc.y * shrinkF, sc.z * shrinkF)
                    end
                end
            end
            i = i + 1
        end
    end
end

-- ============================================================================
-- 护盾系统
-- ============================================================================

function UpdateShield(dt)
    -- 冷却计时
    if shieldCoolTimer_ > 0 then
        shieldCoolTimer_ = math_max(0, shieldCoolTimer_ - dt)
    end

    -- 护盾展开/消散动画
    if shieldAnimState_ ~= "none" and shieldNode_ then
        shieldAnimTimer_ = shieldAnimTimer_ + dt
        local progress = math_min(shieldAnimTimer_ / shieldAnimTime_, 1.0)

        if shieldAnimState_ == "expanding" then
            -- 由中心向外展开：scale 从0到1，easeOutCubic
            local t = 1.0 - progress
            local s = 1.0 - t * t * t
            shieldNode_:SetScale(Vector3(s, s, s))
        else
            -- 由内向外消散：scale 继续放大（1→1.5），同时透明度衰减到0
            local eased = progress * progress  -- easeIn: 先慢后快
            local s = 1.0 + 0.5 * eased        -- scale: 1.0 → 1.5
            local alpha = 1.0 - eased           -- 透明度: 1.0 → 0
            shieldNode_:SetScale(Vector3(s, s, s))
            -- 衰减两层材质透明度
            shieldPulseMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.7, 1.0, 0.08 * alpha)))
            shieldPulseMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8 * alpha, 2.0 * alpha, 5.0 * alpha)))
            if shieldFillMat_ then
                shieldFillMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.7, 0.9, 0.5 * alpha)))
                shieldFillMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05 * alpha, 0.12 * alpha, 0.3 * alpha)))
            end
        end

        if progress >= 1.0 then
            if shieldAnimState_ == "collapsing" then
                -- 消散完毕，关闭护盾并恢复材质参数
                shieldNode_:SetEnabled(false)
                shieldNode_:SetScale(Vector3(1, 1, 1))
                shieldPulseMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.7, 1.0, 0.08)))
                shieldPulseMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8, 2.0, 5.0)))
                if shieldFillMat_ then
                    shieldFillMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.7, 0.9, 0.5)))
                    shieldFillMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.12, 0.3)))
                end
                shieldCoolTimer_ = shieldCooldown_
            end
            shieldAnimState_ = "none"
        end
    end

    -- 护盾激活中
    if shieldActive_ then
        shieldTimer_ = shieldTimer_ - dt
        -- 蜂巢护盾动态效果：缓慢旋转 + 脉冲发光
        if shieldNode_ then
            shieldNode_:Rotate(Quaternion(0, 0, 25 * dt))
            -- 脉冲发光强度（蜂巢荧光闪烁）—— 仅更新 shader 参数，不创建新材质
            local pulse = 0.6 + 0.4 * math_sin(time.elapsedTime * 4.0)
            local flicker = 0.85 + 0.15 * math_sin(time.elapsedTime * 11.0)  -- 高频微闪
            local glow = pulse * flicker
            shieldPulseMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.7, 1.0, 0.05 + 0.06 * glow)))
            shieldPulseMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8 * glow, 2.0 * glow, 5.0 * glow)))
        end
        if shieldTimer_ <= 0 then
            -- 护盾时间结束，开始收回动画
            shieldActive_ = false
            shieldAnimState_ = "collapsing"
            shieldAnimTimer_ = 0
        end
    else
        -- 右键激活护盾
        if shieldCoolTimer_ <= 0 and shieldAnimState_ == "none" and input:GetMouseButtonPress(MOUSEB_RIGHT) then
            shieldActive_ = true
            shieldTimer_ = shieldDuration_
            if shieldNode_ then
                shieldNode_:SetEnabled(true)
                shieldNode_:SetScale(Vector3(0.01, 0.01, 0.01))  -- 从极小开始
            end
            shieldAnimState_ = "expanding"
            shieldAnimTimer_ = 0
        end
    end
end

-- ============================================================================
-- 小行星系统
-- ============================================================================

function UpdateAsteroids(dt)
    asteroidSpawnTimer_ = asteroidSpawnTimer_ + dt
    if asteroidSpawnTimer_ >= asteroidSpawnInterval_ then
        asteroidSpawnTimer_ = 0
        SpawnAsteroid()
    end

    local i = 1
    while i <= #asteroids_ do
        local asteroid = asteroids_[i]
        local pos = asteroid.node.position
        pos.z = pos.z - speed_ * dt
        asteroid.node.position = pos

        -- 旋转（隔帧更新，节省性能）
        if (frameCount_ + i) % 2 == 0 then
            asteroid.node:Rotate(Quaternion(
                asteroid.rotSpeed.x * dt * 2,
                asteroid.rotSpeed.y * dt * 2,
                asteroid.rotSpeed.z * dt * 2
            ))
        end

        -- 超出视野移除
        if pos.z < -10 then
            asteroid.node:Remove()
            table_remove(asteroids_, i)
        else
            i = i + 1
        end
    end
end

-- 生成不规则多面体顶点（扰动正二十面体）
local function GenerateRockVertices(subdivLevel, jitter)
    -- 正二十面体基础顶点
    local phi = (1.0 + math_sqrt(5.0)) / 2.0
    local baseVerts = {
        Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
        Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
        Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1),
    }
    -- 归一化到单位球
    for i, v in ipairs(baseVerts) do
        local len = math_sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        baseVerts[i] = Vector3(v.x / len, v.y / len, v.z / len)
    end
    -- 正二十面体面索引（1-based）
    local faces = {
        {1,12,6}, {1,6,2}, {1,2,8}, {1,8,11}, {1,11,12},
        {2,6,10}, {6,12,5}, {12,11,3}, {11,8,7}, {8,2,9},
        {4,10,5}, {4,5,3}, {4,3,7}, {4,7,9}, {4,9,10},
        {5,10,6}, {3,5,12}, {7,3,11}, {9,7,8}, {10,9,2},
    }

    -- 细分一次
    if subdivLevel >= 1 then
        local newFaces = {}
        local midCache = {}
        local function getMid(ia, ib)
            local key = math_min(ia, ib) .. "_" .. math_max(ia, ib)
            if midCache[key] then return midCache[key] end
            local a = baseVerts[ia]
            local b = baseVerts[ib]
            local mx = (a.x + b.x) * 0.5
            local my = (a.y + b.y) * 0.5
            local mz = (a.z + b.z) * 0.5
            local len = math_sqrt(mx*mx + my*my + mz*mz)
            table_insert(baseVerts, Vector3(mx/len, my/len, mz/len))
            local idx = #baseVerts
            midCache[key] = idx
            return idx
        end
        for _, f in ipairs(faces) do
            local a, b, c = f[1], f[2], f[3]
            local ab = getMid(a, b)
            local bc = getMid(b, c)
            local ca = getMid(c, a)
            table_insert(newFaces, {a, ab, ca})
            table_insert(newFaces, {b, bc, ab})
            table_insert(newFaces, {c, ca, bc})
            table_insert(newFaces, {ab, bc, ca})
        end
        faces = newFaces
    end

    -- 对每个顶点施加随机扰动（使球变成不规则岩石）
    for i, v in ipairs(baseVerts) do
        local distort = 1.0 + (math_random() - 0.5) * jitter
        baseVerts[i] = Vector3(v.x * distort, v.y * distort, v.z * distort)
    end

    return baseVerts, faces
end

-- 预生成岩石网格数据池（启动时一次性计算，SpawnAsteroid 随机选取）
local function InitAsteroidMeshPool()
    for poolIdx = 1, asteroidMeshPoolSize_ do
        local verts, faces = GenerateRockVertices(1, 0.6)
        asteroidMeshPool_[poolIdx] = { verts = verts, faces = faces }
    end
end
InitAsteroidMeshPool()

function SpawnAsteroid()
    local node = scene_:CreateChild("Asteroid")
    local x = math_random() * moveRangeX_ * 2 - moveRangeX_
    local y = math_random() * moveRangeY_ * 2 - moveRangeY_
    local z = 80 + math_random() * 40
    node.position = Vector3(x, y, z)

    local baseSize = 0.7 + math_random() * 1.0

    -- 用 CustomGeometry 生成不规则岩石多面体（从预生成池随机选取）
    local geom = node:CreateComponent("CustomGeometry")
    local meshData = asteroidMeshPool_[math_random(1, asteroidMeshPoolSize_)]
    local verts, faces = meshData.verts, meshData.faces

    -- 使用预缓存岩石色调
    local colorIdx = math_random(1, 6)
    local colorPresets = {
        { 0.25, 0.22, 0.18 },
        { 0.35, 0.30, 0.25 },
        { 0.18, 0.18, 0.20 },
        { 0.30, 0.28, 0.22 },
        { 0.15, 0.12, 0.10 },
        { 0.40, 0.32, 0.20 },
    }
    local c = colorPresets[colorIdx]
    local cr = c[1] + (math_random() - 0.5) * 0.08
    local cg = c[2] + (math_random() - 0.5) * 0.06
    local cb = c[3] + (math_random() - 0.5) * 0.05

    -- 构建三角形网格
    geom:BeginGeometry(0, TRIANGLE_LIST)
    for _, f in ipairs(faces) do
        local v1 = verts[f[1]]
        local v2 = verts[f[2]]
        local v3 = verts[f[3]]

        -- 计算面法线
        local e1x, e1y, e1z = v2.x - v1.x, v2.y - v1.y, v2.z - v1.z
        local e2x, e2y, e2z = v3.x - v1.x, v3.y - v1.y, v3.z - v1.z
        local nx = e1y * e2z - e1z * e2y
        local ny = e1z * e2x - e1x * e2z
        local nz = e1x * e2y - e1y * e2x
        local nlen = math_sqrt(nx*nx + ny*ny + nz*nz)
        if nlen > 0.0001 then nx = nx/nlen; ny = ny/nlen; nz = nz/nlen end
        local normal = Vector3(nx, ny, nz)

        -- 每个面微调颜色（模拟岩石纹理差异）
        local faceShade = 0.85 + math_random() * 0.3

        geom:DefineVertex(v1 * baseSize * 0.5)
        geom:DefineNormal(normal)
        geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))

        geom:DefineVertex(v2 * baseSize * 0.5)
        geom:DefineNormal(normal)
        geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))

        geom:DefineVertex(v3 * baseSize * 0.5)
        geom:DefineNormal(normal)
        geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))
    end
    geom:Commit()

    -- 使用预缓存的岩石材质
    geom:SetMaterial(asteroidRockMats_[colorIdx])
    geom.castShadows = false

    -- 1个表面碎石（增加质感）
    local sphereMdl = mdlSphere_
    local debris = node:CreateChild("Debris")
    local angle1 = math_random() * math_pi * 2
    local angle2 = (math_random() - 0.5) * math_pi
    local dist = baseSize * 0.5 * (0.75 + math_random() * 0.2)
    debris.position = Vector3(
        math_cos(angle1) * math_cos(angle2) * dist,
        math_sin(angle2) * dist,
        math_sin(angle1) * math_cos(angle2) * dist
    )
    local dSize = baseSize * (0.12 + math_random() * 0.18)
    debris.scale = Vector3(
        dSize * (0.6 + math_random() * 0.8),
        dSize * (0.5 + math_random() * 0.6),
        dSize * (0.6 + math_random() * 0.8)
    )
    debris.rotation = Quaternion(math_random()*360, math_random()*360, math_random()*360)
    local dModel = debris:CreateComponent("StaticModel")
    dModel:SetModel(sphereMdl)
    dModel:SetMaterial(asteroidDebrisMats_[colorIdx])
    dModel.castShadows = false

    -- 20% 概率: 熔岩裂缝（自发光球，无点光源）
    if math_random() < 0.20 then
        local crack = node:CreateChild("Crack")
        crack.position = Vector3(0, 0, 0)
        crack.scale = Vector3(0.4, 0.4, 0.4) * baseSize
        local crackModel = crack:CreateComponent("StaticModel")
        crackModel:SetModel(sphereMdl)
        crackModel:SetMaterial(asteroidCrackMat_)
    end

    -- 15% 概率: 冰晶矿脉（1个矿石，减少子节点）
    if math_random() < 0.15 then
        local boxMdl = mdlBox_
        local ore = node:CreateChild("Ore")
        local oa1 = math_random() * math_pi * 2
        local oa2 = (math_random() - 0.5) * math_pi * 0.8
        local oDist = baseSize * 0.5 * (0.8 + math_random() * 0.15)
        ore.position = Vector3(
            math_cos(oa1) * math_cos(oa2) * oDist,
            math_sin(oa2) * oDist,
            math_sin(oa1) * math_cos(oa2) * oDist
        )
        local oSize = baseSize * (0.08 + math_random() * 0.1)
        ore.scale = Vector3(oSize, oSize * (1.5 + math_random()), oSize)
        ore.rotation = Quaternion(math_random()*360, math_random()*360, math_random()*360)

        local oModel = ore:CreateComponent("StaticModel")
        oModel:SetModel(boxMdl)
        oModel:SetMaterial(asteroidOreMat_)
    end

    node.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

    table_insert(asteroids_, {
        node = node,
        radius = baseSize * 0.55,
        rotSpeed = Vector3(
            math_random() * 30 - 15,
            math_random() * 30 - 15,
            math_random() * 30 - 15
        )
    })
end

-- ============================================================================
-- 能量水晶系统
-- ============================================================================

function UpdateCrystals(dt)
    crystalSpawnTimer_ = crystalSpawnTimer_ + dt
    if crystalSpawnTimer_ >= crystalSpawnInterval_ then
        crystalSpawnTimer_ = 0
        if #crystals_ < 3 then
            SpawnCrystal()
        end
    end

    -- 水晶呼吸灯效果（共享材质，每3帧更新一次）
    crystalMatFrame_ = (crystalMatFrame_ or 0) + 1
    if crystalMatFrame_ % 3 == 0 then
        local t = time.elapsedTime
        local glow = 0.6 + 0.4 * math_sin(t * 2.5)
        local crystalBaseColors = { {0.2, 1.0, 0.4}, {0.3, 0.6, 1.0}, {1.0, 0.8, 0.2} }
        for idx, c in ipairs(crystalBaseColors) do
            if crystalMats_[idx] then
                crystalMats_[idx]:SetShaderParameter("MatEmissiveColor",
                    Variant(Color(c[1] * 2.5 * glow, c[2] * 2.5 * glow, c[3] * 2.5 * glow)))
            end
        end
    end

    -- 水晶旋转隔帧更新，降低旋转速度节省性能
    local crystalRotFrame = (frameCount_ % 2 == 0)
    local rotQ = nil
    if crystalRotFrame then
        rotQ = Quaternion(15 * dt * 2, 60 * dt * 2, 8 * dt * 2)
    end

    local i = 1
    while i <= #crystals_ do
        local crystal = crystals_[i]
        local pos = crystal.node.position
        pos.z = pos.z - speed_ * dt
        crystal.node.position = pos

        if crystalRotFrame then
            crystal.node:Rotate(rotQ)
        end

        if pos.z < -10 then
            crystal.node:Remove()
            table_remove(crystals_, i)
        else
            i = i + 1
        end
    end
end

function SpawnCrystal()
    local node = scene_:CreateChild("Crystal")
    local x = math_random() * moveRangeX_ * 1.5 - moveRangeX_ * 0.75
    local y = math_random() * moveRangeY_ * 1.5 - moveRangeY_ * 0.75
    local z = 80 + math_random() * 30
    node.position = Vector3(x, y, z)
    -- 随机初始旋转
    node.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

    local colors = {
        { 0.2, 1.0, 0.4 },
        { 0.3, 0.6, 1.0 },
        { 1.0, 0.8, 0.2 },
    }
    local colorIdx = math_random(1, #colors)
    local c = colors[colorIdx]

    -- 四棱水晶造型（CustomGeometry，比六棱省40%顶点）
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local sides = 4
    local radius = 0.38       -- 腰部半径（稍大补偿棱数减少）
    local halfBody = 0.5      -- 柱体半高
    local tipHeight = 0.6     -- 尖端高度

    -- 生成腰部顶点（上环和下环）
    local topRing = {}
    local botRing = {}
    for i = 1, sides do
        local angle = 2 * math_pi * (i - 1) / sides + 0.785  -- 旋转45°更好看
        local cx = math_cos(angle) * radius
        local cz = math_sin(angle) * radius
        topRing[i] = Vector3(cx, halfBody, cz)
        botRing[i] = Vector3(cx, -halfBody, cz)
    end
    local topTip = Vector3(0, halfBody + tipHeight, 0)
    local botTip = Vector3(0, -(halfBody + tipHeight), 0)

    -- 辅助：添加三角形
    local function AddFace(p1, p2, p3)
        local e1 = p2 - p1
        local e2 = p3 - p1
        local n = e1:CrossProduct(e2):Normalized()
        geom:DefineVertex(p1); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(0, 0))
        geom:DefineVertex(p2); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(1, 0))
        geom:DefineVertex(p3); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(0, 1))
    end

    for i = 1, sides do
        local next = (i % sides) + 1
        AddFace(topTip, topRing[i], topRing[next])
        AddFace(botTip, botRing[next], botRing[i])
        AddFace(topRing[i], botRing[i], botRing[next])
        AddFace(topRing[i], botRing[next], topRing[next])
    end

    geom:Commit()

    -- 水晶材质（自发光足够明亮，不再需要点光源）
    geom:SetMaterial(crystalMats_[colorIdx])

    table_insert(crystals_, {
        node = node,
        radius = crystalRadius_,
    })
end

-- ============================================================================
-- 背景星尘更新
-- ============================================================================

function UpdateStarDusts(dt)
    local currentSpeed = speed_
    if gameState_ ~= STATE_PLAYING then
        -- 菜单呼吸速度：20~60 km/s 缓慢起伏
        local breath = (math_sin(time.elapsedTime * 0.4) + 1) * 0.5
        currentSpeed = 20 + breath * 40
    end

    local dusts = starDusts_
    for i = 1, #dusts do
        local dust = dusts[i]
        local node = dust.node
        local pos = node.position
        local newZ = pos.z - (currentSpeed + dust.speed) * dt

        if newZ < -20 then
            pos.z = 150 + math_random() * 50
            pos.x = math_random() * 60 - 30
            pos.y = math_random() * 40 - 20
        else
            pos.z = newZ
        end

        node.position = pos
    end
end

-- ============================================================================
-- 深空星河背景（BillboardSet，创建后完全静态，零每帧开销）
-- ============================================================================

function CreateStarfield()
    starfieldNode_ = scene_:CreateChild("Starfield")
    starfieldNode_.position = Vector3(0, 0, 0)

    starfieldBBS_ = starfieldNode_:CreateComponent("BillboardSet")
    local bbs = starfieldBBS_
    bbs.numBillboards = 500
    bbs.sorted = false          -- 静态不需要排序
    bbs.relative = false        -- 世界坐标
    bbs.scaled = false
    bbs.faceCameraMode = FC_ROTATE_XYZ

    -- 无纹理自发光材质（白色基底，星点颜色由 billboard.color 控制）
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 1.0, 1.0, 1.0)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(3.0, 3.0, 3.0)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    bbs:SetMaterial(mat)

    -- 星点颜色调色板（模拟真实恒星光谱）
    local palette = {
        Color(1.0, 1.0, 1.0, 0.9),     -- 白色（最常见）
        Color(0.8, 0.85, 1.0, 0.9),    -- 蓝白
        Color(0.6, 0.7, 1.0, 0.85),    -- 淡蓝
        Color(1.0, 0.95, 0.7, 0.85),   -- 暖黄
        Color(1.0, 0.8, 0.5, 0.8),     -- 橙色
        Color(1.0, 0.6, 0.6, 0.75),    -- 淡红
        Color(0.7, 0.6, 1.0, 0.8),     -- 淡紫
        Color(0.5, 1.0, 0.9, 0.8),     -- 青色
    }

    for i = 0, 499 do
        local bb = bbs:GetBillboard(i)
        -- 分布在远景大范围球壳内（Z 80~550，XY 超广散布）
        local x = (math_random() - 0.5) * 220
        local y = (math_random() - 0.5) * 150
        local z = 80 + math_random() * 470
        bb.position = Vector3(x, y, z)

        -- 随机大小（远处的点更小）
        local baseSize = 0.04 + math_random() * 0.12
        bb.size = Vector2(baseSize, baseSize)

        -- 选颜色：70% 白/蓝白，30% 彩色
        local colorIdx
        if math_random() < 0.7 then
            colorIdx = math_random(1, 3)  -- 白/蓝白/淡蓝
        else
            colorIdx = math_random(1, #palette)
        end
        bb.color = palette[colorIdx]
        bb.rotation = math_random() * 360
        bb.enabled = true

        -- 25% 标记为呼吸星点
        if math_random() < 0.25 then
            local idx = #starBreathIndices_ + 1
            starBreathIndices_[idx] = i
            starBreathBaseSize_[idx] = baseSize
            starBreathPhase_[idx] = math_random() * 6.283
        end
    end

    bbs:Commit()
end

-- 星河呼吸更新（每 3 帧执行一次）
local starBreathFrame_ = 0
function UpdateStarfieldBreath()
    starBreathFrame_ = starBreathFrame_ + 1
    if starBreathFrame_ % 3 ~= 0 then return end

    local t = time.elapsedTime * 1.8
    for i = 1, #starBreathIndices_ do
        local bb = starfieldBBS_:GetBillboard(starBreathIndices_[i])
        local s = starBreathBaseSize_[i] * (0.7 + 0.5 * math_sin(t + starBreathPhase_[i]))
        bb.size = Vector2(s, s)
    end
    starfieldBBS_:Commit()
end

-- ============================================================================
-- 流星系统（彩虹弧线，三五成群，屏幕上半部缓慢划过）
-- ============================================================================

-- 彩虹色表（7色循环）
local meteorRainbow_ = {
    { 1.0, 0.2, 0.2 },  -- 红
    { 1.0, 0.6, 0.1 },  -- 橙
    { 1.0, 1.0, 0.2 },  -- 黄
    { 0.2, 1.0, 0.3 },  -- 绿
    { 0.2, 0.7, 1.0 },  -- 蓝
    { 0.4, 0.2, 1.0 },  -- 靛
    { 0.8, 0.3, 1.0 },  -- 紫
}

local function InitMeteorTrail(m)
    -- 起点：屏幕上半部分，从左侧或右侧入场
    local side = (math_random() > 0.5) and 1 or -1
    local startX = -side * (20 + math_random() * 15)
    local startY = 8 + math_random() * 12
    local startZ = 40 + math_random() * 60

    m.px = startX
    m.py = startY
    m.pz = startZ

    -- 初始方向（横向为主 + 轻微斜向）
    m.dirAngle = (side > 0) and (math_random() * 0.3 - 0.15) or (math_pi + math_random() * 0.3 - 0.15)
    m.dirPitch = (math_random() - 0.5) * 0.2

    -- 弧度：角速度让方向缓慢弯曲
    m.curvature = (math_random() - 0.5) * 0.35
    m.pitchCurve = (math_random() - 0.5) * 0.1

    m.speed = 5 + math_random() * 8   -- 缓慢
    m.life = 0
    m.maxLife = 3.0 + math_random() * 3.0
    m.trailLen = 18 + math_random(0, 8)  -- 轨迹段数
    m.colorOffset = math_random(0, 6)    -- 彩虹色相偏移

    -- 清空轨迹历史
    m.history = {}
    m.active = true
    m.node:SetEnabled(true)
end

function CreateMeteors()
    -- 预创建 12 条弧线流星（同时最多 3~4 群，每群 3~4 条）
    local count = 12
    for i = 1, count do
        local node = scene_:CreateChild("MeteorTrail")
        local geom = node:CreateComponent("CustomGeometry")
        geom:SetMaterial(meteorMat_)
        geom.castShadows = false
        node:SetEnabled(false)

        local m = {
            node = node, geom = geom, active = false,
            px = 0, py = 0, pz = 0,
            dirAngle = 0, dirPitch = 0,
            curvature = 0, pitchCurve = 0,
            speed = 6, life = 0, maxLife = 4.0,
            trailLen = 20, colorOffset = 0,
            history = {},
        }
        table_insert(meteors_, m)
    end

    meteorNextGroupTime_ = time.elapsedTime + 0.5 + math_random() * 1.5
end

local function SpawnMeteorGroup()
    -- 3~5 条一组，共享大致起点和方向
    local groupSize = 3 + math_random(0, 2)
    local assigned = 0
    for _, m in ipairs(meteors_) do
        if assigned >= groupSize then break end
        if not m.active then
            InitMeteorTrail(m)
            -- 群内每条略有偏移
            m.py = m.py + (assigned - 1) * (1.5 + math_random() * 1.0)
            m.pz = m.pz + (math_random() - 0.5) * 8
            m.life = -assigned * (0.3 + math_random() * 0.4)  -- 逐条延迟
            m.node:SetEnabled(false)
            assigned = assigned + 1
        end
    end
end

function UpdateMeteors(dt)
    -- 定时触发新群组
    if time.elapsedTime >= meteorNextGroupTime_ then
        SpawnMeteorGroup()
        meteorNextGroupTime_ = time.elapsedTime + 90.0 + math_random() * 30.0
    end

    -- 流星隔帧更新几何（视觉无差异，性能减半）
    local rebuildGeom = (frameCount_ % 2 == 0)

    for _, m in ipairs(meteors_) do
        if m.active then
            m.life = m.life + dt

            -- 延迟出发
            if m.life < 0 then
                m.node:SetEnabled(false)
            else
                m.node:SetEnabled(true)

                if m.life >= m.maxLife then
                    m.active = false
                    m.node:SetEnabled(false)
                else
                    -- 更新方向（弧度弯曲）
                    m.dirAngle = m.dirAngle + m.curvature * dt
                    m.dirPitch = m.dirPitch + m.pitchCurve * dt

                    -- 计算速度分量
                    local cosP = math_cos(m.dirPitch)
                    local vx = math_cos(m.dirAngle) * cosP * m.speed
                    local vy = math_sin(m.dirPitch) * m.speed
                    local vz = math_sin(m.dirAngle) * cosP * m.speed * 0.3

                    -- 移动头部
                    m.px = m.px + vx * dt
                    m.py = m.py + vy * dt
                    m.pz = m.pz + vz * dt

                    -- 环形缓冲记录轨迹（避免 table_insert(1) 的 O(n) 开销）
                    local head = (m.historyHead or 0) + 1
                    if head > m.trailLen then head = 1 end
                    m.historyHead = head
                    local historyCount = m.historyCount or 0
                    if historyCount < m.trailLen then
                        historyCount = historyCount + 1
                        m.historyCount = historyCount
                    end
                    -- 复用已有table或创建
                    if m.history[head] then
                        m.history[head].x = m.px
                        m.history[head].y = m.py
                        m.history[head].z = m.pz
                    else
                        m.history[head] = { x = m.px, y = m.py, z = m.pz }
                    end

                    -- 隔帧重建 CustomGeometry
                    if rebuildGeom then
                        local geom = m.geom
                        local numPts = historyCount
                        if numPts >= 2 then
                            geom:BeginGeometry(0, TRIANGLE_STRIP)
                            local thickness = 0.06
                            local fadeIn = m.life < 0.5 and (m.life / 0.5) or 1.0
                            local fadeOut = (m.maxLife - m.life < 1.0) and ((m.maxLife - m.life) / 1.0) or 1.0
                            local masterAlpha = fadeIn * fadeOut
                            local invNumPts = 1.0 / numPts

                            -- 从最新点往回遍历环形缓冲
                            local idx = head
                            for pi = 1, numPts do
                                local p = m.history[idx]
                                local tAlpha = (1.0 - (pi - 1) * invNumPts) * masterAlpha
                                local cIdx = ((pi + m.colorOffset - 1) % 7) + 1
                                local rc = meteorRainbow_[cIdx]
                                local emissive = 2.0 * tAlpha
                                local halfW = thickness * tAlpha * 0.5
                                local er = rc[1] * emissive
                                local eg = rc[2] * emissive
                                local eb = rc[3] * emissive

                                geom:DefineVertex(Vector3(p.x, p.y + halfW, p.z))
                                geom:DefineNormal(Vector3.UP)
                                geom:DefineColor(Color(er, eg, eb, tAlpha))

                                geom:DefineVertex(Vector3(p.x, p.y - halfW, p.z))
                                geom:DefineNormal(Vector3.UP)
                                geom:DefineColor(Color(er, eg, eb, tAlpha))

                                idx = idx - 1
                                if idx < 1 then idx = m.trailLen end
                            end
                            geom:Commit()
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 航道外装饰陨石（纯视觉，无碰撞，极低性能开销）
-- ============================================================================

function CreateDecoAsteroids()
    local count = 12  -- 少量即可营造氛围
    -- 装饰陨石暗色色调（比游戏内更暗，远景氛围）
    local decoColors = {
        { 0.12, 0.10, 0.09 },
        { 0.15, 0.13, 0.11 },
        { 0.09, 0.09, 0.11 },
        { 0.14, 0.12, 0.10 },
        { 0.07, 0.06, 0.06 },
        { 0.18, 0.14, 0.09 },
    }
    for i = 1, count do
        local node = scene_:CreateChild("DecoAsteroid")
        -- 位于航道外围，不接触飞船飞行轨道
        local side = (i % 2 == 0) and 1 or -1
        local x = side * (moveRangeX_ + 5.0 + math_random() * 8.0)
        -- Y 也保持在轨道外（上方或下方）
        local ySide = (math_random() > 0.5) and 1 or -1
        local y = ySide * (moveRangeY_ + 2.5 + math_random() * 6.0)
        local z = math_random() * 160 - 10
        node.position = Vector3(x, y, z)

        local baseSize = 0.8 + math_random() * 2.0
        node.scale = Vector3(
            baseSize * (0.7 + math_random() * 0.6),
            baseSize * (0.6 + math_random() * 0.5),
            baseSize * (0.7 + math_random() * 0.6)
        )
        node.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

        -- 使用 CustomGeometry 多面体岩石（从预生成池选取）
        local geom = node:CreateComponent("CustomGeometry")
        local meshData = asteroidMeshPool_[math_random(1, asteroidMeshPoolSize_)]
        local verts, faces = meshData.verts, meshData.faces

        local c = decoColors[math_random(1, #decoColors)]
        local cr = c[1] + (math_random() - 0.5) * 0.04
        local cg = c[2] + (math_random() - 0.5) * 0.03
        local cb = c[3] + (math_random() - 0.5) * 0.03

        geom:BeginGeometry(0, TRIANGLE_LIST)
        for _, f in ipairs(faces) do
            local v1 = verts[f[1]]
            local v2 = verts[f[2]]
            local v3 = verts[f[3]]

            -- 面法线
            local e1x, e1y, e1z = v2.x - v1.x, v2.y - v1.y, v2.z - v1.z
            local e2x, e2y, e2z = v3.x - v1.x, v3.y - v1.y, v3.z - v1.z
            local nx = e1y * e2z - e1z * e2y
            local ny = e1z * e2x - e1x * e2z
            local nz = e1x * e2y - e1y * e2x
            local nlen = math_sqrt(nx*nx + ny*ny + nz*nz)
            if nlen > 0.0001 then nx = nx/nlen; ny = ny/nlen; nz = nz/nlen end
            local normal = Vector3(nx, ny, nz)

            -- 每个面微调颜色（模拟岩石纹理差异）
            local faceShade = 0.8 + math_random() * 0.4

            geom:DefineVertex(v1)
            geom:DefineNormal(normal)
            geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))

            geom:DefineVertex(v2)
            geom:DefineNormal(normal)
            geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))

            geom:DefineVertex(v3)
            geom:DefineNormal(normal)
            geom:DefineColor(Color(cr * faceShade, cg * faceShade, cb * faceShade, 1.0))
        end
        geom:Commit()
        geom:SetMaterial(decoAsteroidMat_)
        geom.castShadows = false

        -- 附加1个小碎石增加质感
        local debris = node:CreateChild("DecoDebris")
        local angle1 = math_random() * math_pi * 2
        local angle2 = (math_random() - 0.5) * math_pi
        local dist = 0.55 + math_random() * 0.2
        debris.position = Vector3(
            math_cos(angle1) * math_cos(angle2) * dist,
            math_sin(angle2) * dist,
            math_sin(angle1) * math_cos(angle2) * dist
        )
        local dSize = 0.15 + math_random() * 0.2
        debris.scale = Vector3(
            dSize * (0.6 + math_random() * 0.8),
            dSize * (0.5 + math_random() * 0.6),
            dSize * (0.6 + math_random() * 0.8)
        )
        debris.rotation = Quaternion(math_random()*360, math_random()*360, math_random()*360)
        local dModel = debris:CreateComponent("StaticModel")
        dModel:SetModel(mdlSphere_)
        dModel:SetMaterial(decoAsteroidMat_)
        dModel.castShadows = false

        table_insert(decoAsteroids_, {
            node = node,
            origScale = node.scale,
            scale = 1.0,
            rotSpeed = Vector3(
                (math_random() - 0.5) * 8,
                (math_random() - 0.5) * 8,
                (math_random() - 0.5) * 8
            ),
            driftSpeed = 0.5 + math_random() * 1.5,
        })
    end

    -- === 细小碎石散布（轨道外更广区域，增加空间层次感） ===
    local smallCount = 24
    for i = 1, smallCount do
        local sNode = scene_:CreateChild("DecoSmallRock")
        -- 分布范围比大陨石更广，但不侵入飞船轨道
        local side = (i % 2 == 0) and 1 or -1
        local x = side * (moveRangeX_ + 3.5 + math_random() * 14.0)
        local ySide = (math_random() > 0.5) and 1 or -1
        local y = ySide * (moveRangeY_ + 1.5 + math_random() * 8.0)
        local z = math_random() * 180 - 20
        sNode.position = Vector3(x, y, z)

        local sSize = 0.1 + math_random() * 0.35
        sNode.scale = Vector3(
            sSize * (0.6 + math_random() * 0.8),
            sSize * (0.5 + math_random() * 0.7),
            sSize * (0.6 + math_random() * 0.8)
        )
        sNode.rotation = Quaternion(math_random() * 360, math_random() * 360, math_random() * 360)

        -- 细小碎石用简单 CustomGeometry（从 mesh pool 取形状）
        local geom = sNode:CreateComponent("CustomGeometry")
        local meshData = asteroidMeshPool_[math_random(1, asteroidMeshPoolSize_)]
        local verts, faces = meshData.verts, meshData.faces

        local shade = 0.05 + math_random() * 0.08
        geom:BeginGeometry(0, TRIANGLE_LIST)
        for _, f in ipairs(faces) do
            local v1 = verts[f[1]]
            local v2 = verts[f[2]]
            local v3 = verts[f[3]]

            local e1x, e1y, e1z = v2.x - v1.x, v2.y - v1.y, v2.z - v1.z
            local e2x, e2y, e2z = v3.x - v1.x, v3.y - v1.y, v3.z - v1.z
            local nx = e1y * e2z - e1z * e2y
            local ny = e1z * e2x - e1x * e2z
            local nz = e1x * e2y - e1y * e2x
            local nlen = math_sqrt(nx*nx + ny*ny + nz*nz)
            if nlen > 0.0001 then nx = nx/nlen; ny = ny/nlen; nz = nz/nlen end
            local normal = Vector3(nx, ny, nz)

            local fs = 0.75 + math_random() * 0.5
            geom:DefineVertex(v1)
            geom:DefineNormal(normal)
            geom:DefineColor(Color(shade * fs, shade * fs * 0.9, shade * fs * 0.85, 1.0))

            geom:DefineVertex(v2)
            geom:DefineNormal(normal)
            geom:DefineColor(Color(shade * fs, shade * fs * 0.9, shade * fs * 0.85, 1.0))

            geom:DefineVertex(v3)
            geom:DefineNormal(normal)
            geom:DefineColor(Color(shade * fs, shade * fs * 0.9, shade * fs * 0.85, 1.0))
        end
        geom:Commit()
        geom:SetMaterial(decoAsteroidMat_)
        geom.castShadows = false

        table_insert(decoAsteroids_, {
            node = sNode,
            origScale = sNode.scale,
            scale = 1.0,
            rotSpeed = Vector3(
                (math_random() - 0.5) * 12,
                (math_random() - 0.5) * 12,
                (math_random() - 0.5) * 12
            ),
            driftSpeed = 0.8 + math_random() * 2.0,
        })
    end
end

-- 每帧更新：缓慢旋转 + 随速度向后漂移 + 循环回收
function UpdateDecoAsteroids(dt)
    local currentSpeed = speed_
    if gameState_ ~= STATE_PLAYING then
        local breath = (math_sin(time.elapsedTime * 0.4) + 1) * 0.5
        currentSpeed = 20 + breath * 40
    end

    -- 速度超过30km/s时渐变隐藏装饰陨石
    local fadeThreshold = 30.0
    local fadeRange = 15.0  -- 30~45之间渐变消失
    local targetScale = 1.0
    if gameState_ == STATE_PLAYING and speed_ > fadeThreshold then
        targetScale = math_max(0.0, 1.0 - (speed_ - fadeThreshold) / fadeRange)
    end

    local decos = decoAsteroids_
    local doRotate = (frameCount_ % 2 == 0)
    for i = 1, #decos do
        local deco = decos[i]
        local node = deco.node
        -- 渐变缩放
        local curScale = deco.scale or 1.0
        if curScale ~= targetScale then
            local fadeSpeed = 2.0 * dt
            if targetScale < curScale then
                curScale = math_max(targetScale, curScale - fadeSpeed)
            else
                curScale = math_min(targetScale, curScale + fadeSpeed)
            end
            deco.scale = curScale
            local orig = deco.origScale
            node.scale = Vector3(orig.x * curScale, orig.y * curScale, orig.z * curScale)
        end

        -- 完全消失时跳过位移计算
        if curScale < 0.01 then
            node:SetEnabled(false)
            goto continue_deco
        else
            node:SetEnabled(true)
        end

        local pos = node.position
        pos.z = pos.z - (currentSpeed * 0.6 + deco.driftSpeed) * dt

        -- 超出视野后循环到前方（保持轨道外）
        if pos.z < -20 then
            pos.z = 140 + math_random() * 40
            local side = (math_random() > 0.5) and 1 or -1
            pos.x = side * (moveRangeX_ + 5.0 + math_random() * 8.0)
            local ySide = (math_random() > 0.5) and 1 or -1
            pos.y = ySide * (moveRangeY_ + 2.5 + math_random() * 6.0)
        end

        node.position = pos
        -- 旋转（每2帧更新）
        if doRotate then
            local rs = deco.rotSpeed
            node:Rotate(Quaternion(rs.x * dt * 2, rs.y * dt * 2, rs.z * dt * 2))
        end

        ::continue_deco::
    end
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================

function CheckCollisions()
    local shipPos = Vector3(shipX_, shipY_, 0)
    local scoreMul = warpActive_ and 2 or 1

    -- 子弹 vs 小行星（早退：任一为空则跳过）
    local numBullets = #bullets_
    local numAsteroids = #asteroids_
    if numBullets > 0 and numAsteroids > 0 then
        for bi = numBullets, 1, -1 do
            local bullet = bullets_[bi]
            local bPos = bullet.node.position
            local bz = bPos.z
            local bx = bPos.x
            local by = bPos.y
            local hit = false

            for ai = numAsteroids, 1, -1 do
                local asteroid = asteroids_[ai]
                local aPos = asteroid.node.position
                -- Z 距离预筛（子弹碰撞半径最大 ~2.5，快速跳过）
                local dz = bz - aPos.z
                if dz > -3 and dz < 3 then
                    local dx = bx - aPos.x
                    local dy = by - aPos.y
                    local dist2 = dx * dx + dy * dy + dz * dz
                    local r = 0.5 + asteroid.radius

                    if dist2 < r * r then
                        score_ = score_ + 5 * scoreMul
                        local explPos = asteroid.node.position
                        local explSize = asteroid.radius * 1.2
                        SpawnExplosion(explPos, explSize, { 0.9, 0.4, 0.1 })

                        asteroid.node:Remove()
                        table_remove(asteroids_, ai)
                        numAsteroids = numAsteroids - 1
                        hit = true
                        break
                    end
                end
            end

            if hit then
                bullet.node:Remove()
                table_remove(bullets_, bi)
            end
        end
    end

    if invincibleTimer_ > 0 or warpActive_ or rollActive_ then return end

    -- 小行星 vs 飞船
    for i = #asteroids_, 1, -1 do
        local asteroid = asteroids_[i]
        local astPos = asteroid.node.position
        local dx = shipPos.x - astPos.x
        local dy = shipPos.y - astPos.y
        local dz = shipPos.z - astPos.z
        local dist2 = dx * dx + dy * dy + dz * dz

        local collideRadius = shipRadius_ + asteroid.radius
        -- 护盾扩大碰撞范围
        if shieldActive_ then collideRadius = 1.5 + asteroid.radius end

        if dist2 < collideRadius * collideRadius then
            if shieldActive_ then
                -- 护盾挡住，蓝色电弧爆炸
                score_ = score_ + 5 * scoreMul
                SpawnExplosion(asteroid.node.position, asteroid.radius * 0.8, { 0.2, 0.6, 1.0 })
                asteroid.node:Remove()
                table_remove(asteroids_, i)
            else
                -- 受伤，红色爆炸
                lives_ = lives_ - 1
                invincibleTimer_ = invincibleDuration_

                SpawnExplosion(asteroid.node.position, asteroid.radius * 1.0, { 1.0, 0.2, 0.1 })
                asteroid.node:Remove()
                table_remove(asteroids_, i)

                if lives_ <= 0 then
                    GameOver()
                    return
                end
                break
            end
        end
    end

    -- 水晶碰撞
    for i = #crystals_, 1, -1 do
        local crystal = crystals_[i]
        local crPos = crystal.node.position
        local dx = shipPos.x - crPos.x
        local dy = shipPos.y - crPos.y
        local dz = shipPos.z - crPos.z
        local dist2 = dx * dx + dy * dy + dz * dz
        local r = shipRadius_ + crystal.radius

        if dist2 < r * r then
            score_ = score_ + 10 * scoreMul
            -- 积累折跃能量
            if warpEnergy_ < warpMaxEnergy_ then
                warpEnergy_ = warpEnergy_ + 1
            end

            crystal.node:Remove()
            table_remove(crystals_, i)
        end
    end
end

-- ============================================================================
-- 难度递增
-- ============================================================================

function UpdateDifficulty(dt)
    speed_ = math_min(speed_ + speedIncrement_ * dt, maxSpeed_)

    local progress = (speed_ - 20) / (maxSpeed_ - 20)
    asteroidSpawnInterval_ = 0.4 - progress * (0.4 - asteroidMinInterval_)

    -- 存活加分（每秒约 1 分，warp时双倍）
    score_ = score_ + (warpActive_ and 2 or 1)

    -- 剧情触发检测：逐级检查是否达到下一个阈值
    local nextIdx = storyTriggeredIndex_ + 1
    if nextIdx <= #storyThresholds_ and score_ >= storyThresholds_[nextIdx] then
        storyTriggeredIndex_ = nextIdx
        ShowStoryChoiceUI(nextIdx)
    end
end

-- ============================================================================
-- HUD 更新
-- ============================================================================

function UpdateHUD()
    -- 得分
    if scoreLabel_ then
        scoreLabel_:SetText(string.format("得分: %d", score_))
    end
    -- 生命
    if livesLabel_ then
        local icons = ""
        for i = 1, lives_ do icons = icons .. "✈" end
        for i = lives_ + 1, 5 do icons = icons .. "✧" end
        livesLabel_:SetText(icons)
    end

    -- === 速度仪表 ===
    if speedLabel_ then
        speedLabel_:SetText(string.format("%.0f", speed_))
        local sMode = warpActive_ and "warp" or "normal"
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
        speedBar_:SetValue(speed_ / warpSpeed_)
        local sbMode = warpActive_ and "warp" or (speed_ > maxSpeed_ * 0.8 and "high" or "normal")
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
        local sm = shieldActive_ and "active" or (shieldCoolTimer_ > 0 and "cooldown" or "ready")
        if shieldActive_ then
            shieldLabel_:SetText(string.format("%.1fs", shieldTimer_))
        elseif shieldCoolTimer_ > 0 then
            shieldLabel_:SetText(string.format("%.0fs", shieldCoolTimer_))
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
        local wm = warpActive_ and "warping" or (warpCharging_ and "charging" or (warpEnergy_ >= warpMaxEnergy_ and "ready" or "idle"))
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
    -- 屏幕中央蓄能倒计时
    -- 屏幕中央蓄能倒计时（仅秒数变化时更新，每秒最多1次 SetText）
    if warpCountLabel_ then
        if warpCharging_ then
            local sec = math_ceil(warpChargeTimer_)
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
        if hudState_.lastWarpEnergy ~= warpEnergy_ then
            hudState_.lastWarpEnergy = warpEnergy_
            local filled = string.rep("◆", warpEnergy_)
            local empty = string.rep("◇", warpMaxEnergy_ - warpEnergy_)
            warpStatus_:SetText(filled .. empty)
        end
    end
    if warpBar_ then
        local wbMode = warpActive_ and "warp" or (warpCharging_ and "charge" or "normal")
        -- 充能时完全跳过进度条更新（由 NanoVG 圆环代替显示进度）
        if warpActive_ then
            local val = math_floor(warpTimer_ / warpDuration_ * 50) / 50
            if hudState_.lastWarpBarVal ~= val then
                hudState_.lastWarpBarVal = val
                warpBar_:SetValue(val)
            end
        elseif warpCharging_ then
            -- 充能期间不更新进度条，避免 UI 内部重绘开销
            -- 进度由 NanoVG 圆环展示
        else
            local val = math_floor(warpEnergy_ / warpMaxEnergy_ * 50) / 50
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
        if rollCdLeftTimer_ > 0 then
            rollLeftLabel_:SetText(string.format("%.1f", rollCdLeftTimer_))
            rollLeftLabel_:SetFontColor({ 120, 120, 140, 180 })
            -- 冷却中：红色边框
            if rollLeftPanel_ then rollLeftPanel_:SetBorderColor({ 220, 60, 60, 200 }) end
            if rollLeftIcon_ then rollLeftIcon_:SetFontColor({ 220, 60, 60, 200 }) end
        else
            rollLeftLabel_:SetText("Q")
            rollLeftLabel_:SetFontColor({ 200, 200, 200, 255 })
            -- 可用：蓝色边框
            if rollLeftPanel_ then rollLeftPanel_:SetBorderColor({ 60, 140, 255, 200 }) end
            if rollLeftIcon_ then rollLeftIcon_:SetFontColor({ 60, 140, 255, 200 }) end
        end
    end
    if rollRightLabel_ then
        if rollCdRightTimer_ > 0 then
            rollRightLabel_:SetText(string.format("%.1f", rollCdRightTimer_))
            rollRightLabel_:SetFontColor({ 120, 120, 140, 180 })
            -- 冷却中：红色边框
            if rollRightPanel_ then rollRightPanel_:SetBorderColor({ 220, 60, 60, 200 }) end
            if rollRightIcon_ then rollRightIcon_:SetFontColor({ 220, 60, 60, 200 }) end
        else
            rollRightLabel_:SetText("E")
            rollRightLabel_:SetFontColor({ 200, 200, 200, 255 })
            -- 可用：蓝色边框
            if rollRightPanel_ then rollRightPanel_:SetBorderColor({ 60, 140, 255, 200 }) end
            if rollRightIcon_ then rollRightIcon_:SetFontColor({ 60, 140, 255, 200 }) end
        end
    end
end

-- ============================================================================
-- NanoVG 渲染：充能圆环
-- ============================================================================
function HandleNanoVGRender(eventType, eventData)
    if not vg_ then return end
    if not warpCharging_ then return end

    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    nvgBeginFrame(vg_, w, h, 1.0)

    -- 圆环参数（与倒计时文字位置对齐：top 38% + height 120/2 = 60 逻辑像素）
    local cx = w * 0.5
    local cy = h * 0.38 + 60 * dpr
    local radius = 52 * dpr
    local lineWidth = 5 * dpr

    -- 充能进度（0→1）
    local progress = 1.0 - (warpChargeTimer_ / warpChargeTime_)
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

    -- 前景进度弧（白色，顺时针填充）
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
