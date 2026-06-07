-- ============================================================================
-- 宇宙航行 (Space Voyager)
-- 玩法：驾驶飞船在宇宙中穿梭，闪避小行星，收集能量水晶
-- 操作：WASD/方向键移动飞船，Shift减速，收集5水晶长按空格折跃，左键射击，右键护盾
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- 模块化架构引入（四层分层，详见 docs/编程准则.md）
-- ============================================================================
-- Layer 4: 数据/配置（零逻辑，纯数据）
local Config = require("layer4_content/config")
local StoryData = require("layer4_content/story_data")
local MatDefs = require("layer4_content/material_defs")
-- Layer 1: 基础框架（零游戏依赖，可跨项目）
local FSM = require("layer1_framework/state_machine")
local EventBus = require("layer1_framework/event_bus")
-- Layer 2: 可复用模式（设计模式复用）
local InputManager = require("layer2_patterns/input_manager")
local TouchControls = require("layer2_patterns/touch_controls")
local GeomUtils = require("layer2_patterns/geometry_utils")
local MatFactory = require("layer2_patterns/material_factory")
-- Layer 3: 游戏逻辑（特定于本项目）
local GameState = require("layer3_gameplay/game_state")
local Story = require("layer3_gameplay/story")
local ShipBuilder = require("layer3_gameplay/ship_builder")
local AsteroidBuilder = require("layer3_gameplay/asteroid_builder")
local GameUI = require("layer3_gameplay/game_ui")
local GameAudio = require("layer3_gameplay/game_audio")
local Background = require("layer3_gameplay/background")
local Weapons = require("layer3_gameplay/weapons")
local Effects = require("layer3_gameplay/effects")
local Crystals = require("layer3_gameplay/crystals")
local Asteroids = require("layer3_gameplay/asteroids")
local Collisions = require("layer3_gameplay/collisions")
local Shield = require("layer3_gameplay/shield")
local EngineTrails = require("layer3_gameplay/engine_trails")
local WarpVisuals = require("layer3_gameplay/warp_visuals")
local HUD = require("layer3_gameplay/hud")
local ShipController = require("layer3_gameplay/ship_controller")
local GameFlow = require("layer3_gameplay/game_flow")

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

-- 游戏状态常量
local STATE_MENU = 1
local STATE_PLAYING = 2
local STATE_GAMEOVER = 3
local STATE_STORY_CHOICE = 4   -- 剧情选项弹窗（暂停游戏）
local STATE_STORY_ENDING = 5   -- 结局剧情展示

-- GameState 纯数据容器（统一管理运行时数据）
local gs = GameState.new()

-- frameCount 保留局部变量（高频访问，避免 table 查找开销）
local frameCount_ = 0

-- Zone引用（用于雾动画）
local zone_ = nil

-- ============================================================================
-- 剧情系统（委托给 Layer 3 Story 模块）
-- ============================================================================
local story_ = Story.new()  -- 模块化剧情管理

-- ============================================================================
-- 模块实例（Layer 1/2）
-- ============================================================================
local inputMgr_ = InputManager.new()
local eventBus_ = EventBus.new()
local gameFSM_ = FSM.new({ "menu", "playing", "gameover", "story_choice", "story_ending" }, "menu")

-- FSM 状态名 → gs.phase 整数映射（FSM 为唯一写入口，gs.phase 保持读兼容）
local STATE_NAME_TO_PHASE = {
    menu = 1,
    playing = 2,
    gameover = 3,
    story_choice = 4,
    story_ending = 5,
}
gameFSM_:on("transition", function(from, to)
    gs.phase = STATE_NAME_TO_PHASE[to] or 1
end)

-- 菜单按钮动画引用
local menuStartLabel_ = nil
local menuStartBtn_ = nil

-- BGM 相关（状态由 GameAudio 模块管理）
local menuMusicBtn_ = nil
local endingMusicBtn_ = nil

