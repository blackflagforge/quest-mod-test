--[[
    Weapon Kill UI Integration for Soul Quest System
    Updated for new quest selection menu system
    Place this file in: media/lua/client/
    File name: SFQuest_WeaponKillUI.lua
    
    Handles displaying weapon kill progress in quest UIs
]]--

require 'ISUI/ISCollapsableWindow'

SFQuest_WeaponKillUI = ISCollapsableWindow:derive("SFQuest_WeaponKillUI")

-- Static instance for singleton pattern
SFQuest_WeaponKillUI.instance = nil

function SFQuest_WeaponKillUI:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    -- Window properties following PZ patterns
    o.title = "Weapon Kill Progress"
    o.moveWithMouse = true
    o.resizable = false
    o.drawFrame = true
    o:setAlwaysOnTop(false)
    
    -- Styling
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8}
    o.borderColor = {r=0.7, g=0.7, b=0.7, a=0.9}
    
    -- Custom properties
    o.questProgresses = {}
    o.lastUpdateTime = 0
    o.updateInterval = 1000 -- Update every second
    
    return o
end

function SFQuest_WeaponKillUI:initialise()
    ISCollapsableWindow.initialise(self)
    self:setVisible(false)
end

function SFQuest_WeaponKillUI:createChildren()
    ISCollapsableWindow.createChildren(self)
    -- No child components needed - we'll use custom rendering
end

function SFQuest_WeaponKillUI:update()
    ISCollapsableWindow.update(self)
    
    -- Throttled updates following PZ performance patterns
    local currentTime = getTimestampMs()
    if currentTime - self.lastUpdateTime > self.updateInterval then
        self:updateQuestProgress()
        self.lastUpdateTime = currentTime
    end
end

function SFQuest_WeaponKillUI:updateQuestProgress()
    local player = getPlayer()
    if not player or not player:getModData().missionProgress then
        return
    end
    
    local activeQuests = player:getModData().missionProgress.Category2
    if not activeQuests then return end
    
    -- Clear previous data
    self.questProgresses = {}
    local hasActiveKillQuests = false
    
    -- Find weapon kill quests
    for i = 1, #activeQuests do
        local quest = activeQuests[i]
        if quest and quest.killtracking and quest.status ~= "Completed" then
            hasActiveKillQuests = true
            
            local tracking = quest.killtracking
            local currentKills = tracking.currentKills or 0
            local requiredKills = tracking.required or 1
            
            local weaponDisplayName = self:getWeaponDisplayName(tracking.weapon)
            local questTitle = getText(quest.title) or getText(quest.text) or quest.guid
            
            -- Determine status color
            local statusColor = {r=0.9, g=0.9, b=0.9}
            local statusText = ""
            
            if quest.status == "Done" then
                statusColor = {r=0.2, g=0.8, b=0.2}
                statusText = " [COMPLETE]"
            elseif currentKills >= requiredKills then
                statusColor = {r=0.2, g=0.8, b=0.2}
                statusText = " [READY]"
            end
            
            table.insert(self.questProgresses, {
                questName = questTitle .. statusText,
                currentKills = currentKills,
                requiredKills = requiredKills,
                weaponType = tracking.weapon,
                weaponDisplayName = weaponDisplayName,
                percentage = math.min(100, (currentKills / requiredKills) * 100),
                guid = quest.guid,
                status = quest.status,
                statusColor = statusColor
            })
        end
    end
    
    -- Auto-show/hide based on active quests
    if hasActiveKillQuests and not self:getIsVisible() then
        self:setVisible(true)
        self:bringToTop()
    elseif not hasActiveKillQuests and self:getIsVisible() then
        -- Auto-hide when no more active kill quests
        self:setVisible(false)
    end
    
    -- Adjust window height based on content
    local baseHeight = 80
    local contentHeight = #self.questProgresses * 40
    local newHeight = math.max(baseHeight, baseHeight + contentHeight)
    
    if self:getHeight() ~= newHeight then
        self:setHeight(newHeight)
    end
end

function SFQuest_WeaponKillUI:getWeaponDisplayName(weaponType)
    if weaponType == "any" then
        return "Any Weapon"
    elseif weaponType == "BareHands" then
        return "Bare Hands"
    elseif weaponType:find("Category:") then
        local category = weaponType:gsub("Category:", "")
        return category .. " Weapons"
    elseif weaponType:find("Base.") then
        local item = getScriptManager():FindItem(weaponType)
        if item then
            return item:getDisplayName()
        end
    end
    return weaponType
