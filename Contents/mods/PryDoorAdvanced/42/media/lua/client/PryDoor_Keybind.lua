require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISEquipWeaponAction"
require "TimedActions/ISUnequipAction"
require "PZAPI/ModOptions"

--------------------------------------------------
-- MOD OPTIONS (KEYBIND)
--------------------------------------------------

local modOptions = PZAPI.ModOptions:create(
    "PryDoorAdvanced",
    "Pry Door Advanced"
)

modOptions:addKeyBind(
    "pryKey",
    "Hold to Pry Door",
    Keyboard.KEY_Z,
    "Hold this key near a locked door to pry it open"
)

local function getPryKey()
    local opt = modOptions:getOption("pryKey")
    return opt and opt:getValue() or Keyboard.KEY_Z
end

--------------------------------------------------
-- UTILS
--------------------------------------------------

local function notBroken(item)
    return not item and false or not item:isBroken()
end

local function isMetalDoor(door)
    return door:getSprite()
       and door:getSprite():getName()
       and door:getSprite():getName():contains("metal")
end

local function findNearbyLockedDoor(player)
    local sq = player:getSquare()
    if not sq then return nil end

    for dx=-1,1 do
        for dy=-1,1 do
            local s = getCell():getGridSquare(
                sq:getX()+dx,
                sq:getY()+dy,
                sq:getZ()
            )
            if s then
                for i=0,s:getObjects():size()-1 do
                    local obj = s:getObjects():get(i)
                    if instanceof(obj,"IsoDoor")
                       and obj:isLocked()
                       and not obj:isBarricaded()
                    then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

--------------------------------------------------
-- BEST TOOL SELECTION (SAME AS CONTEXT MENU)
--------------------------------------------------

local function getBestTool(player, door)
    local inv = player:getInventory()

    local axe = inv:getFirstTypeEvalRecurse("Base.Axe", notBroken)
    local crowbar = inv:getFirstTypeEvalRecurse("Base.Crowbar", notBroken)
    local screwdriver = inv:getFirstTypeEvalRecurse("Base.Screwdriver", notBroken)

    if isMetalDoor(door) then
        if crowbar then return "axe", crowbar end
        return nil
    end

    if axe then return "axe", axe end
    if crowbar then return "crowbar", crowbar end
    if screwdriver then return "screwdriver", screwdriver end

    return nil
end

--------------------------------------------------
-- KEY HOLD HANDLER
--------------------------------------------------

local holdTime = 0
local triggered = false
local HOLD_THRESHOLD = 35

local function onKeyKeepPressed(key)
    if key ~= getPryKey() then return end

    local player = getSpecificPlayer(0)
    if not player then return end
    if player:getVehicle() then return end
    if player:isPlayerMoving() then return end

    local door = findNearbyLockedDoor(player)
    if not door then
        holdTime = 0
        triggered = false
        return
    end

    local toolType, tool = getBestTool(player, door)
    if not tool then return end

    holdTime = holdTime + 1

    if holdTime < HOLD_THRESHOLD or triggered then return end
    triggered = true

    --------------------------------------------------
    -- EQUIP TOOL IF NEEDED
    --------------------------------------------------

    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    if primary ~= tool then
        if primary then
            ISTimedActionQueue.add(ISUnequipAction:new(player, primary, 40))
        end
        if secondary and secondary ~= primary then
            ISTimedActionQueue.add(ISUnequipAction:new(player, secondary, 40))
        end
        ISTimedActionQueue.add(
            ISEquipWeaponAction:new(player, tool, 40, false, true)
        )
    end

    --------------------------------------------------
    -- START ACTION
    --------------------------------------------------

    local actionClass =
        toolType=="axe" and PryDoorAxeAction or
        toolType=="crowbar" and PryDoorCrowbarAction or
        PryDoorScrewdriverAction

    ISTimedActionQueue.add(
        actionClass:new(player, door, tool)
    )
end

local function onKeyPressed(key)
    if key == getPryKey() then
        holdTime = 0
        triggered = false
    end
end

Events.OnKeyKeepPressed.Add(onKeyKeepPressed)
Events.OnKeyPressed.Add(onKeyPressed)
