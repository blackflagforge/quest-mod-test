--[[
    SFQuest_ZoneTracker.lua
    Location: media/lua/client/
    
    Client-side zone combat quest tracking system
    Monitors player movement and triggers zombie spawning when entering quest zones
]]--

require 'SFQuest_ZoneKillTracker'

SFQuest_ZoneTracker = {}

-- Tracking state
SFQuest_ZoneTracker.activeZones = {}
SFQuest_ZoneTracker.movementCounter = 0
SFQuest_ZoneTracker.trackingActive = false

-- Dynamic tracking control
function SFQuest_ZoneTracker.startTracking()
    if not SFQuest_ZoneTracker.trackingActive then
        Events.OnPlayerMove.Add(SFQuest_ZoneTracker.onPlayerMove)
        SFQuest_ZoneTracker.trackingActive = true
        print("SOUL QUEST SYSTEM - Started player tracking")
    end
end

function SFQuest_ZoneTracker.stopTracking()
    if SFQuest_ZoneTracker.trackingActive then
        Events.OnPlayerMove.Remove(SFQuest_ZoneTracker.onPlayerMove)
        SFQuest_ZoneTracker.trackingActive = false
        print("SOUL QUEST SYSTEM - Stopped player tracking")
    end
end

-- Add a zone combat quest to tracking
function SFQuest_ZoneTracker.addZoneQuest(questGuid, zoneData)
    if not questGuid or not zoneData then
        print("SOUL QUEST SYSTEM - Error: Invalid zone quest data")
        return false
    end
    
    local player = getPlayer()
    if not player then return false end
    
    -- Parse zone data: "x1,y1,x2,y2,z;spawnCount,outfit1,outfit2;femaleChance;spawnX1,spawnY1,spawnX2,spawnY2;exclusionRadius,killRequirement"
    local parts = luautils.split(zoneData, ";")
    if #parts < 5 then
        print("SOUL QUEST SYSTEM - Error: Invalid zone data format")
        return false
    end
    
    -- Parse trigger zone coordinates
    local zoneCoords = luautils.split(parts[1], ",")
    if #zoneCoords < 5 then
        print("SOUL QUEST SYSTEM - Error: Invalid zone coordinates")
        return false
    end
    
    -- Parse spawn data
    local spawnInfo = luautils.split(parts[2], ",")
    local spawnCount = tonumber(spawnInfo[1]) or 10
    local outfits = {}
    for i = 2, #spawnInfo do
        table.insert(outfits, spawnInfo[i])
    end
    
    -- Parse other parameters
    local femaleChance = tonumber(parts[3]) or 50
    
    local spawnAreaCoords = luautils.split(parts[4], ",")
    if #spawnAreaCoords < 4 then
        print("SOUL QUEST SYSTEM - Error: Invalid spawn area coordinates")
        return false
    end
    
    local finalParams = luautils.split(parts[5], ",")
    local exclusionRadius = tonumber(finalParams[1]) or 5
    local killRequirement = tonumber(finalParams[2]) or 5
    
    -- Create zone quest data
    local zoneQuest = {
        questGuid = questGuid,
        status = "waiting",
        triggered = false,
        
        -- Trigger zone
        triggerX1 = tonumber(zoneCoords[1]),
        triggerY1 = tonumber(zoneCoords[2]),
        triggerX2 = tonumber(zoneCoords[3]),
        triggerY2 = tonumber(zoneCoords[4]),
        triggerZ = tonumber(zoneCoords[5]),
        
        -- Spawn parameters
        spawnCount = spawnCount,
        outfits = outfits,
        femaleChance = femaleChance,
        spawnX1 = tonumber(spawnAreaCoords[1]),
        spawnY1 = tonumber(spawnAreaCoords[2]),
        spawnX2 = tonumber(spawnAreaCoords[3]),
        spawnY2 = tonumber(spawnAreaCoords[4]),
        spawnZ = tonumber(zoneCoords[5]),
        
        -- Combat parameters
        exclusionRadius = exclusionRadius,
        killRequirement = killRequirement,
        killCount = 0
    }
    
    -- Store in player data and active tracking
    if not player:getModData().missionProgress.ZoneCombat then
        player:getModData().missionProgress.ZoneCombat = {}
    end
    
    player:getModData().missionProgress.ZoneCombat[questGuid] = zoneQuest
    SFQuest_ZoneTracker.activeZones[questGuid] = zoneQuest
    
    -- Start tracking when first zone quest is added
    SFQuest_ZoneTracker.startTracking()
    
    print("SOUL QUEST SYSTEM - Zone combat quest added: " .. questGuid)
    print("SOUL QUEST SYSTEM - Trigger zone: " .. zoneQuest.triggerX1 .. "," .. zoneQuest.triggerY1 .. " to " .. zoneQuest.triggerX2 .. "," .. zoneQuest.triggerY2)
    
    return true
