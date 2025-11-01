SFQuest_DeliveryMenu = function(player, context, worldobjects, test)
	local playerObj = getSpecificPlayer(player)
	if test then return ISWorldObjectContextMenu.setTest() end
	if not playerObj:getModData().missionProgress.ClickEvent then return end
	
	local square;
	for i,v in ipairs(worldobjects) do
		square = v:getSquare();
		break;
	end
	local x,y,z = tostring(square:getX()), tostring(square:getY()), tostring(square:getZ());
	local sqTag = x .. "x" .. y .. "x" .. z;
	
	-- Check for click events at this location
	if playerObj:getModData().missionProgress.ClickEvent then
		local clickEvents = playerObj:getModData().missionProgress.ClickEvent;
		for c=1,#clickEvents do
			local event = clickEvents[c];
			if event.square == sqTag then
				-- Found a click event for this location
				local deliveryOption = context:addOption(getText("ContextMenu_HideItem"), worldobjects, nil);
				local subMenu = ISContextMenu:getNew(context);
				context:addSubMenu(deliveryOption, subMenu);
				
				-- Check what quest this click event is for
				local commandTable = luautils.split(event.commands, ";");
				local questGuid = nil;
				
				-- Parse commands to find the quest GUID
				for cmd=1,#commandTable do
					if commandTable[cmd] == "completequest" and commandTable[cmd + 1] then
						questGuid = commandTable[cmd + 1];
						break;
					end
				end
				
				if questGuid then
					local task = SF_MissionPanel.instance:getActiveQuest(questGuid);
					if task then
						-- Check what items this quest originally required
						local itemsToCheck = {};
						
						-- For multi-stage quests, we need to check previous stages
						-- Look for the base quest's original needsitem
						local baseQuest = SF_MissionPanel.instance:getQuest(questGuid);
						if baseQuest and baseQuest.needsitem and baseQuest.needsitem ~= "" then
							table.insert(itemsToCheck, {
								needsitem = baseQuest.needsitem,
								name = "Required Items"
							});
						end
						
						-- Also check current task needsitem if it exists
						if task.needsitem and task.needsitem ~= "" then
							table.insert(itemsToCheck, {
								needsitem = task.needsitem,
								name = "Current Items"
							});
						end
						
						-- Add menu options for each item type
						for i=1,#itemsToCheck do
							local itemCheck = itemsToCheck[i];
							local itemName = itemCheck.name;
							
							-- Try to get a better display name
							local needsTable = luautils.split(itemCheck.needsitem, ";");
							local itemscript = needsTable[1];
							local quantity = tonumber(needsTable[2]) or 1;
							
							if luautils.stringStarts(itemscript, "TagPredicateFreshFood#") then
								local tag = luautils.split(itemscript, "#")[2];
								itemName = tag .. " (" .. quantity .. ")";
							elseif luautils.stringStarts(itemscript, "Tag#") then
								local tag = luautils.split(itemscript, "#")[2];
								itemName = tag .. " (" .. quantity .. ")";
							elseif not luautils.stringStarts(itemscript, "Tag") then
								local scriptItem = getScriptManager():FindItem(itemscript);
								if scriptItem then
									itemName = scriptItem:getDisplayName();
									if quantity > 1 then
										itemName = itemName .. " (" .. quantity .. ")";
									end
								end
							end
							
							local suboption = subMenu:addOption(itemName, worldobjects, onDeliveryWithRemoval, playerObj, square, itemCheck.needsitem, questGuid, event);
							
							-- Check if player actually has the required items
							local hasItems = SF_MissionPanel.instance:checkItemQuantity(itemCheck.needsitem);
							if not hasItems then 
								suboption.notAvailable = true;
							end
						end
					end
				end
				break; -- Only handle the first matching click event
			end
		end
	end
end

-- Enhanced delivery function that removes items
onDeliveryWithRemoval = function(worldobjects, playerObj, square, needsitem, questGuid, clickEvent)
	if luautils.walkAdj(playerObj, square) then
		ISTimedActionQueue.add(SFQuestDeliverItemWithRemoval:new(playerObj, square, needsitem, questGuid, clickEvent));
	end
end

-- Enhanced timed action that actually removes items
SFQuestDeliverItemWithRemoval = ISBaseTimedAction:derive("SFQuestDeliverItemWithRemoval");

function SFQuestDeliverItemWithRemoval:isValid()
	return true;
end

function SFQuestDeliverItemWithRemoval:update()
	-- No update needed
end

function SFQuestDeliverItemWithRemoval:start()
	-- Start the action
end

function SFQuestDeliverItemWithRemoval:stop()
	-- Clean up if cancelled
end

function SFQuestDeliverItemWithRemoval:perform()
	-- Get the quest and check what items it needs
	local task = SF_MissionPanel.instance:getActiveQuest(self.questGuid);
	if not task then return end
	
	-- Check the original quest definition for required items
	local baseQuest = SF_MissionPanel.instance:getQuest(self.questGuid);
	local itemsToRemove = nil;
	
	-- Find what items we need to remove
	if baseQuest and baseQuest.needsitem and baseQuest.needsitem ~= "" then
		itemsToRemove = baseQuest.needsitem;
	end
	
	if itemsToRemove then
		-- Use the existing takeNeededItem function - it handles ALL item types
		local success = SF_MissionPanel.instance:takeNeededItem(itemsToRemove);
		
		if success then
			print("SOUL QUEST SYSTEM - Successfully removed required items: " .. itemsToRemove);
		else
			print("SOUL QUEST SYSTEM - Failed to remove items: " .. itemsToRemove);
			self.character:Say("I don't have the required items.");
			return; -- Don't complete quest if we couldn't remove items
		end
	end
	
	-- Execute the click event commands (complete quest, etc.)
	local commandTable = luautils.split(self.clickEvent.commands, ";");
	SF_MissionPanel.instance:readCommandTable(commandTable);
	
	-- Remove this click event from the player's list
	local player = self.character;
	if player:getModData().missionProgress.ClickEvent then
		local clickEvents = player:getModData().missionProgress.ClickEvent;
		for c=1,#clickEvents do
			if clickEvents[c] == self.clickEvent then
				table.remove(clickEvents, c);
				SF_MissionPanel.instance.needsBackup = true;
				break;
			end
		end
	end
end

function SFQuestDeliverItemWithRemoval:new(character, square, needsitem, questGuid, clickEvent)
	local o = {};
	setmetatable(o, self);
	self.__index = self;
	o.character = character;
	o.square = square;
	o.needsitem = needsitem;
	o.questGuid = questGuid;
	o.clickEvent = clickEvent;
	o.stopOnWalk = true;
	o.stopOnRun = true;
	o.maxTime = clickEvent.actiondata and tonumber(luautils.split(clickEvent.actiondata, ";")[2]) or 100;
	return o;
end

Events.OnFillWorldObjectContextMenu.Add(SFQuest_DeliveryMenu);