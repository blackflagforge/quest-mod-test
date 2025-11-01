--[[
    Enhanced Zombie Kill Tracker for Soul Quest System
    Updated for new quest selection menu system
    FIXED VERSION - Proper completion flow
    Place this file in: media/lua/client/
    File name: SFQuest_ZombieKillTracker.lua
]]--

SFQuest_ZombieKillTracker = {}

-- Table to track who last hit each zombie and with what weapon
local zombieAttackers = {}

-- Initialize the tracker for a player
local function initPlayerTracker(player)
    if not player then return end
    -- Player tracking now handled directly in quest.killtracking objects
end

-- Function to get weapon identifier for tracking
local function getWeaponIdentifier(weapon)
    if not weapon then
        return "BareHands"
    end
    
    -- Get the full type (e.g., "Base.Axe", "Base.Pistol")
    if weapon.getFullType then
        return weapon:getFullType()
    elseif weapon.getType then
        return weapon:getType()
    else
        return "Unknown"
    end
end

-- Function to get weapon category for broader tracking
local function getWeaponCategory(weapon)
    if not weapon then
        return "BareHands"
    end
    
    local weaponType = weapon:getType()
    if not weaponType then
        return "Unknown"
    end
    
    -- Define weapon categories based on examples
    if weapon:isRanged() then
        if weaponType:find("Pistol") or weaponType:find("Revolver") then
            return "Pistol"
        elseif weaponType:find("Rifle") or weaponType:find("HuntingRifle") then
            return "Rifle"
        elseif weaponType:find("Shotgun") then
            return "Shotgun"
        else
            return "Firearm"
        end
    else
        if weaponType:find("Axe") then
            return "Axe"
        elseif weaponType:find("Knife") or weaponType:find("Blade") or weaponType:find("Machete") or weaponType:find("Katana") then
            return "Blade"
        elseif weaponType:find("Bat") or weaponType:find("Club") or weaponType:find("Hammer") then
            return "Blunt"
        elseif weaponType:find("Spear") then
            return "Spear"
        else
            return "Melee"
        end
    end
end

-- Check if player has active weapon-specific kill quests
local function hasActiveWeaponKillQuest(player)
    if not player then return false end
    if not player:getModData() then return false end
    if not player:getModData().missionProgress then return false end
    if not player:getModData().missionProgress.Category2 then return false end
    
    local activeQuests = player:getModData().missionProgress.Category2
    for i = 1, #activeQuests do
        local quest = activeQuests[i]
        if quest and quest.killtracking and quest.status ~= "Obtained" and quest.status ~= "Done" and quest.status ~= "Completed" then
            return true
        end
    end
    return false
end

-- Check if a kill matches quest requirements
local function doesKillMatchQuest(weapon, quest)
    if not quest.killtracking then return false end
    
    local tracking = quest.killtracking
    local weaponType = tracking.weapon
    
    -- Check weapon-specific requirements
    if weaponType == "BareHands" and not weapon then
        return true
    elseif weaponType == "any" then
        return true
    elseif weaponType:find("Category:") then
        local category = weaponType:gsub("Category:", "")
        local weaponCategory = getWeaponCategory(weapon)
        return weaponCategory == category
    elseif weapon then
        local weaponId = getWeaponIdentifier(weapon)
        return weaponId == weaponType or weaponId:find(weaponType)
    end
    
    return false
end

-- Track weapon kills for active quests
local function trackWeaponKill(player, weapon, killType)
    if not player or not hasActiveWeaponKillQuest(player) then
        return
    end
    
    -- Check all active quests to see if this kill counts
    if player:getModData().missionProgress and player:getModData().missionProgress.Category2 then
        local activeQuests = player:getModData().missionProgress.Category2
        local questsUpdated = false
        
        for i = 1, #activeQuests do
            local quest = activeQuests[i]
            if quest and quest.killtracking and quest.status ~= "Obtained" and quest.status ~= "Done" and quest.status ~= "Completed" then
                if doesKillMatchQuest(weapon, quest) then
                    -- Initialize current kills if needed
                    if not quest.killtracking.currentKills then
                        quest.killtracking.currentKills = 0
                    end
                    
                    -- Increment kill count for this quest
                    quest.killtracking.currentKills = quest.killtracking.currentKills + 1
                    
                    local required = quest.killtracking.required or 1
                    local currentKills = quest.killtracking.currentKills
                    
                    print("SOUL QUEST SYSTEM - Kill tracked for quest " .. quest.guid .. ": " .. currentKills .. "/" .. required)
                    
                    questsUpdated = true
                    
                    -- Check if quest is completed
                    if currentKills >= required then
                        print("SOUL QUEST SYSTEM - Kill quest completed: " .. quest.guid)
                        -- FIXED: Set status to "Obtained" so player can turn it in
                        quest.status = "Obtained"
                        
                        -- Trigger onobtained commands (like unlocking completion dialogue)
                        if quest.onobtained then
                            local commandTable = luautils.split(quest.onobtained, ";")
                            if SF_MissionPanel and SF_MissionPanel.instance then
                                SF_MissionPanel.instance:readCommandTable(commandTable)
                            end
                        end
                        
                        -- Update mission panel
                        if SF_MissionPanel and SF_MissionPanel.instance then
                            SF_MissionPanel.instance.needsUpdate = true
                            SF_MissionPanel.instance.needsBackup = true
                        end
                        
                        -- Play completion sound
                        getSoundManager():playUISound("levelup")
                    end
                end
            end
        end
        
        -- Update weapon kill UI if quests were updated
        if questsUpdated then
            -- Signal WeaponKillUI to update
            if SFQuest_WeaponKillUI and SFQuest_WeaponKillUI.instance then
                SFQuest_WeaponKillUI.instance:updateQuestProgress()
            end
            
            -- Auto-open WeaponKillUI if not already open and we have active kill quests
            if SFQuest_WeaponKillUI and not SFQuest_WeaponKillUI.IsOpen() then
                SFQuest_WeaponKillUI.OpenWindow()
            end
        end
    end
