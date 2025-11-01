require 'SFQuest_WeaponKillUI'

SFQuest_WorldEventWindow = ISCollapsableWindow:derive("SFQuest_WorldEventWindow")
SFQuest_WorldEventWindow.tooltip = nil;

function SFQuest_WorldEventWindow:initialise()
	ISCollapsableWindow.initialise(self);
end

function SFQuest_WorldEventWindow:createChildren()
	ISCollapsableWindow.createChildren(self)
	
	-- Always use original dialogue mode
	self:createOriginalDialogueUI()
end

function SFQuest_WorldEventWindow:createOriginalDialogueUI()
	-- Check if this dialogue has multiple choices
	if self.dialogueinfo and self.dialogueinfo.choices then
		self:createMultipleChoiceUI()
		return
	end
	
	-- This is the original single quest dialogue interface
	local contentHeight = self:calculateOriginalContentHeight()
	local newHeight = math.max(240, contentHeight + 60)
	self:setHeight(newHeight)
	
	self.richText = MapSpawnSelectInfoPanel:new(44, 10, 340, 135);
	self.richText.autosetheight = false;
	self.richText.clip = true
	self.richText:initialise();
	self.richText.background = false;
	self.richText:setAnchorTop(true);
	self.richText:setAnchorLeft(true);
	self.richText:setVisible(false);
	self.richText.backgroundColor  = {r=0, g=0, b=0, a=0.5};
	self.richText.text = getText(self.dialogueinfo.text) or "...";
	self:addChild(self.richText);
	self.richText:addScrollBars()
	
	local btnHeight = self.height - 55;
    self.CloseBtn = ISButton:new(12, btnHeight, 100, 20, getText("IGUI_CraftUI_Close"), self, function(self, button) self:close() end);
    self.CloseBtn.internal = "CLOSE";
    self.CloseBtn:initialise();
    self.CloseBtn:instantiate();
    self.CloseBtn.borderColor = self.buttonBorderColor;
	self.CloseBtn:setVisible(false);
    self:addChild(self.CloseBtn);		
	
	if self.dialogueinfo.optional then
		self.DeclineBtn = ISButton:new(12, btnHeight, 100, 20, getText("IGUI_Decline"), self, SFQuest_WorldEventWindow.onOptionMouseDown);
		self.DeclineBtn.internal = "DECLINE";
		self.DeclineBtn:initialise();
		self.DeclineBtn:instantiate();
		self.DeclineBtn.borderColor = self.buttonBorderColor;
		self:addChild(self.DeclineBtn);	
		btnHeight = btnHeight - 24;
	end
	
	if self.command and self.command == "unlockquest" then
		self.AcceptBtn = ISButton:new(12, btnHeight, 100, 20, getText("IGUI_TradingUI_AcceptDeal"), self, SFQuest_WorldEventWindow.onOptionMouseDown);
		self.AcceptBtn.internal = "ACCEPT";
		self.AcceptBtn:initialise();
		self.AcceptBtn:instantiate();
		self.AcceptBtn.borderColor = self.buttonBorderColor;
		self:addChild(self.AcceptBtn);	
	end
	
	-- UPDATED QUEST COMPLETION LOGIC WITH NEEDSITEM2 SUPPORT
	if self.command and self.command == "completequest" then
		self.CloseBtn:setVisible(true);
		local neededStuffTaken = true;
		
		-- Handle regular needsitem (removes items)
		if self.quest.needsitem then
			neededStuffTaken = SF_MissionPanel.instance:takeNeededItem(self.quest.needsitem);
		end

		if self.quest.consumeobjectives and self.quest.objectives then
			for i = 1, #self.quest.objectives do
				local objective = self.quest.objectives[i];
				if objective.needsitem then
					local objItemsRemoved = SF_MissionPanel.instance:takeNeededItem(objective.needsitem);
					if not objItemsRemoved then
						neededStuffTaken = false;
					end
				end
				if objective.needsitem2 then
					local hasItems = SF_MissionPanel.instance:checkItemQuantity2(objective.needsitem2);
					if not hasItems then
						neededStuffTaken = false;
					end
				end
			end
		end
		
		-- Handle needsitem2 (checks but doesn't remove items)
		if self.quest.needsitem2 then
			local hasItems = SF_MissionPanel.instance:checkItemQuantity2(self.quest.needsitem2);
			if not hasItems then
				neededStuffTaken = false;
			end
		end
		
		if neededStuffTaken then
			SF_MissionPanel.instance:removeWorldEvent(self.worldinfo.square);
			SF_MissionPanel.instance:completeQuest(self.character, self.questid);
		end
	elseif self.command and self.command == "updateobjectivestatus" then
		self.CloseBtn:setVisible(true);
		local index = tonumber(self.commandparam2); 
		local neededStuffTaken = true;
		
		if self.quest.objectives and self.quest.objectives[index] then
			-- Handle regular needsitem (removes items)
			if self.quest.objectives[index].needsitem then
				neededStuffTaken = SF_MissionPanel.instance:takeNeededItem(self.quest.objectives[index].needsitem);
			end
			
			-- Handle needsitem2 (checks but doesn't remove items)
			if self.quest.objectives[index].needsitem2 then
				local hasItems = SF_MissionPanel.instance:checkItemQuantity2(self.quest.objectives[index].needsitem2);
				if not hasItems then
					neededStuffTaken = false;
				end
			end
		end
		
		if neededStuffTaken then
			SF_MissionPanel.instance:removeWorldEvent(self.worldinfo.square);
			SF_MissionPanel:updateObjective(self.questid, index, self.commandparam3);
		end		
	end
	
	if self.questid and self.dialogueinfo.lore then
		SF_MissionPanel.instance:updateLore(self.questid, self.dialogueinfo.lore);
	end
end

function SFQuest_WorldEventWindow:createMultipleChoiceUI()
	local choices = self.dialogueinfo.choices
	if not choices or #choices == 0 then
		-- Fallback to original UI if no choices
		print("SOUL QUEST SYSTEM - No choices found, falling back to original dialogue UI")
		self.dialogueinfo.choices = nil -- Clear invalid choices
		self:createOriginalDialogueUI()
		return
	end
	
	-- Calculate window height based on number of choices
	local baseHeight = 180
	local choiceHeight = #choices * 30 -- 30 pixels per choice button
	local contentHeight = baseHeight + choiceHeight
	local newHeight = math.max(250, contentHeight + 40)
	self:setHeight(newHeight)
	
	-- Create rich text panel for dialogue
	self.richText = MapSpawnSelectInfoPanel:new(44, 10, 340, 120);
	self.richText.autosetheight = false;
	self.richText.clip = true
	self.richText:initialise();
	self.richText.background = false;
	self.richText:setAnchorTop(true);
	self.richText:setAnchorLeft(true);
	self.richText:setVisible(false);
	self.richText.backgroundColor = {r=0, g=0, b=0, a=0.5};
	self.richText.text = getText(self.dialogueinfo.text) or "...";
	self:addChild(self.richText);
	self.richText:addScrollBars()
	
	-- Create choice buttons
	self.choiceButtons = {}
	local startY = 175
	local buttonWidth = 180
	local buttonHeight = 25
	local buttonSpacing = 5
	
	for i = 1, #choices do
		local choice = choices[i]
		local buttonY = startY + ((i - 1) * (buttonHeight + buttonSpacing))
		
		local choiceButton = ISButton:new(44, buttonY, buttonWidth, buttonHeight, getText(choice.text) or choice.text, self, SFQuest_WorldEventWindow.onChoiceMouseDown)
		choiceButton.internal = "CHOICE_" .. i
		choiceButton.choiceIndex = i
		choiceButton.choiceData = choice
		choiceButton:initialise()
		choiceButton:instantiate()
		choiceButton.borderColor = self.buttonBorderColor
		self:addChild(choiceButton)
		
		table.insert(self.choiceButtons, choiceButton)
	end
	
	-- Add close button at the bottom
	local closeButtonY = startY + (#choices * (buttonHeight + buttonSpacing)) + 10
	self.CloseBtn = ISButton:new(44, closeButtonY, 100, 20, getText("IGUI_CraftUI_Close"), self, function(self, button) self:close() end)
	self.CloseBtn.internal = "CLOSE"
	self.CloseBtn:initialise()
	self.CloseBtn:instantiate()
	self.CloseBtn.borderColor = self.buttonBorderColor
	self:addChild(self.CloseBtn)
	
	print("SOUL QUEST SYSTEM - Created multiple choice UI with " .. #choices .. " choices")
end

function SFQuest_WorldEventWindow:onChoiceMouseDown(button, x, y)
	if not button.choiceData then return end
	
	local choice = button.choiceData
	
	-- Execute command if present
	if choice.command and choice.command ~= "" then
		local commandTable = luautils.split(choice.command, ";")
		SF_MissionPanel.instance:readCommandTable(commandTable)
		
		-- Only close for completion commands
		if choice.command:find("completequest") then
			self:close()
			return
		end
	end
	
	-- Handle dialogue chaining
	if choice.nextdialogue and choice.nextdialogue ~= "" then
		local newDialogue = SF_MissionPanel.instance:getDialogueInfo(choice.nextdialogue)
		if newDialogue then
			self.dialogueinfo = newDialogue
			self:removeChild(self.richText)
			if self.choiceButtons then
				for i = 1, #self.choiceButtons do
					self:removeChild(self.choiceButtons[i])
				end
			end
			self:removeChild(self.CloseBtn)
			self:createMultipleChoiceUI()
		end
	else
		self:close()
	end
end

function SFQuest_WorldEventWindow:parseStartingItems(unlocks)
	local items = {}
	if not unlocks then return items end
	
	local commandTable = luautils.split(unlocks, ";")
	local count = 1
	
	while commandTable[count] do
		if commandTable[count] == "additem" then
			local itemType = commandTable[count + 1]
			local quantity = tonumber(commandTable[count + 2]) or 1
			table.insert(items, {type = itemType, quantity = quantity})
			count = count + 3
		else
			count = count + 1
		end
	end
	
	return items
end

function SFQuest_WorldEventWindow:render()
	-- Original dialogue mode - render NPC picture and rewards
	local picWidth = 140;
	if self.worldinfo.picture then
		local texture = getTexture(self.worldinfo.picture);
		self:drawTexture(texture, 12, 28, 1, 1, 1, 1);
		self:drawRectBorder(12, 28, texture:getWidth(), texture:getHeight(), 0.5, 1, 1, 1);
		picWidth = texture:getWidth();
	end

	self.richText:setX(12 + picWidth)
	self.richText:setY(16)
	self.richText:setVisible(true);
	self.richText:paginate();
	
	local textX = 12 + picWidth + 36;
	local startY = 160;
	local currentY = startY;
	
	-- Draw weapon kill requirements if this is a weapon kill quest
	if self.quest and self.quest.killtracking then
		if SFQuest_WeaponKillUI and SFQuest_WeaponKillUI.getWeaponRequirementText then
			local requirementText = SFQuest_WeaponKillUI.getWeaponRequirementText(self.quest)
			if requirementText and requirementText ~= "" then
				self:drawText("Quest Requirement:", 12 + picWidth + 24, currentY, 1.0, 0.8, 1.0, 1, self.font);
				currentY = currentY + 22;
				self:drawText(requirementText, 12 + picWidth + 24, currentY, 0.8, 0.8, 1.0, 1, self.font);
				currentY = currentY + 32;
			end
		end
		
		-- Show current progress if this is a completion dialogue
		if self.command == "completequest" and SFQuest_WeaponKillUI and SFQuest_WeaponKillUI.getKillProgressText then
			local progressText = SFQuest_WeaponKillUI.getKillProgressText(self.quest, self.character)
			if progressText and progressText ~= "" then
				self:drawText("Current Progress" .. progressText, 12 + picWidth + 24, currentY, 0.2, 1.0, 0.2, 1, self.font);
				currentY = currentY + 32;
			end
		end
	end
	
	-- Draw starting items and rewards (original logic)
	if self.quest and self.quest.unlocks and self.command == "unlockquest" then
		local startingItems = self:parseStartingItems(self.quest.unlocks)
		if #startingItems > 0 then
			self:drawText("Starting Items:", 12 + picWidth + 24, currentY, 0.2, 0.8, 0.2, 1, self.font);
			currentY = currentY + 22;
			
			for _, item in ipairs(startingItems) do
				local scriptItem = getScriptManager():FindItem(item.type);
				if scriptItem then
					local itemName = scriptItem:getDisplayName();
					local icon = getTexture("Item_" .. scriptItem:getIcon());
					local itemStr = itemName;
					if item.quantity > 1 then
						itemStr = itemName .. "  X " .. item.quantity;
					end
					-- Draw item icon with visual enhancement
					self:drawRect(textX - 2, currentY - 2, 24, 24, 0.3, 0.2, 0.8, 0.2); -- Background highlight
					self:drawRectBorder(textX - 2, currentY - 2, 24, 24, 1.0, 0.2, 0.8, 0.2); -- Green border
					self:drawTextureScaledAspect(icon, textX, currentY, 20, 20, 1, 1, 1, 1);
					self:drawText(itemStr, textX + 22, currentY + 2, 0.2, 0.8, 0.2, 1, self.font);
					currentY = currentY + 22; -- Keep original spacing
				end
			end
		end
	end
	
	-- Draw quest rewards (MODIFIED TO SUPPORT HIDDEN ITEMS)
	if self.quest and (self.quest.awardsrep or self.quest.awardsitem) and not (self.command == "updateobjectivestatus") then
		if self.quest.unlocks then currentY = currentY + 10; end
		self:drawText("Quest Rewards:", 12 + picWidth + 24, currentY, 1.0, 0.8, 0.2, 1, self.font);
		currentY = currentY + 22;
		
		if self.quest.awardsitem then
			local count = 1;
			local rewardTable = luautils.split(self.quest.awardsitem, ";");
			while rewardTable[count] do
				local itemType = rewardTable[count];
				
				-- Skip hidden items (items starting with "Hidden:")
				if not luautils.stringStarts(itemType, "Hidden:") then
					local scriptItem = getScriptManager():FindItem(itemType);
					if scriptItem then
						local itemName = scriptItem:getDisplayName();
						local iconName = scriptItem:getIcon();
						local icon = nil;
						
						-- Try to get the texture, with fallback
						if iconName then
							icon = getTexture("Item_" .. iconName);
						end
						
						-- Only draw if we have valid data
						if itemName and icon then
							local rewardStr = itemName;
							if rewardTable[count + 1] and rewardTable[count + 1] ~= "1" then
								rewardStr = itemName .. "  X " .. rewardTable[count + 1];
							end
							self:drawTextureScaledAspect(icon, textX, currentY, 20, 20, 1, 1, 1, 1);		
							self:drawText(rewardStr, textX + 22, currentY + 2, 1.0, 0.8, 0.2, 1, self.font);
							currentY = currentY + 22;
						else
							-- Fallback for items without icons
							if itemName then
								local rewardStr = itemName;
								if rewardTable[count + 1] and rewardTable[count + 1] ~= "1" then
									rewardStr = itemName .. "  X " .. rewardTable[count + 1];
								end
								self:drawText(rewardStr, textX + 22, currentY + 2, 1.0, 0.8, 0.2, 1, self.font);
								currentY = currentY + 22;
							end
						end
					end
				end
				count = count + 2;
			end
		end
	end
end

function SFQuest_WorldEventWindow:calculateOriginalContentHeight()
	local baseHeight = 160
	local itemHeight = 0
	
	-- Calculate starting items height
	if self.quest and self.quest.unlocks and self.command == "unlockquest" then
		local startingItems = self:parseStartingItems(self.quest.unlocks)
		if #startingItems > 0 then
			itemHeight = itemHeight + 25 + (#startingItems * 22)
		end
	end
	
	-- Calculate rewards height
	local rewardCount = 0
	if self.quest and self.quest.awardsrep and not (self.command == "updateobjectivestatus") then
		rewardCount = rewardCount + 1
	end
	if self.quest and self.quest.awardsitem and not (self.command == "updateobjectivestatus") then
		local rewardTable = luautils.split(self.quest.awardsitem, ";");
		local itemCount = math.ceil(#rewardTable / 2)
		rewardCount = rewardCount + itemCount
	end
	
	if rewardCount > 0 then
		itemHeight = itemHeight + 25 + (rewardCount * 22)
	end
	
	return baseHeight + itemHeight
end

function SFQuest_WorldEventWindow:onOptionMouseDown(button, x, y)
    if button.internal == "ACCEPT" then
		self.richText.text = getText(self.dialogueinfo.textaccepted) or "...";
		self.AcceptBtn:setVisible(false);
		self.CloseBtn:setVisible(true);
		if self.DeclineBtn then
			self.DeclineBtn:setVisible(false);
		end
		if self.overrideRewardItem then
			SF_MissionPanel.instance:unlockQuest(self.questid, self.overrideRewardItem);
		else
			SF_MissionPanel.instance:unlockQuest(self.questid);	
		end
		SF_MissionPanel.instance:removeWorldEvent(self.worldinfo.square);
    end
    if button.internal == "DECLINE" then
		self.richText.text = getText(self.dialogueinfo.textdeclined) or "...";
		self.DeclineBtn:setVisible(false);
		self.AcceptBtn:setVisible(false);
		self.CloseBtn:setVisible(true);
    end
end

function SFQuest_WorldEventWindow:update()
	ISCollapsableWindow.update(self)
end

function SFQuest_WorldEventWindow:onJoypadDown(button)
	if button == Joypad.BButton then
		self:removeFromUIManager()
		setJoypadFocus(self.playerNum, nil)
	end
end

function SFQuest_WorldEventWindow:onGainJoypadFocus(joypadData)
	self.drawJoypadFocus = true
end

function SFQuest_WorldEventWindow:close()
	self:removeFromUIManager()
end

function SFQuest_WorldEventWindow:new(x, y, character, square, worldinfo, dialogueinfo, questid)
	local width = 500
	local height = 300
	local o = ISCollapsableWindow:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.height = height;
	o.character = character
	o.playerNum = character:getPlayerNum()
	o.clearStentil = false;
	o.square = square
	o.worldinfo = worldinfo;
	o.dialogueinfo = dialogueinfo;
	
	-- Store world identity and square coordinates for dialogue chaining
	if worldinfo then
		o.worldIdentity = worldinfo.identity
		o.squareCoords = worldinfo.square
	end
	
	if dialogueinfo then
		-- Only process command if it exists (multiple choice dialogues may not have commands)
		if dialogueinfo.command then
			local commandTable = luautils.split(dialogueinfo.command, ";");
			o.command = commandTable[1];
			o.commandparam = commandTable[2];
			o.commandparam2 = commandTable[3];
			o.commandparam3 = commandTable[4];
			o.questid = commandTable[2] or questid;
			
			-- Get quest data for original dialogue mode
			if o.command == "completequest" or o.command == "updateobjectivestatus" then
				o.quest = SF_MissionPanel.instance:getActiveQuest(o.questid);
			elseif o.command == "unlockquest" then
				o.quest = SF_MissionPanel.instance:getQuest(o.questid);	
			end
			
			-- Handle random reward items
			o.overrideRewardItem = nil;
			if o.quest and o.quest.awardsitem and luautils.stringStarts(o.quest.awardsitem, "Table:") then
				local tableKey = luautils.split(o.quest.awardsitem, ":")[2];
				local randomTable = SFQuest_Database.RandomRewardItemPool[tableKey];
					if randomTable and #randomTable > 0 then
						o.overrideRewardItem = randomTable[ZombRand(1, #randomTable + 1)];
					end
			end
		else
			-- Multiple choice dialogue with no command
			o.command = nil;
			o.questid = questid;
		end
	end
	o.title = getText(worldinfo.name);
	o.buttonBorderColor = {r=0.7, g=0.7, b=0.7, a=0.5};
	o:setResizable(false)
	o.deal = "open";
	o.fontHeight = getTextManager():getFontHeight(self.font)
	SFQuest_WorldEventWindow.instance = o;
	return o
end