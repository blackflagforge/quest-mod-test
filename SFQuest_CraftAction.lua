require "TimedActions/ISCraftAction"

local vanilla = ISCraftAction.perform;
function ISCraftAction:perform()
    vanilla(self);
    SF_MissionPanel.instance:checkQuestForCompletionByType("item", nil, "Obtained");
end