end

-- Event handler for zombie death
local function onZombieDeath(zombie)
    if not zombie then return end
    
    -- Try to get the killer from our tracking table first
    local zombieID = zombie:getOnlineID()
    local attackerData = nil
    if zombieID and zombieAttackers[zombieID] then
        attackerData = zombieAttackers[zombieID]
    end
    
    local killer = nil
    local weapon = nil
    
    if attackerData then
        killer = attackerData.attacker
        weapon = attackerData.weapon
    else
        -- Fallback: try built-in methods
        if zombie.getKiller then
            killer = zombie:getKiller()
        elseif zombie.getLastAttacker then
            killer = zombie:getLastAttacker()
        elseif zombie.getTarget then
            local target = zombie:getTarget()
            if target and instanceof(target, "IsoPlayer") then
                killer = target
            end
        end
    end
    
    -- Only process if killer is a player
    if not killer or not instanceof(killer, "IsoPlayer") then
        return
    end
    
    -- Get weapon if not already obtained
    if not weapon then
        local primaryWeapon = killer:getPrimaryHandItem()
        local secondaryWeapon = killer:getSecondaryHandItem()
        
        if primaryWeapon then
            weapon = primaryWeapon
        elseif secondaryWeapon then
            weapon = secondaryWeapon
        end
    end
    
    -- Track the weapon kill
    trackWeaponKill(killer, weapon, "zombie")
    
    -- Clean up tracking data
    if zombieID and zombieAttackers[zombieID] then
        zombieAttackers[zombieID] = nil
    end
end

-- Track zombie hits to record weapon used
local function onWeaponHitCharacter(attacker, victim, weapon, damage)
    if not victim or not attacker then return end
    
    -- Only track player attacks on zombies
    if instanceof(attacker, "IsoPlayer") and instanceof(victim, "IsoZombie") then
        local zombieID = victim:getOnlineID()
        if zombieID then
            zombieAttackers[zombieID] = {
                attacker = attacker,
                weapon = weapon
            }
        end
    end
end

-- Public API functions for quest system integration

-- Get current weapon kill count for a quest
function SFQuest_ZombieKillTracker.getWeaponKillCount(player, weaponType)
    if not player then return 0 end
    if not weaponType then return 0 end
    
    -- For new system, we look directly in quest data
    if player:getModData().missionProgress and player:getModData().missionProgress.Category2 then
        local activeQuests = player:getModData().missionProgress.Category2
        
        for i = 1, #activeQuests do
            local quest = activeQuests[i]
            if quest and quest.killtracking and quest.killtracking.weapon == weaponType then
                return quest.killtracking.currentKills or 0
            end
        end
    end
    
    return 0
end

-- Get weapon display name for UI
function SFQuest_ZombieKillTracker.getWeaponDisplayName(weaponType)
    if not weaponType then return "Unknown Weapon" end
    
    if weaponType == "any" then
        return getText("IGUI_WeaponKill_AnyWeapon") or "Any Weapon"
    elseif weaponType == "BareHands" or weaponType == "Bare Hands" then
        return getText("IGUI_WeaponKill_BareHands") or "Bare Hands"
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

-- Get kill progress text for a quest (for UI display)
function SFQuest_ZombieKillTracker.getKillProgressText(quest, player)
    if not quest or not quest.killtracking or not player then
        return ""
    end
    
    local tracking = quest.killtracking
    local currentKills = tracking.currentKills or 0
    local requiredKills = tracking.required or 1
    
    local weaponName = SFQuest_ZombieKillTracker.getWeaponDisplayName(tracking.weapon)
    
    return string.format(" (%d/%d with %s)", currentKills, requiredKills, weaponName)
end

-- Reset weapon kill tracker for a player (useful when quest completes)
function SFQuest_ZombieKillTracker.resetPlayerTracker(player)
    if not player then return end
    -- For new system, we don't need to reset anything as data is in quest objects
end

-- Check if quest has active weapon kill tracking
function SFQuest_ZombieKillTracker.hasActiveKillQuests(player)
    return hasActiveWeaponKillQuest(player)
end

-- Initialize tracker when player is created
local function onCreatePlayer(playerIndex, player)
    initPlayerTracker(player)
end

-- Handle quest unlocking - check if we need to show weapon kill UI
local function onQuestUnlocked()
    local player = getPlayer()
    if not player then return end
    
    -- Check if any weapon kill quests are now active
    if hasActiveWeaponKillQuest(player) then
        -- Auto-open weapon kill UI if not already open
        if SFQuest_WeaponKillUI and not SFQuest_WeaponKillUI.IsOpen() then
            SFQuest_WeaponKillUI.OpenWindow()
        end
    end
end

-- Event registration
Events.OnZombieDead.Add(onZombieDeath)
Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
Events.OnCreatePlayer.Add(onCreatePlayer)

-- Check for weapon kill quests on game start
Events.OnGameStart.Add(function()
    local player = getPlayer()
    if player and hasActiveWeaponKillQuest(player) then
        -- Auto-open weapon kill UI if we have active kill quests
        if SFQuest_WeaponKillUI and not SFQuest_WeaponKillUI.IsOpen() then
            SFQuest_WeaponKillUI.OpenWindow()
        end
    end
end)

print("SOUL QUEST SYSTEM - Enhanced Zombie Kill Tracker loaded (FIXED - Proper completion flow)")

return SFQuest_ZombieKillTracker