--[[
Layer 3 - 游戏逻辑层：剧情系统模块
职责：剧情触发判断、选择记录、结局计算
--]]

local StoryData = require("layer4_content/story_data")

local Story = {}
Story.__index = Story

--- 创建剧情系统
---@return table Story实例
function Story.new()
    local self = setmetatable({}, Story)
    self.repairCount = 0
    self.exploreCount = 0
    self.broadcastCount = 0
    self.triggeredIndex = 0     -- 已触发到第几个阈值
    return self
end

--- 检查是否应触发剧情选择（每帧调用）
---@param score number 当前分数
---@return number|nil 如果触发则返回阈值索引，否则nil
function Story:checkTrigger(score)
    local thresholds = StoryData.thresholds
    local nextIdx = self.triggeredIndex + 1
    if nextIdx > #thresholds then return nil end
    if score >= thresholds[nextIdx] then
        self.triggeredIndex = nextIdx
        return nextIdx
    end
    return nil
end

--- 执行选择（表驱动，新增 action 类型只需改 StoryData.choices 数据）
---@param action string "repair" | "explore" | "broadcast"
---@param thresholdIdx number 当前阈值索引
---@return boolean 是否触发结局（第5次选择后）
function Story:makeChoice(action, thresholdIdx)
    local key = action .. "Count"
    self[key] = (self[key] or 0) + 1
    return thresholdIdx >= 5
end

--- 获取最终结局（声明式数据匹配，按优先级遍历）
---@return table 结局数据 { key, title, text, color, image }
function Story:getEnding()
    local counts = {
        repair = self.repairCount,
        explore = self.exploreCount,
        broadcast = self.broadcastCount,
    }
    for _, ending in ipairs(StoryData.endings) do
        if not ending.requireAction then
            return ending  -- 默认结局（无条件）
        end
        if (counts[ending.requireAction] or 0) > ending.threshold then
            return ending
        end
    end
    return StoryData.endings[#StoryData.endings]
end

--- 获取游戏结束结局（生命耗尽）
---@return table
function Story:getGameOverEnding()
    return StoryData.gameOverEnding
end

--- 获取选择记录文本
---@return string
function Story:getRecordText()
    return string.format("修复: %d | 探索: %d | 广播: %d",
        self.repairCount, self.exploreCount, self.broadcastCount)
end

--- 重置
function Story:reset()
    self.repairCount = 0
    self.exploreCount = 0
    self.broadcastCount = 0
    self.triggeredIndex = 0
end

return Story
