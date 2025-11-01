--[[


	Your file should be placed inside media/lua/client/TimedActions


]]--

require "TimedActions/ISBaseTimedAction"

SFQuest_ClickEventAction = ISBaseTimedAction:derive("SFQuest_ClickEventAction");

function SFQuest_ClickEventAction:isValid()
	return true;
end

function SFQuest_ClickEventAction:waitToStart()
	self.character:facePosition(self.square:getX(), self.square:getY());
	return self.character:shouldBeTurning()
end

function SFQuest_ClickEventAction:update()
	self.character:facePosition(self.square:getX(), self.square:getY());
end

function SFQuest_ClickEventAction:start()
	if self.anim then
		self:setActionAnim(self.anim);
	end
	if self.animvar1 and self.animvar2 then
		self:setAnimVariable(self.animvar1, self.animvar2);
	end
	self:setOverrideHandModels(self.prop1, self.prop2);
end

function SFQuest_ClickEventAction:stop()
    ISBaseTimedAction.stop(self);
end

function SFQuest_ClickEventAction:perform()
	-- Remove items if this is a clickevent2 with item requirements
	if self.isClickEvent2 and self.needsitem and self.needsitem ~= "" then
		local itemsRemoved = SF_MissionPanel.instance:takeNeededItem(self.needsitem);
		if itemsRemoved then
			print("SOUL QUEST SYSTEM - Removed items: " .. self.needsitem);
		else
			print("SOUL QUEST SYSTEM - Failed to remove required items");
			-- Action fails if we can't remove items
			ISBaseTimedAction.perform(self);
			return;
		end
	end
	
	-- Execute the commands (complete quest, etc.)
	if self.commands then
		local commandTable = luautils.split(self.commands, ";");
		SF_MissionPanel.instance:readCommandTable(commandTable);
	end
	
	-- Remove the click event from player data
	if self.isClickEvent2 then
		if self.character:getModData().missionProgress.ClickEvent2 then
			for c=1,#self.character:getModData().missionProgress.ClickEvent2 do
				local event = self.character:getModData().missionProgress.ClickEvent2[c];
				if event.address and event.address == self.address then
					table.remove(self.character:getModData().missionProgress.ClickEvent2, c);
					SF_MissionPanel.instance.needsBackup = true;
					break;
				end
			end
		end
	else
		if self.character:getModData().missionProgress.ClickEvent then
			for c=1,#self.character:getModData().missionProgress.ClickEvent do
				local event = self.character:getModData().missionProgress.ClickEvent[c];
				if event.address and event.address == self.address then
					table.remove(self.character:getModData().missionProgress.ClickEvent, c);
					SF_MissionPanel.instance.needsBackup = true;
					break;
				end
			end
		end
	end

    -- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self);
end

function SFQuest_ClickEventAction:new(character, square, address, time, anim, prop1, prop2, commands, animvar1, animvar2, isClickEvent2, needsitem)
	local o = ISBaseTimedAction.new(self, character)
	o.character = character;
	o.square = square;
	o.address = address;
	o.stopOnWalk = true;
	o.stopOnRun = true;
	o.maxTime = time;
	o.anim = anim;
	o.animvar1 = animvar1;
	o.animvar2 = animvar2;
	o.prop1 = prop1;
	o.prop2 = prop2;
	o.commands = commands;
	o.isClickEvent2 = isClickEvent2 or false;
	o.needsitem = needsitem or "";
	return o;
end