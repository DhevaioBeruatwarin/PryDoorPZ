require "PryDoor/PryDoor_Config"

PryDoor = PryDoor or {}
PryDoor.Utils = {}

local Config = PryDoor.Config

function PryDoor.Utils.isLockedWorldObject(obj)
    if not obj then return false end
    if instanceof(obj, "IsoWindow") then
        return obj:isLocked() and not obj:IsOpen() and not obj:isSmashed()
    elseif instanceof(obj, "IsoDoor") then
        return (obj:isLocked() or obj:isLockedByKey()) and not obj:IsOpen()
    elseif instanceof(obj, "IsoThumpable") and obj:isDoor() then
        return (obj:isLocked() or obj:isLockedByKey()) and not obj:IsOpen()
    end
    return false
end

function PryDoor.Utils.getWorldCategory(obj)
    if instanceof(obj, "IsoWindow") then return "window" end
    if instanceof(obj, "IsoDoor") or (instanceof(obj,"IsoThumpable") and obj:isDoor()) then
        local sp = obj:getSprite()
        if sp and sp:getName() and sp:getName():lower():find("garage") then
            return "garage"
        end
        return "door"
    end
end

function PryDoor.Utils.canPlayerPry(player, category)
    if player:getPerkLevel(Perks.Strength) < (Config.MIN_STRENGTH[category] or 0) then
        return false, Config.MESSAGES.TOO_WEAK
    end
    if player:getStats():getFatigue() > 0.85 then
        return false, Config.MESSAGES.TOO_TIRED
    end
    return true
end

function PryDoor.Utils.calculateSuccessChance(player, tool, category)
    local chance = Config.DIFFICULTY[category] or 0.5
    if tool then
        chance = chance + (Config.TOOL_BONUS[tool:getFullType()] or 0)
    end
    return math.max(0.1, math.min(0.95, chance))
end

function PryDoor.Utils.makeNoise(player, category, success)
    local r = Config.NOISE_RADIUS[category] or 10
    if success then r = r * 0.6 end
    local sq = player:getSquare()
    addSound(player, sq:getX(), sq:getY(), sq:getZ(), r, r)
end

function PryDoor.Utils.applyFatigue(player, category)
    local stats = player:getStats()
    stats:setFatigue(math.min(1, stats:getFatigue() + (Config.FATIGUE_COST[category] or 0.05)))
end

function PryDoor.Utils.handleFailure(player)
    if ZombRand(100) < Config.FAIL_CHANCE.injury * 100 then
        player:Say(Config.MESSAGES.INJURED)
    else
        player:Say(Config.MESSAGES.FAILED)
    end
end

function PryDoor.Utils.findTool(player)
    local inv = player:getInventory()
    for _,t in ipairs(Config.TOOLS) do
        local item = inv:getFirstType(t)
        if item and not item:isBroken() then return item end
    end
end

return PryDoor.Utils