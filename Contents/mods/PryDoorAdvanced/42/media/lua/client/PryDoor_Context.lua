require "ISInventoryPaneContextMenu"

local function notBroken(item)
    return not item:isBroken()
end

local function isMetalDoor(door)
    return door:getSprite() and door:getSprite():getName():contains("metal")
end

local function getBestTool(inv, door)
    local axe = inv:getFirstTypeEvalRecurse("Base.Axe", notBroken)
    local crowbar = inv:getFirstTypeEvalRecurse("Base.Crowbar", notBroken)
    local screwdriver = inv:getFirstTypeEvalRecurse("Base.Screwdriver", notBroken)

    if isMetalDoor(door) then
        if crowbar then return "crowbar", crowbar end
        return nil
    end

    if axe then return "axe", axe end
    if crowbar then return "crowbar", crowbar end
    if screwdriver then return "screwdriver", screwdriver end

    return nil
end

local function onFillWorldObjectContextMenu(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return end

    local door
    for _,obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoDoor") and obj:isLocked() and not obj:isBarricaded() then
            door = obj
            break
        end
    end
    if not door then return end

    local toolType, tool = getBestTool(playerObj:getInventory(), door)
    if not toolType then return end

    context:addOption("Pry Open Door", door, function()
        local actionType =
            toolType == "axe" and "PryDoorAxeAction" or
            toolType == "crowbar" and "PryDoorCrowbarAction" or
            "PryDoorScrewdriverAction"

        ISTimedActionQueue.add(_G[actionType]:new(playerObj, door, tool))
    end)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
