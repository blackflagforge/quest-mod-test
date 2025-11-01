--NEW

--[[
	This file handles player initialization and recovering quest data from the server.
	FIXED: Added ClickEvent2 table initialization for multi-stage quest system
]]--

SFQuest_PlayerHandler = {};

SFQuest_PlayerHandler.startingPlayerStats = {
	Category1 = {},
	label = "IGUI_XP_Quests",
	Category1Greyed = true,
	Category1Label = "IGUI_XP_Quests_QuestLog",
	Category2 = {},
	Category2Label = "IGUI_XP_Quests_ActiveQuests",
	ActionEvent = {},
	ClickEvent = {},
	ClickEvent2 = {}, 
	DailyEvent = {},
	Timers = {},
	Factions = {},
	Delivery = {},
	WorldEvent = {},
    QuestStages = {},	
	ZoneCombat = {},
};

function SFQuest_PlayerHandler.StartPlayer(int, player)
	local player = player;

	-- If there is a backup file for the player's account then we use that, if not start it from zero.
	if not player:getModData().missionProgress then
		player:getModData().missionProgress = SFQuest_PlayerHandler.startingPlayerStats;

		--inserting factions from Database here
		for k,v in pairs(SFQuest_Database.FactionPool) do
			local factionTable = {};
			factionTable.factioncode = v.factioncode;
			factionTable.name = v.name;
			factionTable.reputation = v.startrep;
			factionTable.repmax = v.tiers[1].minrep;
			factionTable.tierlevel = 1;
			factionTable.tiername = v.tiers[1].tiername;
			factionTable.tiercolor = v.tiers[1].barcolor;
			table.insert(player:getModData().missionProgress.Factions, factionTable);
		end

		for q,u in pairs(SFQuest_Database.StartingPool) do
			local hasCondition = true;
			if u.condition then
				local condition = luautils.split(u.condition, ";");
				if condition[1] == "profession" and player:getDescriptor() and player:getDescriptor():getProfession() ~= condition[2] then
					hasCondition = false;
				elseif condition[1] == "trait" and not player:HasTrait(condition[2]) then
					hasCondition = false;
				end
			end
			if hasCondition == true then
				if u.click then
					local commandTable = luautils.split(u.click, ";");
					SF_MissionPanel.instance:runCommand("clickevent",  commandTable[1], commandTable[2], commandTable[3]);
				end
				if u.daily then
					local daily = SF_MissionPanel.instance:getDailyEvent(u.daily);
					SF_MissionPanel.instance:runCommand("unlockdaily", daily);	
				end
				if u.quest then
					SF_MissionPanel.instance:unlockQuest(u.quest);
				end
				if u.timer then
					SF_MissionPanel.instance:runCommand("unlocktimer", u.timer);
				end
				if u.randomworldfrompool then
					local entry = luautils.split(u.randomworldfrompool, ";");
					SF_MissionPanel.instance:runCommand("randomcodedworldfrompool", entry[1], entry[2], entry[3]);				
				end
				if u.world then
					local entry = luautils.split(u.world, ";");
					SF_MissionPanel.instance:runCommand("unlockworldevent", entry[1], entry[2], entry[3]);
				end
			end
		end


		SF_MissionPanel.instance:triggerUpdate();		
		if isClient() then
			print("SOUL QUEST SYSTEM - Requesting backup quest data.");
			local id = player:getUsername();
			sendClientCommand(player, 'SFQuest', 'sendData', {id = id});
		else
			local id = player:getUsername();	
			local filepath = "/Backup/SFQuest_" .. id .. ".txt";
			local filereader = getFileReader(filepath, false);
			if not filereader then return nil end;
			local data = {};
			local temp = {}
			local line = filereader:readLine();
			while line ~= nil do
				assert(loadstring(line));
				line = filereader:readLine();
			end
			filereader:close();		
			player:getModData().missionProgress = temp;
			SF_MissionPanel.instance:triggerUpdate();			
		end
	end
end

function SFQuest_PlayerHandler.OnGameStart()
	SF_MissionPanel.instance:triggerUpdate();
	
	local player = getPlayer();
	if player:getModData().missionProgress and player:getModData().missionProgress.WorldEvent then
		for k2,v2 in pairs(player:getModData().missionProgress.WorldEvent) do
			local squareTable = luautils.split(k2, "x");
			local x, y, z = tonumber(squareTable[1]), tonumber(squareTable[2]), tonumber(squareTable[3]);
			local square = getCell():getGridSquare(x, y, z);
			if square then
				local marker = getIsoMarkers():addIsoMarker({}, {"media/textures/Test_Marker.png"}, square, 1, 1, 1, false, false);
				marker:setDoAlpha(false);
				marker:setAlphaMin(0.8);
				marker:setAlpha(1.0);
				v2.marker = marker;
			end
		end
	end
end

Events.OnCreatePlayer.Add(SFQuest_PlayerHandler.StartPlayer);
Events.OnGameStart.Add(SFQuest_PlayerHandler.OnGameStart);