end

function SFQuest_WeaponKillUI:render()
    ISCollapsableWindow.render(self)
    
    if not self:getIsVisible() or #self.questProgresses == 0 then
        return
    end
    
    -- Check if collapsed/minimized
    if self.collapsed or self.minimized or self.isCollapsed or 
       (self.getIsCollapsed and self:getIsCollapsed()) or
       (self.isMinimized and self:isMinimized()) then
        return
    end
    
    if self:getHeight() < 50 then
        return
    end
    
    -- Custom rendering
    local yPos = self:titleBarHeight() + 10
    local margin = 10
    local lineHeight = 40
    
    for i, progress in ipairs(self.questProgresses) do
        local questY = yPos + ((i - 1) * lineHeight)
        
        -- Truncate quest name to fit window
        local questName = self:truncateText(progress.questName, self:getWidth() - 100)
        
        -- Draw quest name with status color
        self:drawText(questName, margin, questY, 
                     progress.statusColor.r, progress.statusColor.g, progress.statusColor.b, 1.0, UIFont.Small)
        
        -- Draw kill count (right aligned)
        local killText = progress.currentKills .. "/" .. progress.requiredKills
        local killTextWidth = getTextManager():MeasureStringX(UIFont.Small, killText)
        self:drawText(killText, self:getWidth() - killTextWidth - margin, questY, 1.0, 1.0, 1.0, 1.0, UIFont.Small)
        
        -- Draw weapon type (smaller, below quest name)
        local weaponText = "(" .. progress.weaponDisplayName .. ")"
        self:drawText(weaponText, margin, questY + 12, 0.7, 0.7, 0.7, 1.0, UIFont.Small)
        
        -- Draw progress bar
        local progressY = questY + 26
        local progressWidth = self:getWidth() - (margin * 2)
        local progressHeight = 6
        local fillWidth = (progress.currentKills / progress.requiredKills) * progressWidth
        
        -- Progress bar background
        self:drawRect(margin, progressY, progressWidth, progressHeight, 0.3, 0.2, 0.2, 0.2)
        
        -- Progress bar fill with color coding
        local fillColor = self:getProgressColor(progress.percentage)
        self:drawRect(margin, progressY, fillWidth, progressHeight, 0.8, fillColor.r, fillColor.g, fillColor.b)
        
        -- Progress bar border
        self:drawRectBorder(margin, progressY, progressWidth, progressHeight, 1.0, 0.8, 0.8, 0.8)
    end
end

function SFQuest_WeaponKillUI:getProgressColor(percentage)
    if percentage >= 100 then
        return {r = 0.2, g = 0.8, b = 0.2} -- Green
    elseif percentage >= 75 then
        return {r = 0.6, g = 0.8, b = 0.2} -- Yellow-green
    elseif percentage >= 50 then
        return {r = 0.8, g = 0.8, b = 0.2} -- Yellow
    elseif percentage >= 25 then
        return {r = 0.8, g = 0.6, b = 0.2} -- Orange
    else
        return {r = 0.8, g = 0.2, b = 0.2} -- Red
    end
end

function SFQuest_WeaponKillUI:truncateText(text, maxWidth)
    local textWidth = getTextManager():MeasureStringX(UIFont.Small, text)
    if textWidth <= maxWidth then
        return text
    end
    
    for i = #text, 1, -1 do
        local truncated = text:sub(1, i) .. "..."
        local truncatedWidth = getTextManager():MeasureStringX(UIFont.Small, truncated)
        if truncatedWidth <= maxWidth then
            return truncated
        end
    end
    
    return "..."
end

function SFQuest_WeaponKillUI:close()
    SFQuest_WeaponKillUI.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

-- Static methods following PZ singleton pattern
function SFQuest_WeaponKillUI.OpenWindow()
    if SFQuest_WeaponKillUI.instance then
        SFQuest_WeaponKillUI.instance:close()
    end
    
    local width, height = 320, 150
    local x = getCore():getScreenWidth() - width - 20
    local y = 50
    
    SFQuest_WeaponKillUI.instance = SFQuest_WeaponKillUI:new(x, y, width, height)
    SFQuest_WeaponKillUI.instance:initialise()
    SFQuest_WeaponKillUI.instance:addToUIManager()
    SFQuest_WeaponKillUI.instance:setVisible(true)
    
    return SFQuest_WeaponKillUI.instance
