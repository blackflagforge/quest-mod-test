--[[
    SFQuest_ZoneKillTracker.lua
    Location: media/lua/client/
    
    Zone-specific kill tracking for zone combat quests
    Tracks zombie kills only after zone entry and quest activation
]]--

SFQuest_ZoneKillTracker = {}

-- Active zone kill tracking
SFQuest_ZoneKillTracker.activeTracking = {}

-- Start kill tracking for a zone quest
function SFQuest_ZoneKillTracker.startZoneKillTracking(questGuid, killRequirement)
    if not questGuid or not killRequirement then
        print("SOUL QUEST SYSTEM - Error: Invalid kill tracking parameters")
        return false
    end
    
    SFQuest_ZoneKillTracker.activeTracking[questGuid] = {
        killRequirement = killRequirement,
        killCount = 0,
        startTime = getTimestampMs(),
        active = true
    }
    
    print("SOUL QUEST SYSTEM - Started kill tracking for quest: " .. questGuid .. " (need " .. killRequirement .. " kills)")
    return true
end

-- Stop kill tracking for a zone quest
function SFQuest_ZoneKillTracker.stopZoneKillTracking(questGuid)
    if SFQuest_ZoneKillTracker.activeTracking[questGuid] then
        SFQuest_ZoneKillTracker.activeTracking[questGuid].active = false
        SFQuest_ZoneKillTracker.activeTracking[questGuid] = nil
        print("SOUL QUEST SYSTEM - Stopped kill tracking for quest: " .. questGuid)
    end
end

-- Get current kill count for a quest
function SFQuest_ZoneKillTracker.getKillCount(questGuid)
    if SFQuest_ZoneKillTracker.activeTracking[questGuid] then
        return SFQuest_ZoneKillTracker.activeTracking[questGuid].killCount
    end
    return 0
end

-- Get kill requirement for a quest
function SFQuest_ZoneKillTracker.getKillRequirement(questGuid)
    if SFQuest_ZoneKillTracker.activeTracking[questGuid] then
        return SFQuest_ZoneKillTracker.activeTracking[questGuid].killRequirement
    end
    return 0
end

-- Check if quest kill requirement is met
function SFQuest_ZoneKillTracker.isKillRequirementMet(questGuid)
    local tracking = SFQuest_ZoneKillTracker.activeTracking[questGuid]
    if tracking then
        return tracking.killCount >= tracking.killRequirement
    end
    return false
end

-- Record a zombie kill for active zone quests
function SFQuest_ZoneKillTracker.recordZombieKill(killer, weapon, zombie)
    if not killer or not instanceof(killer, "IsoPlayer") then
        return
    end
    
    -- Only track kills for the current player
    if killer ~= getPlayer() then
        return
    end
    
    -- Check if this kill should count for any active zone quests
    for questGuid, tracking in pairs(SFQuest_ZoneKillTracker.activeTracking) do
        if tracking.active then
            -- Check if this zombie belongs to this quest (if tagged)
            local questMatch = true
            if zombie and zombie:getModData() and zombie:getModData().questGuid then
                questMatch = zombie:getModData().questGuid == questGuid
            end
            
            if questMatch then
                tracking.killCount = tracking.killCount + 1
                
                print("SOUL QUEST SYSTEM - Zone kill recorded for quest " .. questGuid .. ": " .. tracking.killCount .. "/" .. tracking.killRequirement)
                
                -- Update zone tracker with kill count
                if SFQuest_ZoneTracker and SFQuest_ZoneTracker.activeZones[questGuid] then
                    SFQuest_ZoneTracker.activeZones[questGuid].killCount = tracking.killCount
                end
                
                -- Update player data
                local player = getPlayer()
                if player and player:getModData().missionProgress and player:getModData().missionProgress.ZoneCombat and player:getModData().missionProgress.ZoneCombat[questGuid] then
                    player:getModData().missionProgress.ZoneCombat[questGuid].killCount = tracking.killCount
                end
                
                -- Check if requirement is met
                if tracking.killCount >= tracking.killRequirement then
                    SFQuest_ZoneKillTracker.onKillRequirementMet(questGuid)
                end
                
                -- Update quest UI
                if SF_MissionPanel and SF_MissionPanel.instance then
                    SF_MissionPanel.instance.needsUpdate = true
                end
            end
        end
    end
