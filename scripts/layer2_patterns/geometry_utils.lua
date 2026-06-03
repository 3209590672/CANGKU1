--[[
Layer 2 - 可复用模式：CustomGeometry 通用建模工具
职责：提供三角面片、法线计算、多边形辅助等通用几何操作
零游戏依赖，可跨项目复用
--]]

local GeomUtils = {}

--- 计算三角面法线
---@param p1 Vector3
---@param p2 Vector3
---@param p3 Vector3
---@return Vector3
function GeomUtils.faceNormal(p1, p2, p3)
    local e1 = p2 - p1
    local e2 = p3 - p1
    return e1:CrossProduct(e2):Normalized()
end

--- 添加三角面片（带法线和默认UV）
---@param geom CustomGeometry
---@param p1 Vector3
---@param p2 Vector3
---@param p3 Vector3
---@param normal Vector3
function GeomUtils.addTri(geom, p1, p2, p3, normal)
    geom:DefineVertex(p1); geom:DefineNormal(normal); geom:DefineTexCoord(Vector2(0, 0))
    geom:DefineVertex(p2); geom:DefineNormal(normal); geom:DefineTexCoord(Vector2(1, 0))
    geom:DefineVertex(p3); geom:DefineNormal(normal); geom:DefineTexCoord(Vector2(0, 1))
end

--- 添加四边形（两个三角面，自动计算法线）
---@param geom CustomGeometry
---@param p1 Vector3
---@param p2 Vector3
---@param p3 Vector3
---@param p4 Vector3
function GeomUtils.addQuad(geom, p1, p2, p3, p4)
    local n = GeomUtils.faceNormal(p1, p2, p3)
    GeomUtils.addTri(geom, p1, p2, p3, n)
    GeomUtils.addTri(geom, p1, p3, p4, n)
end

--- 生成八边形截面环
---@param cx number 圆心X
---@param cy number 圆心Y
---@param cz number 圆心Z
---@param radius number 水平半径
---@param radiusY number|nil 垂直半径（默认=radius）
---@param zOff number|nil Z偏移
---@return table Vector3数组
function GeomUtils.makeOctRing(cx, cy, cz, radius, radiusY, zOff)
    local pts = {}
    radiusY = radiusY or radius
    zOff = zOff or 0
    for i = 0, 7 do
        local a = (i / 8) * math.pi * 2
        local px = cx + math.cos(a) * radius
        local py = cy + math.sin(a) * radiusY
        pts[i + 1] = Vector3(px, py, cz + zOff)
    end
    return pts
end

--- 连接两个截面环形成管状表面
---@param geom CustomGeometry
---@param ring1 table 前截面点数组
---@param ring2 table 后截面点数组
function GeomUtils.connectRings(geom, ring1, ring2)
    local n = #ring1
    for i = 1, n do
        local i2 = (i % n) + 1
        GeomUtils.addQuad(geom, ring1[i], ring2[i], ring2[i2], ring1[i2])
    end
end

--- 封闭截面（扇形三角化，朝向指定法线方向）
---@param geom CustomGeometry
---@param pts table 截面点数组
---@param center Vector3 扇形中心点
---@param outward boolean true=外法线（前端面），false=内法线（后端面）
function GeomUtils.capRing(geom, pts, center, outward)
    local n = #pts
    for i = 1, n do
        local i2 = (i % n) + 1
        if outward then
            local norm = GeomUtils.faceNormal(center, pts[i], pts[i2])
            GeomUtils.addTri(geom, center, pts[i], pts[i2], norm)
        else
            local norm = GeomUtils.faceNormal(center, pts[i2], pts[i])
            GeomUtils.addTri(geom, center, pts[i2], pts[i], norm)
        end
    end
end

--- 创建六边形贴面灯（通用装饰组件）
---@param parent Node 父节点
---@param name string 子节点名称
---@param pos Vector3 位置
---@param normal Vector3 法线方向
---@param radius number 半径
---@param mat Material 材质
---@return Node
function GeomUtils.createHexLight(parent, name, pos, normal, radius, mat)
    local node = parent:CreateChild(name)
    node.position = pos
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local up = (math.abs(normal.y) < 0.99) and Vector3.UP or Vector3.RIGHT
    local tangent = normal:CrossProduct(up):Normalized()
    local bitangent = tangent:CrossProduct(normal):Normalized()

    local hexPts = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        local dx = math.cos(angle) * radius
        local dy = math.sin(angle) * radius
        hexPts[i + 1] = tangent * dx + bitangent * dy
    end

    -- 正面
    local center = Vector3(0, 0, 0)
    for i = 1, 6 do
        local i2 = (i % 6) + 1
        GeomUtils.addTri(geom, center, hexPts[i], hexPts[i2], normal)
    end

    -- 背面
    local backOff = normal * (-0.002)
    local backN = normal * (-1)
    for i = 1, 6 do
        local i2 = (i % 6) + 1
        GeomUtils.addTri(geom, backOff, hexPts[i2] + backOff, hexPts[i] + backOff, backN)
    end

    geom:Commit()
    geom:SetMaterial(mat)
    geom.castShadows = false
    return node
end

return GeomUtils
