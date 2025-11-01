function ISMoveableSpriteProps:canPickUpMoveableInternal( _character, _square, _object, _isMulti )
    local canPickUp = false;
    if self.isMoveable and instanceof(_square,"IsoGridSquare") then
        canPickUp = not _object and true or self:objectNoContainerOrEmpty( _object );
        if not _isMulti and canPickUp then
            canPickUp = _character:getInventory():hasRoomFor(_character, self.weight);
        end
        if canPickUp and self.isTable then
            canPickUp = not _square:Is("IsTableTop") and _object == self:getTopTable(_square);
        end
        self.yOffsetCursor = _object and _object:getRenderYOffset() or 0;

        if canPickUp and self.isWaterCollector then
            if _object and _object:hasWater() then
                canPickUp = false
            end
        end

        if canPickUp and CMetalDrumSystem.instance:isValidIsoObject(_object) and
                (_object:getModData().haveCharcoal or _object:getModData().haveLogs) then
            canPickUp = false
        end
        
        if canPickUp and self.type == "Window" then
            if _object and instanceof(_object,"IsoWindow") then
                canPickUp = _object:isDestroyed() or (not _object:IsOpen());        -- only allow pickup when destroyed or closed (destroyed will remove window no return item)
                if _object:isBarricaded() then
                    canPickUp = false
                end
            else
                canPickUp = false;
            end
        end

        if canPickUp and self.type == "WindowObject" then
            if _character:getSquare() and _character:getSquare():Is(IsoFlagType.exterior) then
                canPickUp = false;
            end
        end

	local x, y, z = _square:getX(), _square:getY(), _square:getZ();
	local squaretag = tostring(x) .. "x" .. tostring(y) .. "x" .. tostring(z);
        if self.isoType == "IsoMannequin" and SFQuest_Database.MannequinPool[squaretag] then
            canPickUp = false
        end

        if instanceof(_object, "IsoBarbecue") then
            canPickUp = not _object:isLit() and not _object:hasPropaneTank();
        end

        if instanceof(_object, "IsoFireplace") then
            canPickUp = not (_object:isLit() or _object:isSmouldering())
        end

        if canPickUp and _character and instanceof(_character,"IsoGameCharacter") then
            local hasSKill, _ = self:hasRequiredSkill( _character, "pickup" );
            local hasTool = not self.pickUpTool and true or self:hasTool( _character, "pickup" );
            canPickUp = hasSKill and hasTool;
        end
    end
    return canPickUp;
end