end

-- Handle kill requirement completion
function SFQuest_ZoneKillTracker.onKillRequirementMet(questGuid)
    print("SOUL QUEST SYSTEM - Kill requirement met for quest: " .. questGuid)
    
    -- Stop tracking for this quest
    SFQuest_ZoneKillTracker.stopZoneKillTracking(questGuid)
    
    -- Notify zone tracker that quest is completed
    if SFQuest_ZoneTracker then
        SFQuest_ZoneTracker.completeZoneQuest(questGuid)
    end
    
    -- Play completion sound
    getSoundManager():playUISound("levelup")
    
    -- Show notification to player
    local player = getPlayer()
    if player then
        player:Say("Zone cleared! All zombies eliminated.")
    end
end

-- Get kill progress text for UI display
function SFQuest_ZoneKillTracker.getKillProgressText(questGuid)
    local tracking = SFQuest_ZoneKillTracker.activeTracking[questGuid]
    if tracking then
        return string.format("Zombies Killed: %d/%d", tracking.killCount, tracking.killRequirement)
    end
    return ""
end

-- Event handler for zombie death
local function onZombieDeath(zombie)
    if not zombie then return end
    
    -- Try to get the killer from various sources
    local killer = nil
    local weapon = nil
    
    -- Try built-in methods first
    if zombie.getKiller and zombie:getKiller() then
        killer = zombie:getKiller()
    elseif zombie.getLastAttacker and zombie:getLastAttacker() then
        killer = zombie:getLastAttacker()
    elseif zombie.getTarget and zombie:getTarget() then
        local target = zombie:getTarget()
        if instanceof(target, "IsoPlayer") then
            killer = target
        end
    end
    
    -- Get weapon if killer found
    if killer and instanceof(killer, "IsoPlayer") then
        local primaryWeapon = killer:getPrimaryHandItem()
        local secondaryWeapon = killer:getSecondaryHandItem()
        
        if primaryWeapon then
            weapon = primaryWeapon
        elseif secondaryWeapon then
            weapon = secondaryWeapon
        end
    end
    
    -- Record the kill if we have a valid killer
    if killer then
        SFQuest_ZoneKillTracker.recordZombieKill(killer, weapon, zombie)
    end
end

-- Event handler for player death (fail all active zone quests)
local function onPlayerDeath(player)
    if player == getPlayer() then
        -- Stop all active kill tracking
        for questGuid, tracking in pairs(SFQuest_ZoneKillTracker.activeTracking) do
            if tracking.active then
                print("SOUL QUEST SYSTEM - Player died, failing zone quest: " .. questGuid)
                SFQuest_ZoneKillTracker.stopZoneKillTracking(questGuid)
                
                -- Notify zone tracker of failure
                if SFQuest_ZoneTracker then
                    SFQuest_ZoneTracker.failZoneQuest(questGuid)
                end
            end
        end
    end
end

-- Initialize on game start
local function onGameStart()
    local player = getPlayer()
    if player then
        print("SOUL QUEST SYSTEM - Zone kill tracker initialized")
        
        -- Restore kill tracking for any active zone quests
        if player:getModData().missionProgress and player:getModData().missionProgress.ZoneCombat then
            for questGuid, zoneData in pairs(player:getModData().missionProgress.ZoneCombat) do
                if zoneData.status == "active" and zoneData.killRequirement then
                    -- Restore kill tracking
                    SFQuest_ZoneKillTracker.activeTracking[questGuid] = {
                        killRequirement = zoneData.killRequirement,
                        killCount = zoneData.killCount or 0,
                        startTime = getTimestampMs(),
                        active = true
                    }
                    print("SOUL QUEST SYSTEM - Restored kill tracking for quest: " .. questGuid .. " (" .. (zoneData.killCount or 0) .. "/" .. zoneData.killRequirement .. ")")
                end
            end
        end
    end
end

-- Event registration
Events.OnZombieDead.Add(onZombieDeath)
Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnGameStart.Add(onGameStart)

print("SOUL QUEST SYSTEM - Zone Kill Tracker loaded")

return SFQuest_ZoneKillTracker