end

-- Remove zone quest from tracking
function SFQuest_ZoneTracker.removeZoneQuest(questGuid)
    local player = getPlayer()
    if not player then return end
    
    -- Remove from active tracking
    SFQuest_ZoneTracker.activeZones[questGuid] = nil
    
    -- Remove from player data
    if player:getModData().missionProgress and player:getModData().missionProgress.ZoneCombat then
        player:getModData().missionProgress.ZoneCombat[questGuid] = nil
    end
    
    -- Stop tracking if no more zones
    if next(SFQuest_ZoneTracker.activeZones) == nil then
        SFQuest_ZoneTracker.stopTracking()
    end
    
    print("SOUL QUEST SYSTEM - Zone quest removed: " .. questGuid)
end

-- Check if player is within zone coordinates
function SFQuest_ZoneTracker.isPlayerInZone(player, zone)
    if not player or not zone then return false end
    
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    
    if not x then return false end
    
    local inX = x >= math.min(zone.triggerX1, zone.triggerX2) and x <= math.max(zone.triggerX1, zone.triggerX2)
    local inY = y >= math.min(zone.triggerY1, zone.triggerY2) and y <= math.max(zone.triggerY1, zone.triggerY2)
    local inZ = z == zone.triggerZ
    
    return inX and inY and inZ
end

-- Main tracking function (like pager system)
function SFQuest_ZoneTracker.trackPlayerMovement(player)
    if not player then return end
    
    -- Early exit if no active zones
    if next(SFQuest_ZoneTracker.activeZones) == nil then
        return
    end
    
    SFQuest_ZoneTracker.movementCounter = SFQuest_ZoneTracker.movementCounter + 1
    
    local threshold = 5
    
    -- Calculate threshold based on distance to closest zone (pager system pattern)
    for questGuid, zone in pairs(SFQuest_ZoneTracker.activeZones) do
        if zone.status == "waiting" then
            local zoneCenterX = (zone.triggerX1 + zone.triggerX2) / 2
            local zoneCenterY = (zone.triggerY1 + zone.triggerY2) / 2
            local dx = player:getX() - zoneCenterX
            local dy = player:getY() - zoneCenterY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance > 100 then
                threshold = 25
            elseif distance > 40 then
                threshold = 10
            elseif distance > 20 then
                threshold = 5
            else
                threshold = 3
            end
            break
        end
    end
    
    if SFQuest_ZoneTracker.movementCounter < threshold then
        return
    end
    
    SFQuest_ZoneTracker.movementCounter = 0
    
    -- Check each active zone
    for questGuid, zone in pairs(SFQuest_ZoneTracker.activeZones) do
        if zone.status == "waiting" and not zone.triggered then
            if SFQuest_ZoneTracker.isPlayerInZone(player, zone) then
                SFQuest_ZoneTracker.triggerZoneEntry(player, questGuid, zone)
            end
        elseif zone.status == "active" then
            if not SFQuest_ZoneTracker.isPlayerInZone(player, zone) then
                SFQuest_ZoneTracker.handleZoneExit(player, questGuid, zone)
            end
        end
    end
end

-- Handle zone entry - trigger zombie spawning
function SFQuest_ZoneTracker.triggerZoneEntry(player, questGuid, zone)
    print("SOUL QUEST SYSTEM - ZONE ENTRY DETECTED: Player entered target zone for quest " .. questGuid .. " at coordinates " .. player:getX() .. "," .. player:getY())
    
    -- Mark as triggered
    zone.triggered = true
    zone.status = "active"
    
    -- Update stored data
    if player:getModData().missionProgress.ZoneCombat[questGuid] then
        player:getModData().missionProgress.ZoneCombat[questGuid].triggered = true
        player:getModData().missionProgress.ZoneCombat[questGuid].status = "active"
    end
    
    -- Send spawn command to server
    local spawnData = {
        questGuid = questGuid,
        spawnCount = zone.spawnCount,
        outfits = zone.outfits,
        femaleChance = zone.femaleChance,
        spawnX1 = zone.spawnX1,
        spawnY1 = zone.spawnY1,
        spawnX2 = zone.spawnX2,
        spawnY2 = zone.spawnY2,
        spawnZ = zone.spawnZ,
        exclusionRadius = zone.exclusionRadius,
        playerX = player:getX(),
        playerY = player:getY()
    }
    
    print("SOUL QUEST SYSTEM - SENDING SPAWN COMMAND: Requesting " .. zone.spawnCount .. " zombies for quest " .. questGuid)
    sendClientCommand(player, 'SFQuest', 'spawnZombies', spawnData)
    
    -- Start kill tracking
    if SFQuest_ZoneKillTracker then
        SFQuest_ZoneKillTracker.startZoneKillTracking(questGuid, zone.killRequirement)
    end
    
    -- Update quest status
    if SF_MissionPanel and SF_MissionPanel.instance then
        SF_MissionPanel.instance:updateQuestStatus(questGuid, "Obtained")
        SF_MissionPanel.instance.needsUpdate = true
        SF_MissionPanel.instance.needsBackup = true
    end
