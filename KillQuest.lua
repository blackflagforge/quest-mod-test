-- Triggered Player Zombie Kill Tracker for Project Zomboid
-- Place this file in: ServerLua/
-- File name: TriggeredZombieTracker.lua

local TriggeredZombieTracker = {}

-- Tracking state
local trackedPlayers = {}  -- Players currently being tracked
local playerKillCounts = {}  -- Kill counts per player
local zombieAttackers = {}  -- Backup tracking table

-- Initialize the tracker
local function initTracker()
    print("Triggered Zombie Kill Tracker initialized")
end

-- Function to get weapon name
local function getWeaponName(weapon)
    if not weapon then
        return "Bare Hands"
    end
    
    if weapon.getDisplayName then
        return weapon:getDisplayName()
    elseif weapon.getName then
        return weapon:getName()
    elseif weapon.getType then
        return weapon:getType()
    else
        return "Unknown Weapon"
    end
end

-- Function to get player identifier
local function getPlayerID(player)
    if not player then return nil end
    
    if player.getUsername then
        return player:getUsername()
    elseif player.getDisplayName then
        return player:getDisplayName()
    else
        return tostring(player)
    end
end

-- Start tracking a specific player
function TriggeredZombieTracker.startTracking(player, questID)
    if not player then 
        print("Error: Cannot start tracking - invalid player")
        return false
    end
    
    local playerID = getPlayerID(player)
    if not playerID then
        print("Error: Cannot get player ID")
        return false
    end
    
    trackedPlayers[playerID] = {
        player = player,
        questID = questID or "default",
        startTime = os.time(),
        active = true
    }
    
    playerKillCounts[playerID] = {
        totalKills = 0,
        weaponKills = {},  -- weapon name -> count
        killDetails = {}   -- individual kill records
    }
    
    print("Started tracking zombie kills for player: " .. playerID)
    
    -- Notify player
    if player.Say then
        player:Say("Zombie kill tracking started!")
    end
    
    return true
end

-- Stop tracking a specific player
function TriggeredZombieTracker.stopTracking(player)
    if not player then return false end
    
    local playerID = getPlayerID(player)
    if not playerID or not trackedPlayers[playerID] then
        return false
    end
    
    trackedPlayers[playerID].active = false
    
    print("Stopped tracking zombie kills for player: " .. playerID)
    
    -- Notify player with final stats
    if player.Say then
        local stats = TriggeredZombieTracker.getPlayerStats(player)
        if stats then
            player:Say("Tracking stopped. Total kills: " .. stats.totalKills)
        end
    end
    
    return true
end

-- Get kill statistics for a player
function TriggeredZombieTracker.getPlayerStats(player)
    if not player then return nil end
    
    local playerID = getPlayerID(player)
    if not playerID or not playerKillCounts[playerID] then
        return nil
    end
    
    return playerKillCounts[playerID]
end

-- Check if player has reached kill target
function TriggeredZombieTracker.hasReachedTarget(player, targetKills)
    local stats = TriggeredZombieTracker.getPlayerStats(player)
    if not stats then return false end
    
    return stats.totalKills >= targetKills
end

-- Event handler for zombie death
local function onZombieDeath(zombie)
    if not zombie then return end
    
    -- Get killer information
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
    
    -- Fallback to our tracking table
    if not killer then
        local zombieID = zombie:getOnlineID()
        local attackerData = zombieAttackers[zombieID]
        if attackerData then
            killer = attackerData.attacker
            weapon = attackerData.weapon
        end
        zombieAttackers[zombieID] = nil
    end
    
    -- Only process if killer is a player
    if not killer or not instanceof(killer, "IsoPlayer") then
        return
    end
    
    local playerID = getPlayerID(killer)
    if not playerID then return end
    
    -- Check if this player is being tracked
    if not trackedPlayers[playerID] or not trackedPlayers[playerID].active then
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
    
    local weaponName = getWeaponName(weapon)
    
    -- Update kill counts
    local killData = playerKillCounts[playerID]
    killData.totalKills = killData.totalKills + 1
    
    -- Update weapon-specific counts
    if not killData.weaponKills[weaponName] then
        killData.weaponKills[weaponName] = 0
    end
    killData.weaponKills[weaponName] = killData.weaponKills[weaponName] + 1
    
    -- Store detailed kill record
    local killRecord = {
        timestamp = os.time(),
        weapon = weaponName,
        coords = {
            x = zombie:getX(),
            y = zombie:getY(),
            z = zombie:getZ()
        }
    }
    table.insert(killData.killDetails, killRecord)
    
    print(string.format("Player %s killed zombie #%d with %s", 
        playerID, killData.totalKills, weaponName))
    
    -- Notify player of milestone kills
    if killData.totalKills % 10 == 0 then
        killer:Say("Zombies killed: " .. killData.totalKills)
    end
end

-- Track weapon hits for backup
local function onWeaponHitCharacter(attacker, victim, weapon, damage)
    if not victim or not attacker or not instanceof(victim, "IsoZombie") then
        return
    end
    
    local playerID = getPlayerID(attacker)
    if not playerID or not trackedPlayers[playerID] or not trackedPlayers[playerID].active then
        return
    end
    
    local zombieID = victim:getOnlineID()
    zombieAttackers[zombieID] = {
        attacker = attacker,
        weapon = weapon
    }
end

-- Server commands for manual control
local function onServerCommand(module, command, player, args)
    if module ~= "ZombieTracker" then return end
    
    if command == "start" then
        local questID = args and args.questID
        TriggeredZombieTracker.startTracking(player, questID)
        
    elseif command == "stop" then
        TriggeredZombieTracker.stopTracking(player)
        
    elseif command == "stats" then
        local stats = TriggeredZombieTracker.getPlayerStats(player)
        if stats and player.Say then
            player:Say("Total kills: " .. stats.totalKills)
            
            -- Show top 3 weapons
            local weaponList = {}
            for weapon, count in pairs(stats.weaponKills) do
                table.insert(weaponList, {weapon = weapon, count = count})
            end
            
            table.sort(weaponList, function(a, b) return a.count > b.count end)
            
            for i = 1, math.min(3, #weaponList) do
                local entry = weaponList[i]
                player:Say(entry.weapon .. ": " .. entry.count .. " kills")
            end
        end
        
    elseif command == "check" then
        local targetKills = args and tonumber(args.target) or 10
        local hasReached = TriggeredZombieTracker.hasReachedTarget(player, targetKills)
        if player.Say then
            player:Say("Target reached: " .. tostring(hasReached))
        end
    end
end

-- Integration function for quest systems
function TriggeredZombieTracker.checkQuestProgress(player, questID, targetKills)
    local stats = TriggeredZombieTracker.getPlayerStats(player)
    if not stats then return 0 end
    
    return {
        current = stats.totalKills,
        target = targetKills,
        completed = stats.totalKills >= targetKills,
        weaponBreakdown = stats.weaponKills
    }
end

-- Event registration
Events.OnZombieDead.Add(onZombieDeath)
Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
Events.OnServerStarted.Add(initTracker)
Events.OnClientCommand.Add(onServerCommand)

-- Export the module
return TriggeredZombieTracker