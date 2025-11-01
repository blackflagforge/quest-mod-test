--[[

		Most of these functions were adapted from tchernobill's
		Kill Count mod with the author's permission.

]]--

require "ISUI/ISCollapsableWindow"
require "ISUI/ISLayoutManager"
require "XpSystem/ISUI/ISCharacterInfoWindow"

local previous_ISCharacterInfoWindow_createChildren = ISCharacterInfoWindow.createChildren
function ISCharacterInfoWindow:createChildren()
    previous_ISCharacterInfoWindow_createChildren(self)
	
	self.questView = SF_MissionPanel:new(getSpecificPlayer(self.playerNum), 0, 8, 420, 400)
	self.questView:initialise()
	self.questView.infoText = getTextOrNull("UI_ProtectionPanel");
	--local modData = getSpecificPlayer(self.playerNum):getModData();
	local textentry = getText("IGUI_XP_Quests");
	--if not modData[questProgress].label == nil then textentry = getText(modData[questProgress].label) end;
	local tabtitle = textentry;
	self.panel:addView(tabtitle, self.questView);
end

local previous_ISCharacterInfoWindow_onTabTornOff = ISCharacterInfoWindow.onTabTornOff
function ISCharacterInfoWindow:onTabTornOff(view, window)
    if self.playerNum == 0 and view == self.questView then
        ISLayoutManager.RegisterWindow('charinfowindow.quest', ISCollapsableWindow, window)
    end
    previous_ISCharacterInfoWindow_onTabTornOff(self, view, window)

end

local previous_ISCharacterInfoWindow_RestoreLayout = ISCharacterInfoWindow.RestoreLayout
function ISCharacterInfoWindow:RestoreLayout(name, layout)
    previous_ISCharacterInfoWindow_RestoreLayout(self,name,layout)

	local floatingQuest = true
	local floatingProtection = true
	if layout.tabs ~= nil then
		local tabs = string.split(layout.tabs, ',')
		for k,v in pairs(tabs) do
			if v == 'quest' then
				floatingQuest = false
			elseif v == 'protection' then
				floatingProtection = false
			end
		end
	else
		floatingQuest = false
		floatingProtection = false
	end
	--temporary fix for the protection tab as it is currently broken in the game
	if floatingProtection then
		self.panel:removeView(self.protectionView)
        local width = self.protectionView:getWidth()
        local height = self.protectionView:getHeight() + 30
		local newWindow = ISCollapsableWindow:new(0, 0, width, height);
		newWindow:initialise();
		newWindow:addToUIManager();
		newWindow:addView(self.protectionView);
		newWindow:setTitle(xpSystemText.protection);
		self:onTabTornOff(self.protectionView, newWindow)
	end
    if floatingQuest and self.questView then
        self.panel:removeView(self.questView)
        local width = self.questView:getWidth()
        local height = self.questView:getHeight() + 30
        local newWindow = ISCollapsableWindow:new(0, 0, width, height);
        newWindow:initialise();
        newWindow:addToUIManager();
        newWindow:addView(self.questView);
        newWindow:setTitle(xpSystemText.quest);
        self:onTabTornOff(self.questView, newWindow);
    end
end

local previous_ISCharacterInfoWindow_SaveLayout = ISCharacterInfoWindow.SaveLayout
function ISCharacterInfoWindow:SaveLayout(name, layout)
    previous_ISCharacterInfoWindow_SaveLayout(self,name,layout)
    
    if self.questView and self.questView.parent == self.panel and self.questView == self.panel:getActiveView() then
		layout.current = 'quest'
    end
    if not layout.tabs then
		layout.tabs = "quest"
	else
		layout.tabs = layout.tabs .. ",quest"
	end
end