-- ============================================================================
-- 预缓存材质（性能优化：避免每帧/每次生成时创建 Material）
-- ============================================================================
-- 护盾脉冲材质（复用单实例，只更新 shader 参数）
local shieldPulseMat_ = nil

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
local starDustMat_ = nil
local meteorMat_ = nil
local decoAsteroidMat_ = nil

-- 预缓存模型引用（避免每帧/每次生成时重复查找）
local mdlBox_ = nil
local mdlSphere_ = nil
local mdlCylinder_ = nil

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

    -- 初始化触摸控制（手机端自动显示虚拟摇杆和按钮）
    TouchControls.init()

    InitCachedMaterials()

    CreateScene()

    Background.init({
        scene = scene_,
        cache = cache,
        starDustMat = starDustMat_,
        meteorMat = meteorMat_,
        decoAsteroidMat = decoAsteroidMat_,
        asteroidMeshPool = asteroidMeshPool_,
        asteroidMeshPoolSize = asteroidMeshPoolSize_,
        moveRangeX = gs.moveRangeX,
        moveRangeY = gs.moveRangeY,
        mdlSphere = mdlSphere_,
    })

    CreateShip()

    Weapons.init({
        scene = scene_,
        inputMgr = inputMgr_,
        mdlBox = mdlBox_,
        mdlSphere = mdlSphere_,
        bulletCoreMat = bulletCoreMat_,
        bulletGlowMat = bulletGlowMat_,
        bulletTrailMats = bulletTrailMats_,
        bulletTipMat = bulletTipMat_,
        getShipPos = function() return gs.shipX, gs.shipY end,
        eventBus = eventBus_,
    })

    Effects.init({
        scene = scene_,
        mdlCylinder = mdlCylinder_,
        mdlSphere = mdlSphere_,
        mdlBox = mdlBox_,
        explosionRayMat = explosionRayMat_,
        explosionDebrisMat = explosionDebrisMat_,
        explosionGlowBaseMat = explosionGlowBaseMat_,
        getFrameCount = function() return frameCount_ end,
    })

    Crystals.init({
        scene = scene_,
        crystalMats = crystalMats_,
        getSpeed = function() return gs.speed end,
        getMoveRange = function() return gs.moveRangeX, gs.moveRangeY end,
        getFrameCount = function() return frameCount_ end,
        getElapsedTime = function() return time.elapsedTime end,
    })

    Asteroids.init({
        state = gs,
        scene = scene_,
        AsteroidBuilder = AsteroidBuilder,
        meshPool = asteroidMeshPool_,
        meshPoolSize = asteroidMeshPoolSize_,
        rockMats = asteroidRockMats_,
        debrisMats = asteroidDebrisMats_,
        crackMat = asteroidCrackMat_,
        oreMat = asteroidOreMat_,
        mdlSphere = mdlSphere_,
        mdlBox = mdlBox_,
    })

    Collisions.init({
        state = gs,
        Weapons = Weapons,
        Asteroids = Asteroids,
        Crystals = Crystals,
        Effects = Effects,
        eventBus = eventBus_,
    })

    -- EventBus 订阅：碰撞模块发出的跨模块事件
    eventBus_:on("game_over", function(_score)
        GameOver()
    end)

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
    local vg = nvgCreate(1)
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    HUD.setNanoVG(vg)

    -- 初始化飞船控制器
    ShipController.init({
        gs = gs,
        inputMgr = inputMgr_,
        shipNode = shipNode_,
        EngineTrails = EngineTrails,
        eventBus = eventBus_,
    })

    -- 初始化游戏流程模块（收窄 ctx：ISP 最小依赖集）
    GameFlow.init({
        gs = gs,
        fsm = gameFSM_,
        eventBus = eventBus_,
        shipNode = shipNode_,
        GameState = GameState,
        Crystals = Crystals,
        Weapons = Weapons,
        Asteroids = Asteroids,
        Effects = Effects,
        Shield = Shield,
        EngineTrails = EngineTrails,
        story = story_,
        showMenuUI = ShowMenuUI,
        showPlayingUI = ShowPlayingUI,
        showGameOverUI = ShowGameOverUI,
    })

    -- EventBus 订阅：game_start 时重置翼尖拖尾（原 GameFlow 直调 WarpVisuals）
    eventBus_:on("game_start", function()
        WarpVisuals.resetWingTrail(EngineTrails.getWarpWingTrail())
    end)

    -- EventBus 订阅：game_return_menu 时重建背景装饰（原 GameFlow 直调 Background）
    eventBus_:on("game_return_menu", function()
        Background.createStarDusts()
        Background.createDecoAsteroids()
        Background.createMeteors()
    end)

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")
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
    gs.moveRangeX = halfWidth - 1.0
    gs.moveRangeY = halfHeight - 0.8
    print(string.format("=== Visible range: X=%.1f Y=%.1f (aspect=%.2f) ===", gs.moveRangeX, gs.moveRangeY, aspect))
