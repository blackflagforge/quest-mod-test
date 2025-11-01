--NEW
require 'SFQuest_ZoneSpawner'

local Commands = {}

function Commands.saveData(player, args)
	local id = player:getUsername();

	--print("Parsing data table for ID " .. id);
	--Write the text file
	local filepath = "/Backup/SFQuest_" .. id .. ".txt";
	--print("File path is: " .. filepath);
	local filewriter = getFileWriter(filepath, true, false);
	SFQuest_Server.parseTable(args, filewriter, "temp");
	print("SOUL QUEST SYSTEM - Saved quest data for ID: " .. id);
end

function Commands.sendData(player, args)
	local id = args.id;
	print("SOUL QUEST SYSTEM - Server received a request for quest data. Player ID: " .. id);
	local filepath = "/Backup/SFQuest_" .. id .. ".txt";
	local filereader = getFileReader(filepath, false);
	if filereader then
		print("SOUL QUEST SYSTEM - Located backup file player " .. id);
		local temp = {};
		local line = filereader:readLine();
		while line ~= nil do
			table.insert(temp, line);
			line = filereader:readLine();
		end
		filereader:close();
		local newargs = { id = id , data = temp };
		print("SOUL QUEST SYSTEM - Requested quest data for player " .. id .. " sent.");
		sendServerCommand('SFQuest', "setProgress", newargs);
	end;
end

function Commands.spawnZombies(player, args)
	if not player or not args then
		print("SOUL QUEST SYSTEM - Error: Invalid spawn zombies request");
		return;
	end
	
	local id = player:getUsername();
	print("SOUL QUEST SYSTEM - Spawn request from player: " .. id);
	print("SOUL QUEST SYSTEM - Quest GUID: " .. (args.questGuid or "unknown"));
	
	-- Validate player is alive and online
	if not player:isAlive() then
		print("SOUL QUEST SYSTEM - Error: Player " .. id .. " is not alive");
		return;
	end
	
	-- Use the zone spawner to handle the request
	if SFQuest_ZoneSpawner then
		SFQuest_ZoneSpawner.handleSpawnRequest(player, args);
	else
		print("SOUL QUEST SYSTEM - Error: SFQuest_ZoneSpawner not available");
		
		-- Send failure notification to client
		local failData = {
			questGuid = args.questGuid or "unknown",
			error = "Server spawner not available"
		};
		sendServerCommand(player, 'SFQuest', 'spawnFailed', failData);
	end
end


Events.OnClientCommand.Add(function(module, command, player, args)
	if module == 'SFQuest' and Commands[command] then
		args = args or {}
		Commands[command](player, args)
	end
end)

