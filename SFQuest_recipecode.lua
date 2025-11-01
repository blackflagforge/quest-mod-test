require 'recipecode'

function Recipe.OnCreate.QuestItem(items, result, player)
	local type = result:getType();
	print("This recipe updates quests that require a " .. type);
	--Update quests that require this item
	SF_MissionPanel.instance:checkQuestForCompletionByType("item", type, "Completed");
end