end

-- ============================================================================
-- BGM：委托给 GameAudio 模块
-- ============================================================================

function InitBGM()
    GameAudio.init(scene_, cache, eventBus_)
    GameAudio.setMenuChecker(function() return gs.phase == STATE_MENU end)
end

function ToggleBGM()
    local enabled = GameAudio.toggleBGM()
    if menuMusicBtn_ then
        menuMusicBtn_:SetText(enabled and "🔊" or "🔇")
        menuMusicBtn_:SetFontColor(enabled and { 120, 220, 255, 220 } or { 120, 120, 140, 150 })
    end
end

function PlayEndingBGM(endingKey)
    GameAudio.playEnding(endingKey)
end

function StopEndingBGM()
    GameAudio.stopEnding()
end

function ToggleEndingBGM()
    local enabled = GameAudio.toggleEndingBGM()
    if endingMusicBtn_ then
        endingMusicBtn_:SetText(enabled and "🔊" or "🔇")
        endingMusicBtn_:SetFontColor(enabled and { 120, 220, 255, 220 } or { 120, 120, 140, 150 })
    end
end


-- ============================================================================
-- UI：委托给 GameUI 模块
-- ============================================================================

function ShowMenuUI()
    TouchControls.setVisible(false)
    local refs = GameUI.showMenu({
        bgmEnabled = GameAudio.isBgmEnabled(),
        onStart = function() StartGame() end,
        onToggleBGM = function() ToggleBGM() end,
    })
    menuStartLabel_ = refs.menuStartLabel
    menuStartBtn_ = refs.menuStartBtn
    menuMusicBtn_ = refs.menuMusicBtn
end

function ShowPlayingUI()
    TouchControls.setVisible(true)
    local refs = GameUI.showPlaying({ warpSpeed = gs.warpSpeed })
    -- 注入 HUD 模块控件引用
    HUD.setWidgets(refs)
    HUD.resetCache()
end

function ShowGameOverUI()
    TouchControls.setVisible(false)
    PlayEndingBGM("永恒漂泊")
    local refs = GameUI.showGameOver({
        score = gs.score,
        gameTime = gs.gameTime,
        speed = gs.speed,
        endingBgmEnabled = GameAudio.isEndingBgmEnabled(),
        onReturnMenu = function() ReturnToMenu() end,
        onToggleEndingBGM = function() ToggleEndingBGM() end,
    })
    endingMusicBtn_ = refs.endingMusicBtn
end



function OnStoryChoiceMade(isEnding)
    if isEnding then
        ShowStoryEndingUI()
    else
        gameFSM_:go("playing")
        ShowPlayingUI()
    end
end

function ShowStoryEndingUI(ending)
    TouchControls.setVisible(false)
    gameFSM_:go("story_ending")
    ending = ending or story_:getEnding()
    PlayEndingBGM(ending.key)
    local refs = GameUI.showStoryEnding({
        ending = ending,
        score = gs.score,
        story = story_,
        endingBgmEnabled = GameAudio.isEndingBgmEnabled(),
        onReturnMenu = function() ReturnToMenu() end,
        onToggleEndingBGM = function() ToggleEndingBGM() end,
    })
    endingMusicBtn_ = refs.endingMusicBtn
