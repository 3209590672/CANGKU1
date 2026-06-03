-- ============================================================================
-- scene_setup.lua — 场景创建（灯光、相机、星云、Zone雾效）
-- ============================================================================
local M = {}

--- 创建主场景，返回 { scene, cameraNode, zone }
---@param deps { cache: ResourceCache }
---@return { scene: Scene, cameraNode: Node, zone: Zone }
function M.createScene(deps)
    local cache = deps.cache

    local scene = Scene()
    scene:CreateComponent("Octree")

    -- 夜晚光照
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/DarkNight.xml")
    local lightGroup = scene:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    local zone = lightGroup:GetComponent("Zone", true)
    zone.fogStart = 80
    zone.fogEnd = 400
    zone.fogColor = Color(0.02, 0.015, 0.05, 1.0)
    zone.ambientColor = Color(0.35, 0.35, 0.55)

    -- 星云背景（大面片，陨石飞来方向）
    local nebulaNode = scene:CreateChild("Nebula")
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
    local cameraNode = scene:CreateChild("Camera")
    cameraNode.position = Vector3(0, 0.2, -4.5)
    local camera = cameraNode:CreateComponent("Camera")
    camera.nearClip = 0.1
    camera.farClip = 600.0
    camera.fov = 70.0
    -- 音频监听器
    cameraNode:CreateComponent("SoundListener")
    audio.listener = cameraNode:GetComponent("SoundListener")

    -- 左上角光照效果（模拟恒星光源）
    local ulLightNode = cameraNode:CreateChild("UpperLeftGlow")
    ulLightNode.position = Vector3(-3.5, 2.5, 8.0)
    local ulLight = ulLightNode:CreateComponent("Light")
    ulLight.lightType = LIGHT_POINT
    ulLight.color = Color(1.0, 0.9, 0.7)
    ulLight.brightness = 3.5
    ulLight.range = 18.0
    ulLight.specularIntensity = 0.6

    -- 主聚光灯（从相机方向照亮飞船和前方物体）
    local glowNode = cameraNode:CreateChild("CenterSpot")
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
    local backLightNode = scene:CreateChild("BackLight")
    backLightNode.position = Vector3(0, 3, 60)
    backLightNode.rotation = Quaternion(175, Vector3.RIGHT)
    local backLight = backLightNode:CreateComponent("Light")
    backLight.lightType = LIGHT_DIRECTIONAL
    backLight.color = Color(1.0, 0.6, 0.25)
    backLight.brightness = 1.2
    backLight.specularIntensity = 0.8

    -- 顶部冷蓝补光（增加层次感）
    local topLightNode = scene:CreateChild("TopFill")
    topLightNode.rotation = Quaternion(60, Vector3.RIGHT)
    local topLight = topLightNode:CreateComponent("Light")
    topLight.lightType = LIGHT_DIRECTIONAL
    topLight.color = Color(0.4, 0.5, 0.9)
    topLight.brightness = 0.6
    topLight.specularIntensity = 0.1

    -- 边缘高光（左后方 rim light）
    local rimLeftNode = scene:CreateChild("RimLeft")
    rimLeftNode.rotation = Quaternion(160, Vector3.UP) * Quaternion(10, Vector3.RIGHT)
    local rimLeft = rimLeftNode:CreateComponent("Light")
    rimLeft.lightType = LIGHT_DIRECTIONAL
    rimLeft.color = Color(0.6, 0.75, 1.0)
    rimLeft.brightness = 1.8
    rimLeft.specularIntensity = 2.5

    -- 边缘高光（右后方 rim light）
    local rimRightNode = scene:CreateChild("RimRight")
    rimRightNode.rotation = Quaternion(-160, Vector3.UP) * Quaternion(10, Vector3.RIGHT)
    local rimRight = rimRightNode:CreateComponent("Light")
    rimRight.lightType = LIGHT_DIRECTIONAL
    rimRight.color = Color(0.6, 0.75, 1.0)
    rimRight.brightness = 1.8
    rimRight.specularIntensity = 2.5

    -- 平滑环境补光（正前方偏下，柔和照亮所有陨石表面）
    local frontFillNode = scene:CreateChild("FrontFill")
    frontFillNode.rotation = Quaternion(-15, Vector3.RIGHT)
    local frontFill = frontFillNode:CreateComponent("Light")
    frontFill.lightType = LIGHT_DIRECTIONAL
    frontFill.color = Color(0.5, 0.55, 0.7)
    frontFill.brightness = 0.8
    frontFill.specularIntensity = 0.05

    -- 底部暖色反弹光（模拟星云反射的漫射光）
    local bottomBounceNode = scene:CreateChild("BottomBounce")
    bottomBounceNode.rotation = Quaternion(-130, Vector3.RIGHT)
    local bottomBounce = bottomBounceNode:CreateComponent("Light")
    bottomBounce.lightType = LIGHT_DIRECTIONAL
    bottomBounce.color = Color(0.4, 0.3, 0.5)
    bottomBounce.brightness = 0.5
    bottomBounce.specularIntensity = 0.0

    -- 侧面柔光（从左侧45°照入，增加立体感过渡）
    local sideFillNode = scene:CreateChild("SideFill")
    sideFillNode.rotation = Quaternion(45, Vector3.UP) * Quaternion(20, Vector3.RIGHT)
    local sideFill = sideFillNode:CreateComponent("Light")
    sideFill.lightType = LIGHT_DIRECTIONAL
    sideFill.color = Color(0.45, 0.5, 0.65)
    sideFill.brightness = 0.6
    sideFill.specularIntensity = 0.1

    local viewport = Viewport:new(scene, camera)
    renderer:SetViewport(0, viewport)
    renderer.hdrRendering = true

    return {
        scene = scene,
        cameraNode = cameraNode,
        zone = zone,
    }
end

return M