end

-- Handle player leaving zone
function SFQuest_ZoneTracker.handleZoneExit(player, questGuid, zone)
    print("SOUL QUEST SYSTEM - Player left active zone for quest: " .. questGuid)
    
    zone.status = "abandoned"
    
    -- Stop kill tracking
    if SFQuest_ZoneKillTracker then
        SFQuest_ZoneKillTracker.stopZoneKillTracking(questGuid)
    end
    
    -- Update quest status to failed
    if SF_MissionPanel and SF_MissionPanel.instance then
        SF_MissionPanel.instance:updateQuestStatus(questGuid, "Failed")
        SF_MissionPanel.instance.needsUpdate = true
    end
    
    SFQuest_ZoneTracker.removeZoneQuest(questGuid)
end

-- Handle zombie spawn confirmation from server
function SFQuest_ZoneTracker.onZombiesSpawned(questGuid)
    local zone = SFQuest_ZoneTracker.activeZones[questGuid]
    if zone then
        print("SOUL QUEST SYSTEM - Zombies spawned confirmed for quest: " .. questGuid)
    end
end

-- Handle zone quest completion
function SFQuest_ZoneTracker.completeZoneQuest(questGuid)
    local player = getPlayer()
    if not player then return end
    
    local zone = SFQuest_ZoneTracker.activeZones[questGuid]
    if zone then
        zone.status = "completed"
        print("SOUL QUEST SYSTEM - Zone quest completed: " .. questGuid)
        
        if SF_MissionPanel and SF_MissionPanel.instance then
            SF_MissionPanel.instance:completeQuest(player, questGuid)
        end
        
        SFQuest_ZoneTracker.removeZoneQuest(questGuid)
    end
end

-- Handle zone quest failure
function SFQuest_ZoneTracker.failZoneQuest(questGuid)
    local player = getPlayer()
    if not player then return end
    
    local zone = SFQuest_ZoneTracker.activeZones[questGuid]
    if zone then
        zone.status = "failed"
        print("SOUL QUEST SYSTEM - Zone quest failed: " .. questGuid)
        
        if SFQuest_ZoneKillTracker then
            SFQuest_ZoneKillTracker.stopZoneKillTracking(questGuid)
        end
        
        if SF_MissionPanel and SF_MissionPanel.instance then
            SF_MissionPanel.instance:updateQuestStatus(questGuid, "Failed")
            SF_MissionPanel.instance.needsUpdate = true
        end
        
        SFQuest_ZoneTracker.removeZoneQuest(questGuid)
    end
end

-- Event handlers
function SFQuest_ZoneTracker.onPlayerMove(player)
    if player == getPlayer() then
        SFQuest_ZoneTracker.trackPlayerMovement(player)
    end
end

local function onPlayerDeath(player)
    if player == getPlayer() then
        for questGuid, zone in pairs(SFQuest_ZoneTracker.activeZones) do
            if zone.status == "active" then
                SFQuest_ZoneTracker.failZoneQuest(questGuid)
            end
        end
    end
end

local function onGameStart()
    local player = getPlayer()
    if player then
        -- Initialize ZoneCombat table if needed
        if not player:getModData().missionProgress then
            return
        end
        
        if not player:getModData().missionProgress.ZoneCombat then
            player:getModData().missionProgress.ZoneCombat = {}
        end
        
        -- Restore active zone quests from save data
        for questGuid, zoneData in pairs(player:getModData().missionProgress.ZoneCombat) do
            if zoneData.status == "waiting" or zoneData.status == "active" then
                SFQuest_ZoneTracker.activeZones[questGuid] = zoneData
                SFQuest_ZoneTracker.startTracking()
                print("SOUL QUEST SYSTEM - Restored zone quest: " .. questGuid)
            end
        end
        
        print("SOUL QUEST SYSTEM - Zone tracker initialized")
    end
end

-- Event registration
Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnGameStart.Add(onGameStart)

print("SOUL QUEST SYSTEM - Zone Tracker loaded")

return SFQuest_ZoneTracker