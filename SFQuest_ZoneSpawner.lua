--[[
    SFQuest_ZoneSpawner.lua
    Location: media/lua/server/
    
    Server-side zombie spawning system for zone combat quests
    Handles spawn requests from clients and executes zombie creation
]]--

SFQuest_ZoneSpawner = {}

-- Validate spawn request data
function SFQuest_ZoneSpawner.validateSpawnRequest(player, spawnData)
    if not player or not spawnData then
        print("SOUL QUEST SYSTEM - Error: Invalid spawn request data")
        return false
    end
    
    -- Validate required fields
    local required = {"questGuid", "spawnCount", "outfits", "spawnX1", "spawnY1", "spawnX2", "spawnY2", "spawnZ", "playerX", "playerY"}
    for _, field in ipairs(required) do
        if not spawnData[field] then
            print("SOUL QUEST SYSTEM - Error: Missing required field: " .. field)
            return false
        end
    end
    
    -- Validate spawn count
    if spawnData.spawnCount <= 0 or spawnData.spawnCount > 100 then
        print("SOUL QUEST SYSTEM - Error: Invalid spawn count: " .. spawnData.spawnCount)
        return false
    end
    
    -- Validate coordinates
    if spawnData.spawnX1 == spawnData.spawnX2 or spawnData.spawnY1 == spawnData.spawnY2 then
        print("SOUL QUEST SYSTEM - Error: Invalid spawn area coordinates")
        return false
    end
    
    -- Validate outfits
    if not spawnData.outfits or #spawnData.outfits == 0 then
        print("SOUL QUEST SYSTEM - Error: No outfits specified")
        return false
    end
    
    return true
end

-- Get random coordinates within spawn area, excluding player area
function SFQuest_ZoneSpawner.getRandomSpawnCoordinates(spawnData)
    local minX = math.min(spawnData.spawnX1, spawnData.spawnX2)
    local maxX = math.max(spawnData.spawnX1, spawnData.spawnX2)
    local minY = math.min(spawnData.spawnY1, spawnData.spawnY2)
    local maxY = math.max(spawnData.spawnY1, spawnData.spawnY2)
    
    local attempts = 0
    local maxAttempts = 50
    
    while attempts < maxAttempts do
        local randomX = minX + ZombRand(maxX - minX + 1)
        local randomY = minY + ZombRand(maxY - minY + 1)
        
        -- Check if coordinates are outside exclusion radius around player
        local dx = randomX - spawnData.playerX
        local dy = randomY - spawnData.playerY
        local distanceSquared = dx * dx + dy * dy
        local exclusionRadiusSquared = spawnData.exclusionRadius * spawnData.exclusionRadius
        
        if distanceSquared > exclusionRadiusSquared then
            return randomX, randomY
        end
        
        attempts = attempts + 1
    end
    
    -- If we can't find a good spot, use the furthest corner from player
    local corners = {
        {minX, minY},
        {maxX, minY},
        {minX, maxY},
        {maxX, maxY}
    }
    
    local bestX, bestY = minX, minY
    local maxDistance = 0
    
    for _, corner in ipairs(corners) do
        local dx = corner[1] - spawnData.playerX
        local dy = corner[2] - spawnData.playerY
        local distance = dx * dx + dy * dy
        
        if distance > maxDistance then
            maxDistance = distance
            bestX, bestY = corner[1], corner[2]
        end
    end
    
    return bestX, bestY
end

