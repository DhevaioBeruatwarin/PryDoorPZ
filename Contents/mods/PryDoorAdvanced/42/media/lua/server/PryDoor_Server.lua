local function successChance(player, tool, door)
    local str = player:getPerkLevel(Perks.Strength)
    local base =
        tool=="axe" and 95 or
        tool=="crowbar" and 85 or
        70

    if door:getSprite():getName():contains("metal") then
        if tool=="axe" then base=60 end
        if tool=="screwdriver" then base=30 end
    end

    return math.min(100, base + (str*2))
end

local function onClientCommand(module, command, player, args)
    if module~="PryDoor" or command~="tryPry" then return end

    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    if not sq then return end

    local door
    for i=0,sq:getObjects():size()-1 do
        local obj = sq:getObjects():get(i)
        if instanceof(obj,"IsoDoor") then door=obj break end
    end
    if not door or not door:isLocked() then return end

    local roll = ZombRand(100)
    local chance = successChance(player, args.tool, door)

    if roll < chance then
        door:setLockedByKey(false)
        door:ToggleDoor(player)
        player:playSound("BreakDoor")
        player:getXp():AddXP(Perks.Strength, 6)
    else
        player:playSound("BreakBarricadeMetal")
    end
end

Events.OnClientCommand.Add(onClientCommand)