end

function SFQuest_WeaponKillUI.CloseWindow()
    if SFQuest_WeaponKillUI.instance then
        SFQuest_WeaponKillUI.instance:close()
    end
end

function SFQuest_WeaponKillUI.ToggleWindow()
    if SFQuest_WeaponKillUI.instance and SFQuest_WeaponKillUI.instance:getIsVisible() then
        SFQuest_WeaponKillUI.CloseWindow()
    else
        SFQuest_WeaponKillUI.OpenWindow()
    end
end

function SFQuest_WeaponKillUI.IsOpen()
    return SFQuest_WeaponKillUI.instance and SFQuest_WeaponKillUI.instance:getIsVisible()
end

-- Integration functions for WorldEventWindow

-- Function to get weapon kill progress text for a quest
function SFQuest_WeaponKillUI.getKillProgressText(quest, player)
    if not quest then return "" end
    if not quest.killtracking then return "" end
    if not player then return "" end
    
    local tracking = quest.killtracking
    local weaponType = tracking.weapon
    local requiredKills = tracking.required or 1
    local currentKills = tracking.currentKills or 0
    
    if not weaponType then return "" end
    
    -- Get weapon display name
    local weaponDisplayName = "Unknown Weapon"
    if weaponType == "any" then
        weaponDisplayName = "Any Weapon"
    elseif weaponType == "BareHands" then
        weaponDisplayName = "Bare Hands"
    elseif weaponType:find("Category:") then
        local category = weaponType:gsub("Category:", "")
        weaponDisplayName = category .. " Weapons"
    elseif weaponType:find("Base.") then
        local item = getScriptManager():FindItem(weaponType)
        if item then
            weaponDisplayName = item:getDisplayName()
        end
    else
        weaponDisplayName = weaponType
    end
    
    -- Format progress text
    return string.format(" (%d/%d with %s)", currentKills, requiredKills, weaponDisplayName)
end

-- Function to check if a weapon kill quest is completed
function SFQuest_WeaponKillUI.isKillQuestCompleted(quest, player)
    if not quest then return false end
    if not quest.killtracking then return false end
    if not player then return false end
    
    local tracking = quest.killtracking
    local requiredKills = tracking.required or 1
    local currentKills = tracking.currentKills or 0
    
    return currentKills >= requiredKills
end

-- Function to get weapon requirement text for quest selection
function SFQuest_WeaponKillUI.getWeaponRequirementText(quest)
    if not quest then return "" end
    if not quest.killtracking then return "" end
    
    local tracking = quest.killtracking
    local weaponType = tracking.weapon
    local requiredKills = tracking.required or 1
    
    if not weaponType then return "" end
    
    local weaponDisplayName = "Unknown Weapon"
    if weaponType == "any" then
        weaponDisplayName = "Any Weapon"
    elseif weaponType == "BareHands" then
        weaponDisplayName = "Bare Hands"
    elseif weaponType:find("Category:") then
        local category = weaponType:gsub("Category:", "")
        weaponDisplayName = category .. " Weapons"
    elseif weaponType:find("Base.") then
        local item = getScriptManager():FindItem(weaponType)
        if item then
            weaponDisplayName = item:getDisplayName()
        end
    else
        weaponDisplayName = weaponType
    end
    
    return string.format("Kill %d zombies with %s", requiredKills, weaponDisplayName)
end

-- Keybind for manual control
local function onKeyPressed(key)
    if key == 117 then -- F6 key
        SFQuest_WeaponKillUI.ToggleWindow()
    end
end

-- Event registration
Events.OnKeyPressed.Add(onKeyPressed)

-- Global functions for console access
_G.showWeaponKillUI = SFQuest_WeaponKillUI.OpenWindow
_G.hideWeaponKillUI = SFQuest_WeaponKillUI.CloseWindow
_G.toggleWeaponKillUI = SFQuest_WeaponKillUI.ToggleWindow

print("SFQuest Weapon Kill UI: Loaded (New Menu System)")
print("- F6: Toggle window")
print("- Console: showWeaponKillUI(), hideWeaponKillUI(), toggleWeaponKillUI()")

return SFQuest_WeaponKillUI