-- Distribute zombies across available outfits
function SFQuest_ZoneSpawner.distributeZombiesAcrossOutfits(spawnCount, outfits)
    local distribution = {}
    local zombiesPerOutfit = math.floor(spawnCount / #outfits)
    local remainingZombies = spawnCount % #outfits
    
    for i, outfit in ipairs(outfits) do
        local zombieCount = zombiesPerOutfit + (i <= remainingZombies and 1 or 0)
        if zombieCount > 0 then
            distribution[outfit] = zombieCount
        end
    end
    
    return distribution
end

-- Main zombie spawning function
function SFQuest_ZoneSpawner.spawnZombiesForQuest(player, spawnData)
    if not SFQuest_ZoneSpawner.validateSpawnRequest(player, spawnData) then
        return false
    end
    
    print("SOUL QUEST SYSTEM - Spawning zombies for quest: " .. spawnData.questGuid)
    print("SOUL QUEST SYSTEM - Spawn count: " .. spawnData.spawnCount)
    print("SOUL QUEST SYSTEM - Spawn area: " .. spawnData.spawnX1 .. "," .. spawnData.spawnY1 .. " to " .. spawnData.spawnX2 .. "," .. spawnData.spawnY2)
    print("SOUL QUEST SYSTEM - Player exclusion: " .. spawnData.playerX .. "," .. spawnData.playerY .. " radius " .. spawnData.exclusionRadius)
    
    -- Distribute zombies across outfits
    local outfitDistribution = SFQuest_ZoneSpawner.distributeZombiesAcrossOutfits(spawnData.spawnCount, spawnData.outfits)
    
    local totalSpawned = 0
    local femaleChance = spawnData.femaleChance or 50
    
    -- Spawn zombies for each outfit
    for outfit, zombieCount in pairs(outfitDistribution) do
        for i = 1, zombieCount do
            local spawnX, spawnY = SFQuest_ZoneSpawner.getRandomSpawnCoordinates(spawnData)
            
            print("SOUL QUEST SYSTEM - Spawning zombie " .. (totalSpawned + 1) .. " at " .. spawnX .. "," .. spawnY .. " with outfit " .. outfit)
            
            -- Spawn zombie using game's addZombiesInOutfit function
            local zombies = addZombiesInOutfit(spawnX, spawnY, spawnData.spawnZ, 1, outfit, femaleChance, false, false, false, false, 1)
            
            if zombies and zombies:size() > 0 then
                local zombie = zombies:get(0)
                if zombie then
                    -- Optional: Set zombie as aggressive or add custom behavior
                    zombie:setUseless(false)
                    totalSpawned = totalSpawned + 1
                    
                    -- Optional: Tag zombie with quest GUID for tracking
                    zombie:getModData().questGuid = spawnData.questGuid
                    
                    print("SOUL QUEST SYSTEM - Successfully spawned zombie " .. totalSpawned)
                else
                    print("SOUL QUEST SYSTEM - Warning: Failed to get zombie reference")
                end
            else
                print("SOUL QUEST SYSTEM - Warning: Failed to spawn zombie at " .. spawnX .. "," .. spawnY)
            end
        end
    end
    
    print("SOUL QUEST SYSTEM - Total zombies spawned: " .. totalSpawned .. " out of " .. spawnData.spawnCount)
    
    -- Send confirmation back to client
    local confirmData = {
        questGuid = spawnData.questGuid,
        spawnedCount = totalSpawned,
        requestedCount = spawnData.spawnCount
    }
    
    sendServerCommand(player, 'SFQuest', 'zoneSpawned', confirmData)
    
    return totalSpawned > 0
end

-- Handle client spawn requests
function SFQuest_ZoneSpawner.handleSpawnRequest(player, args)
    if not player or not args then
        print("SOUL QUEST SYSTEM - Error: Invalid spawn request")
        return
    end
    
    -- Verify player is online and valid
    if not player:isAlive() then
        print("SOUL QUEST SYSTEM - Error: Player is not alive, cannot spawn zombies")
        return
    end
    
    -- Additional validation: Check if player is actually near the spawn area
    local playerSquare = player:getSquare()
    if not playerSquare then
        print("SOUL QUEST SYSTEM - Error: Cannot get player position")
        return
    end
    
    local playerX = playerSquare:getX()
    local playerY = playerSquare:getY()
    local playerZ = playerSquare:getZ()
    
    -- Verify player is within reasonable distance of spawn area
    local spawnCenterX = (args.spawnX1 + args.spawnX2) / 2
    local spawnCenterY = (args.spawnY1 + args.spawnY2) / 2
    
    local dx = playerX - spawnCenterX
    local dy = playerY - spawnCenterY
    local distanceToSpawnArea = math.sqrt(dx * dx + dy * dy)
    
    -- Allow spawning if player is within 50 tiles of spawn area center
    if distanceToSpawnArea > 50 then
        print("SOUL QUEST SYSTEM - Error: Player too far from spawn area (" .. math.floor(distanceToSpawnArea) .. " tiles)")
        return
    end
    
    -- Verify Z level matches
    if playerZ ~= args.spawnZ then
        print("SOUL QUEST SYSTEM - Error: Player Z level mismatch")
        return
    end
    
    -- Update player coordinates in spawn data (in case they moved slightly)
    args.playerX = playerX
    args.playerY = playerY
    
	print("SOUL QUEST SYSTEM - SERVER SPAWN REQUEST: Received spawn request for quest " .. args.questGuid .. " from player " .. player:getUsername())
    -- Execute the spawn
    SFQuest_ZoneSpawner.spawnZombiesForQuest(player, args)
end

-- Clean up any remaining zombies for a quest (if needed)
function SFQuest_ZoneSpawner.cleanupQuestZombies(questGuid)
    -- This function could be used to clean up zombies if a quest is abandoned
    -- For now, we'll let zombies remain in the world naturally
    print("SOUL QUEST SYSTEM - Cleanup requested for quest: " .. questGuid)
end

print("SOUL QUEST SYSTEM - Zone Spawner loaded")

return SFQuest_ZoneSpawner