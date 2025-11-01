function ISDestroyCursor:canDestroy(object)
	-- No destroying door-wall that has a door.
	if self:_isDoorWallN(object) or self:_isDoorWallW(object) then
		local isNorth = self:_isDoorWallN(object)
		local objects = object:getSquare():getObjects()
		for i=1,objects:size() do
			local object2 = objects:get(i-1)
			if isNorth and self:_isDoorN(object2) and object ~= object2 then return false end
			if (not isNorth) and self:_isDoorW(object2) and object ~= object2 then return false end
		end
	end
	if self.dismantle then
		return object and instanceof(object, "IsoThumpable") and object:isDismantable()
	end
	if not object or not object:getSquare() or not object:getSprite() then return false end
	if instanceof(object, "IsoWorldInventoryObject") then return false end
	if instanceof(object, "IsoTree") then return false end
	local square = object:getSquare()
	local props = object:getProperties()
	if not props then return false end

	-- No sledgehammering the traders!
	local x,y,z = square:getX(), square:getY(), square:getZ();
	local squaretag = tostring(x) .. "x" .. tostring(y) .. "x" .. tostring(z);
	if props:Is("CustomName") and props:Val("CustomName") == "Mannequin" and SFQuest_Database.MannequinPool[squaretag] then
		return false
	end
	-- No sledgehammering the daffodils.
	if props:Is(IsoFlagType.vegitation) then return false end

	-- Sheetropes
	if props:Is(IsoFlagType.climbSheetTopW) or props:Is(IsoFlagType.climbSheetTopE) or
			props:Is(IsoFlagType.climbSheetTopN) or props:Is(IsoFlagType.climbSheetTopS) or
			props:Is(IsoFlagType.climbSheetW) or props:Is(IsoFlagType.climbSheetE) or
			props:Is(IsoFlagType.climbSheetN) or props:Is(IsoFlagType.climbSheetS) then
		return false
	end

	-- No destroying the floor tile at the top of a staircase.
	-- The floor tile isn't visible when climbing the stairs.
	-- This is to stop mp griefers.
	if object:getZ() > 0 and self:isFloorAtTopOfStairs(object) then return false end

	local spriteName = object:getSprite():getName()
	if spriteName then
		-- advertising billboard base
		if spriteName == "advertising_01_14" then return false end
		-- 2-story street-light base tile
		if spriteName == "lighting_outdoor_01_16" then return false end
		if spriteName == "lighting_outdoor_01_17" then return false end
		-- Don't destroy water tiles.
		if luautils.stringStarts(spriteName, 'blends_natural_02') then return false end
		-- FIXME: these tiles should have 'vegitation' flag.
		if luautils.stringStarts(spriteName, 'blends_grassoverlays') then return false end
		if luautils.stringStarts(spriteName, 'd_') then return false end
		if luautils.stringStarts(spriteName, 'e_') then return false end
		if luautils.stringStarts(spriteName, 'f_') then return false end
		if luautils.stringStarts(spriteName, 'vegetation_') and not luautils.stringStarts(spriteName, 'vegetation_indoor') then return false end

		if luautils.stringStarts(spriteName, 'trash_01') then return false end
		if luautils.stringStarts(spriteName, 'street_curbs') then return false end
	end

	-- Destroy doors, walls and windows from the opposite square too
	if not square:isCouldSee(self.player) then
		if self:couldSeeOpposite(object, square) then return true end
		return false
	end

	if props:Is(IsoFlagType.solidfloor) then return object:getZ() > 0 end
	return true
end