end

-- ============================================================================
-- 预缓存材质初始化
-- ============================================================================

function InitCachedMaterials()
    -- 预缓存常用模型引用
    mdlBox_ = cache:GetResource("Model", "Models/Box.mdl")
    mdlSphere_ = cache:GetResource("Model", "Models/Sphere.mdl")
    mdlCylinder_ = cache:GetResource("Model", "Models/Cylinder.mdl")

    -- 初始化材质工厂
    MatFactory.init(cache)

    -- 单材质创建
    shieldPulseMat_     = MatFactory.create(MatDefs.shieldPulse)
    bulletCoreMat_      = MatFactory.create(MatDefs.bulletCore)
    bulletGlowMat_      = MatFactory.create(MatDefs.bulletGlow)
    bulletTipMat_       = MatFactory.create(MatDefs.bulletTip)
    explosionRayMat_    = MatFactory.create(MatDefs.explosionRay)
    explosionDebrisMat_ = MatFactory.create(MatDefs.explosionDebris)
    explosionGlowBaseMat_ = MatFactory.create(MatDefs.explosionGlowBase)
    asteroidCrackMat_   = MatFactory.create(MatDefs.asteroidCrack)
    asteroidOreMat_     = MatFactory.create(MatDefs.asteroidOre)
    starDustMat_        = MatFactory.create(MatDefs.starDust)
    decoAsteroidMat_    = MatFactory.create(MatDefs.decoAsteroid)
    meteorMat_          = MatFactory.create(MatDefs.meteor)

    -- 批量材质创建
    bulletTrailMats_ = MatFactory.createTrailArray(MatDefs.bulletTrail)
    crystalMats_ = MatFactory.createColorArray(MatDefs.crystal)
    asteroidRockMats_, asteroidDebrisMats_ = MatFactory.createRockPairs(MatDefs.asteroidRock)
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
    zone_ = zone
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

    -- 摄像机（后上方俯视，向下看10度）
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 3.5, -5.5)
    cameraNode_.rotation = Quaternion(10.0, Vector3.RIGHT)  -- 俯视10度
    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 600.0
    camera.fov = 70.0
    cameraNode_:CreateComponent("SoundListener")
    audio.listener = cameraNode_:GetComponent("SoundListener")

    -- 左上角光照效果（模拟恒星光源）
    local ulLightNode = cameraNode_:CreateChild("UpperLeftGlow")
    ulLightNode.position = Vector3(-3.5, 2.5, 8.0)
    local ulLight = ulLightNode:CreateComponent("Light")
    ulLight.lightType = LIGHT_POINT
    ulLight.perVertex = true
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

    -- 暖色背光
    local backLightNode = scene_:CreateChild("BackLight")
    backLightNode.position = Vector3(0, 3, 60)
    backLightNode.rotation = Quaternion(175, Vector3.RIGHT)
    local backLight = backLightNode:CreateComponent("Light")
    backLight.lightType = LIGHT_DIRECTIONAL
    backLight.color = Color(1.0, 0.6, 0.25)
    backLight.brightness = 1.2
    backLight.specularIntensity = 0.8

    -- 顶部冷蓝补光
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

    -- 平滑环境补光
    local frontFillNode = scene_:CreateChild("FrontFill")
    frontFillNode.rotation = Quaternion(-15, Vector3.RIGHT)
    local frontFill = frontFillNode:CreateComponent("Light")
    frontFill.lightType = LIGHT_DIRECTIONAL
    frontFill.color = Color(0.5, 0.55, 0.7)
    frontFill.brightness = 0.8
    frontFill.specularIntensity = 0.05

    -- 底部暖色反弹光
    local bottomBounceNode = scene_:CreateChild("BottomBounce")
    bottomBounceNode.rotation = Quaternion(-130, Vector3.RIGHT)
    local bottomBounce = bottomBounceNode:CreateComponent("Light")
    bottomBounce.lightType = LIGHT_DIRECTIONAL
    bottomBounce.color = Color(0.4, 0.3, 0.5)
    bottomBounce.brightness = 0.5
    bottomBounce.specularIntensity = 0.0

    -- 侧面柔光
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
end

