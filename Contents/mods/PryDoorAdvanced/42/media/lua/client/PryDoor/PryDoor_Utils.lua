require "PryDoor/PryDoor_Config"

PryDoor = PryDoor or {}
PryDoor.Utils = {}

local Config = PryDoor.Config

-- ============================================
-- Object Validation
-- ============================================

function PryDoor.Utils.isLockedWorldObject(obj)
    if not obj then return false end
    if instanceof(obj,"IsoWindow") then
        return obj:isLocked() and not obj:IsOpen() and not obj:isSmashed()
    elseif instanceof(obj,"IsoDoor") then
        return (obj:isLocked() or obj:isLockedByKey()) and not obj:IsOpen()
    elseif instanceof(obj,"IsoThumpable") and obj:isDoor() then
        return (obj:isLocked() or obj:isLockedByKey()) and not obj:IsOpen()
    end
    return false
end

function PryDoor.Utils.getWorldCategory(obj)
    if instanceof(obj,"IsoWindow") then return "window" end
    if instanceof(obj,"IsoDoor") or (instanceof(obj,"IsoThumpable") and obj:isDoor()) then
        local sp = obj:getSprite()
        if sp and sp:getName() and sp:getName():lower():find("garage") then
            return "garage"
        end
        return "door"
    end
end

-- ============================================
-- Player Validation (Skills, Strength, Tools)
-- ============================================

function PryDoor.Utils.canPlayerPry(player, category, tool)
    if not player or not category then return false, Config.MESSAGES.TOO_UNSKILLED end

    -- Strength check
    local minStr = Config.MIN_STRENGTH[category] or 0
    if player:getPerkLevel(Perks.Strength) < minStr then
        return false, Config.MESSAGES.TOO_WEAK
    end

    -- Fatigue check
    if player:getStats():getFatigue() > 0.85 then
        return false, Config.MESSAGES.TOO_TIRED
    end

    -- Skill check
    if category == "vehicle" then
        if player:getPerkLevel(Perks.Mechanics) < Config.MIN_MECHANICS then
            return false, "I need more mechanics knowledge to pry this!"
        end
    else
        if player:getPerkLevel(Perks.Woodwork) < Config.MIN_WOODWORK then
            return false, "I need more carpentry knowledge to pry this!"
        end
    end

    -- Tool check: Obeng cannot pry garage or vehicle
    if tool then
        local type = tool:getFullType()
        if type == "Base.Screwdriver" then
            if category == "garage" or category == "vehicle" then
                return false, Config.MESSAGES.TOOL_INEFFECTIVE
            end
        end
    end

    return true, nil
end

-- ============================================
-- Success Calculation
-- ============================================

function PryDoor.Utils.calculateSuccessChance(player, tool, category)
    local chance = Config.DIFFICULTY[category] or 0.5

    if tool then
        chance = chance + (Config.TOOL_BONUS[tool:getFullType()] or 0)
    end

    -- Strength bonus: 2% per level above minimum
    local minStr = Config.MIN_STRENGTH[category] or 0
    local strBonus = math.max(0, (player:getPerkLevel(Perks.Strength) - minStr) * 0.02)
    chance = chance + strBonus

    -- Skill bonus
    if category == "vehicle" then
        chance = chance + (player:getPerkLevel(Perks.Mechanics) * 0.015)
    else
        chance = chance + (player:getPerkLevel(Perks.Woodwork) * 0.01)
    end

    return math.max(0.10, math.min(0.95, chance))
end

-- ============================================
-- Noise, Fatigue, Failure, Tool Functions
-- ============================================

function PryDoor.Utils.makeNoise(player, category, success)
    local radius = Config.NOISE_RADIUS[category] or 10
    if success then radius = radius * 0.6 end
    local sq = player:getSquare()
    addSound(player, sq:getX(), sq:getY(), sq:getZ(), radius, radius)
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
    return nil
end

return PryDoor.Utils
