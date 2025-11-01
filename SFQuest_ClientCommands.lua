--NEW

local Commands = {}

function Commands.setProgress(args)
	local player = getPlayer();
	local id = player:getUsername();
	if not id == args.id then
		return
	end
	
	print("SOUL QUEST SYSTEM - Backup data received from server, recovering quest progress.");
	print("SOUL QUEST SYSTEM - Player ID: " .. tostring(id));
	print("SOUL QUEST SYSTEM - Args ID: " .. tostring(args.id));
	print("SOUL QUEST SYSTEM - Data type: " .. type(args.data));
	print("SOUL QUEST SYSTEM - Data length: " .. (args.data and #args.data or "nil"));
	
	-- Debug: Print all received data
	if args.data then
		print("SOUL QUEST SYSTEM - Received data contents:");
		for i, line in ipairs(args.data) do
			print("Line " .. i .. ": " .. tostring(line));
		end
	else
		print("SOUL QUEST SYSTEM - No data received!");
		return;
	end
	
	-- Create temp table and make it available globally for the loadstring execution
	local temp = {};
	_G.temp = temp;  -- Make temp accessible to loadstring
	
	for a, b in ipairs(args.data) do
		print("SOUL QUEST SYSTEM - Processing line " .. a .. ": " .. tostring(b));
		
		-- Try to load and execute the string
		local func, err = loadstring(b);
		if func then
			print("SOUL QUEST SYSTEM - Successfully loaded string as function");
			local success, result = pcall(func);
			if success then
				print("SOUL QUEST SYSTEM - Successfully executed function");
			else
				print("SOUL QUEST SYSTEM - Failed to execute function: " .. tostring(result));
				print("SOUL QUEST SYSTEM - Problematic line was: " .. tostring(b));
				_G.temp = nil;  -- Clean up global
				return;
			end
		else
			print("SOUL QUEST SYSTEM - Failed to load string as function: " .. tostring(err));
			print("SOUL QUEST SYSTEM - Problematic line was: " .. tostring(b));
			_G.temp = nil;  -- Clean up global
			return;
		end
	end
	
	-- Clean up global reference
	_G.temp = nil;
	
	print("SOUL QUEST SYSTEM - Final temp table keys:");
	for key, value in pairs(temp) do
		print("  " .. tostring(key) .. " = " .. type(value));
	end
	
	if not temp.Delivery then
		print("SOUL QUEST SYSTEM - Data transformation likely to be corrupted, aborting backup.");
		print("SOUL QUEST SYSTEM - Missing Delivery table in restored data");
		return
	end
	
	print("SOUL QUEST SYSTEM - Successfully restored quest data, applying to player");
	player:getModData().missionProgress = temp;
	SF_MissionPanel.instance:triggerUpdate();
end

function Commands.zoneSpawned(args)
	local player = getPlayer();
	if not player then return end
	
	print("SOUL QUEST SYSTEM - Zone spawn confirmation received");
	print("SOUL QUEST SYSTEM - Quest GUID: " .. (args.questGuid or "unknown"));
	print("SOUL QUEST SYSTEM - Spawned: " .. (args.spawnedCount or 0) .. "/" .. (args.requestedCount or 0));
	
	-- Notify zone tracker that spawning completed
	if SFQuest_ZoneTracker then
		SFQuest_ZoneTracker.onZombiesSpawned(args.questGuid);
	end
	
	-- Show notification to player
	if args.spawnedCount and args.spawnedCount > 0 then
		player:Say("Zombies incoming! Defend yourself!");
	else
		player:Say("Something went wrong with the spawn...");
	end
end

function Commands.spawnFailed(args)
	local player = getPlayer();
	if not player then return end
	
	print("SOUL QUEST SYSTEM - Zone spawn failed");
	print("SOUL QUEST SYSTEM - Quest GUID: " .. (args.questGuid or "unknown"));
	print("SOUL QUEST SYSTEM - Error: " .. (args.error or "unknown"));
	
	-- Handle spawn failure
	if SFQuest_ZoneTracker and args.questGuid then
		SFQuest_ZoneTracker.failZoneQuest(args.questGuid);
	end
	
	-- Show error to player
	player:Say("Failed to spawn zombies. Quest failed.");
end


Events.OnServerCommand.Add(function(module, command, args)
	if not isClient() then return end
	if module == "SFQuest" and Commands[command] then
		print("SOUL QUEST SYSTEM - Received command: " .. tostring(command));
		args = args or {}
		Commands[command](args)  -- CORRECT: only pass args
	end
end)


Events.OnServerCommand.Add(onServerCommand)