-- ============================================================================
-- 飞船创建
-- ============================================================================

function CreateShip()
    -- 委托 ShipBuilder 构建飞船实体造型（机身、座舱、机翼、尾翼、引擎、装饰）
    local buildResult = ShipBuilder.build(scene_, cache)
    shipNode_ = buildResult.shipNode

    -- 护盾（委托 Shield 模块创建蜂巢几何体）
    Shield.createGeometry({ shipNode = shipNode_, cache = cache, pulseMat = shieldPulseMat_ })
    Shield.setEventBus(eventBus_)

    -- 程序化生成16x16柔边圆形纹理（共用于翼尖拖尾+火花粒子）
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

    -- 引擎拖尾（光带段 + 微粒 + 翼尖拖尾 + 火花粒子）
    EngineTrails.create({ scene = scene_, shipNode = shipNode_, cache = cache, circleTex = circleTex })
end

-- ============================================================================
-- 背景星尘
-- ============================================================================

function CreateStarDusts()
    Background.createStarDusts()
end

-- ============================================================================
-- 折跃穿越视觉效果
-- ============================================================================

function CreateWarpStreaks()
    WarpVisuals.createStreaks({ scene = scene_, shipNode = shipNode_, cache = cache })
end

-- ============================================================================
-- 游戏状态管理（委托 GameFlow 模块）
-- ============================================================================

function ReturnToMenu()
    GameFlow.returnToMenu()
end

function StartGame()
    GameFlow.startGame()
end

function GameOver()
    GameFlow.gameOver()
end

function ClearObjects()
    GameFlow.clearObjects()
end

-- ============================================================================
-- 更新循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    frameCount_ = frameCount_ + 1
    gs.frameCount = frameCount_

    -- 雾景深循环动画（隔帧更新）
    if zone_ and frameCount_ % 2 == 0 then
        local t
        if gs.phase == STATE_PLAYING or gs.phase == STATE_GAMEOVER then
            t = (math_sin(gs.gameTime * 0.349 - math_pi * 0.5) + 1.0) * 0.5
        else
            t = (math_sin(time.elapsedTime * 0.1745 - math_pi * 0.5) + 1.0) * 0.5 * 0.5
        end
        local r = 0.02 + t * 0.0925
        local g = 0.015 + t * 0.075
        local b = 0.05 + t * 0.1375
        zone_.fogColor = Color(r, g, b, 1.0)
        zone_.fogStart = 80 - t * 30
        zone_.fogEnd = 400 - t * 90
    end

    if gs.phase == STATE_PLAYING then
        gs.gameTime = gs.gameTime + dt
        ShipController.updateMovement(dt, frameCount_)
        ShipController.updateWarp(dt)
        -- 更新引擎音效（根据加速状态）
        GameAudio.updateEngine(inputMgr_:isAccelerating())
        UpdateShooting(dt)
        Shield.update(dt, gs, inputMgr_)
        UpdateBullets(dt)
        UpdateAsteroids(dt)
        UpdateCrystals(dt)
        UpdateStarDusts(dt)
        UpdateExplosions(dt)
        WarpVisuals.update(dt, gs, shipNode_, Background, EngineTrails.getWarpWingTrail())
        CheckCollisions()
        UpdateDifficulty(dt)
        if frameCount_ % 3 == 0 then
            HUD.update(gs, Weapons)
        end

        -- 无敌闪烁
        if gs.invincibleTimer > 0 then
            gs.invincibleTimer = gs.invincibleTimer - dt
            local visible = math_floor(gs.invincibleTimer * 10) % 2 == 0
            shipNode_:SetEnabled(visible)
        else
            shipNode_:SetEnabled(true)
        end

    elseif gs.phase == STATE_MENU then
        UpdateStarDusts(dt)
        -- 菜单中飞船缓慢浮动
        if shipNode_ ~= nil then
            shipNode_.position = Vector3(
                math_sin(time.elapsedTime * 0.5) * 0.5,
                math_sin(time.elapsedTime * 0.8) * 0.3,
                0
            )
            shipNode_:SetEnabled(true)

            -- 菜单呼吸速度驱动尾焰长度（与星尘同步）
            local menuBreath = (math_sin(time.elapsedTime * 0.4) + 1) * 0.5
            local menuSpeed = 20 + menuBreath * 40

            -- 引擎拖尾菜单动画（委托模块）
            EngineTrails.updateMenu(dt, shipNode_, menuSpeed)
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
                endBtn:SetFontColor({ 120, 220, 255, alpha })
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
-- 飞船控制（委托 ShipController 模块）
-- ============================================================================

