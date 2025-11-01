--[[


	Your file should be placed inside media/lua/client


]]--

require "SFQuest_ClickEventAction"

SFQuest_ClickEventMenu = function(player, context, worldobjects, test)

	local playerObj = getSpecificPlayer(player)
	if test then return ISWorldObjectContextMenu.setTest() end
	
	-- Early returns if no click events exist
	if not playerObj:getModData().missionProgress.ClickEvent and not playerObj:getModData().missionProgress.ClickEvent2 then return end
	
	local hasClickEvent = false;
	local hasClickEvent2 = false;
	
	-- Check if we have any click events (with null checks)
	if playerObj:getModData().missionProgress.ClickEvent and #playerObj:getModData().missionProgress.ClickEvent > 0 then
		hasClickEvent = true;
	end
	if playerObj:getModData().missionProgress.ClickEvent2 and #playerObj:getModData().missionProgress.ClickEvent2 > 0 then
		hasClickEvent2 = true;
	end
	
	if not hasClickEvent and not hasClickEvent2 then return end

	local square;
	
	for i,v in ipairs(worldobjects) do
		square = v:getSquare();
		break;
	end

	local x,y,z = tostring(square:getX()), tostring(square:getY()), tostring(square:getZ());
	local sqTag = x .. "x" .. y .. "x" .. z;
	
	-- Check for regular clickevent
	if hasClickEvent then
		for c=1,#playerObj:getModData().missionProgress.ClickEvent do
			local event = playerObj:getModData().missionProgress.ClickEvent[c];
			if event.square and event.square == sqTag then
				local clickOption = context:addOption(getText("ContextMenu_InvestigateCorpse"), worldobjects, onClickEvent, playerObj, square, event.address, event.actiondata, event.commands);			
			end
		end
	end
	
	-- Check for clickevent2
	if hasClickEvent2 then
		for c=1,#playerObj:getModData().missionProgress.ClickEvent2 do
			local event = playerObj:getModData().missionProgress.ClickEvent2[c];
			if event.square and event.square == sqTag then
				local clickOption2 = context:addOption(getText("ContextMenu_DeliverItems"), worldobjects, onClickEvent2, playerObj, square, event.address, event.actiondata, event.commands);			
			end
		end
	end
end

onClickEvent = function(worldobjects, playerObj, square, address, actiondata, commands)
	local dataTable = luautils.split(actiondata, ";");
	local count = 1;
	local time;
	local anim;
	local animvar1;
	local animvar2;
	local prop1;
	local prop2;
	while dataTable[count] do
		if dataTable[count] == "time" then
			time = dataTable[count + 1];
			count = count + 2;
		elseif dataTable[count] == "anim" then
			anim = dataTable[count + 1];
			count = count + 2;
		elseif dataTable[count] == "animvar" then
			animvar1 = dataTable[count + 1];
			animvar2 = dataTable[count + 2];
			count = count + 3;
		elseif dataTable[count] == "prop1" then
			prop1 = dataTable[count + 1];
			count = count + 2;
		elseif dataTable[count] == "prop2" then
			prop2 = dataTable[count + 1];
			count = count + 2;
		else
			print("SOUL QUEST SYSTEM - Unrecognized right click action data: " .. dataTable[count]);
			count = count + 100;
		end
	end
	if luautils.walkAdj(playerObj, square) then
		ISTimedActionQueue.add(SFQuest_ClickEventAction:new(playerObj, square, address, time, anim, prop1, prop2, commands, animvar1, animvar2));
	end
end

onClickEvent2 = function(worldobjects, playerObj, square, address, actiondata, commands)
	-- Find the active quest that owns this clickevent2 to get needsitem
	local sqTag = square:getX() .. "x" .. square:getY() .. "x" .. square:getZ();
	local needsitem = "";
	
	print("SOUL QUEST SYSTEM - ClickEvent2 triggered at: " .. sqTag);
	
	-- Check all active quests to find which one has this clickevent2
	if playerObj:getModData().missionProgress and playerObj:getModData().missionProgress.Category2 then
		local activeQuests = playerObj:getModData().missionProgress.Category2;
		print("SOUL QUEST SYSTEM - Found " .. #activeQuests .. " active quests");
		
		for i = 1, #activeQuests do
			local quest = activeQuests[i];
			print("SOUL QUEST SYSTEM - Checking quest: " .. (quest.guid or "unknown"));
			print("SOUL QUEST SYSTEM - Quest unlocks: " .. (quest.unlocks or "none"));
			print("SOUL QUEST SYSTEM - Quest needsitem: " .. (quest.needsitem or "none"));
			
			if quest.unlocks and quest.unlocks:find("clickevent2") and quest.unlocks:find(sqTag) then
				needsitem = quest.needsitem or "";
				print("SOUL QUEST SYSTEM - Found matching quest! Will remove: " .. needsitem);
				break;
			end
		end
	end
	
	print("SOUL QUEST SYSTEM - Final needsitem to remove: " .. needsitem);
	
	-- Check if player has required items before allowing action
	if needsitem and needsitem ~= "" then
		local hasItems = SF_MissionPanel.instance:checkItemQuantity(needsitem);
		if not hasItems then
			playerObj:Say("I don't have the required items for this.");
			return;
		end
		print("SOUL QUEST SYSTEM - Player has required items, proceeding with action");
	end
	
	local dataTable = luautils.split(actiondata, ";");
	local count = 1;
	local time;
	local anim;
	local animvar1;
	local animvar2;
	local prop1;
	local prop2;
	while dataTable[count] do
		if dataTable[count] == "time" then
			time = dataTable[count + 1];
			count = count + 2;
		elseif dataTable[count] == "anim" then
			anim = dataTable[count + 1];
			count = count + 2;
		elseif dataTable[count] == "animvar" then
			animvar1 = dataTable[count + 1];
			animvar2 = dataTable[count + 2];
			count = count + 3;
		elseif dataTable[count] == "prop1" then
			prop1 = dataTable[count + 1];
			count = count + 2;
		elseif dataTable[count] == "prop2" then
			prop2 = dataTable[count + 1];
			count = count + 2;
		else
			print("SOUL QUEST SYSTEM - Unrecognized right click action data: " .. dataTable[count]);
			count = count + 100;
		end
	end
	if luautils.walkAdj(playerObj, square) then
		ISTimedActionQueue.add(SFQuest_ClickEventAction:new(playerObj, square, address, time, anim, prop1, prop2, commands, animvar1, animvar2, true, needsitem));
	end
end

Events.OnFillWorldObjectContextMenu.Add(SFQuest_ClickEventMenu);