require "TimedActions/ISInventoryTransferAction"

local vanilla = ISInventoryTransferAction.perform;
function ISInventoryTransferAction:perform()
    vanilla(self);
    SF_MissionPanel.instance:checkQuestForCompletionByType("item", nil, "Obtained");
end