-- （折跃系统已移入 ShipController 模块）

-- ============================================================================
-- 射击系统
-- ============================================================================

function UpdateShooting(dt)
    Weapons.updateShooting(dt)
end

function FireBullet()
    Weapons.fireBullet()
end

function UpdateBullets(dt)
    Weapons.updateBullets(dt)
end

-- ============================================================================
-- 爆炸特效系统
-- ============================================================================

function SpawnExplosion(pos, size, color)
    Effects.spawnExplosion(pos, size, color)
end

function UpdateExplosions(dt)
    Effects.updateExplosions(dt)
end

-- ============================================================================
-- 小行星系统
-- ============================================================================

function UpdateAsteroids(dt)
    Asteroids.update(dt)
end

-- 预生成岩石网格数据池（启动时计算，委托 AsteroidBuilder）
asteroidMeshPool_ = AsteroidBuilder.initMeshPool(asteroidMeshPoolSize_)

function SpawnAsteroid()
    Asteroids.spawn()
end

-- ============================================================================
-- 能量水晶系统
-- ============================================================================

function UpdateCrystals(dt)
    Crystals.update(dt)
end

function SpawnCrystal()
    Crystals.spawn()
end

-- ============================================================================
-- 背景系统更新：委托给 Background 模块
-- ============================================================================

function UpdateStarDusts(dt)
    Background.updateStarDusts(dt, gs.speed, gs.phase == STATE_PLAYING, time.elapsedTime)
end

function CreateStarfield()
    Background.createStarfield()
end

function UpdateStarfieldBreath()
    Background.updateStarfieldBreath(time.elapsedTime)
end

function CreateMeteors()
    Background.createMeteors()
end

function UpdateMeteors(dt)
    Background.updateMeteors(dt, time.elapsedTime, frameCount_)
end

function CreateDecoAsteroids()
    Background.createDecoAsteroids()
end

function UpdateDecoAsteroids(dt)
    Background.updateDecoAsteroids(dt, gs.speed, gs.phase == STATE_PLAYING, time.elapsedTime, frameCount_)
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================

function CheckCollisions()
    Collisions.check()
end

-- ============================================================================
-- 难度递增
-- ============================================================================

function UpdateDifficulty(dt)
    gs.speed = math_min(gs.speed + gs.speedIncrement * dt, gs.maxSpeed)

    local progress = (gs.speed - 20) / (gs.maxSpeed - 20)
    gs.asteroidSpawnInterval = 0.4 - progress * (0.4 - gs.asteroidMinInterval)

    -- 存活加分（每秒约 1 分，warp时双倍）
    gs.score = gs.score + (gs.warpActive and 2 or 1)


end

-- ============================================================================
-- NanoVG 渲染：充能圆环（委托 HUD 模块）
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    HUD.renderChargeRing(gs)
end
