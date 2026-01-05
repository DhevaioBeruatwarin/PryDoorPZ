
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISBaseTimedAction"
require "ISUI/ISWorldObjectContextMenu"
--dheva1o
local PRY_MOD = { VERSION = "3.8.0-BALANCED", DEBUG = true }

-- ============================================
-- TOOL DURABILITY CONFIG
-- ============================================
local TOOL_DURABILITY_LOSS = {
    screwdriver = { min = 5, max = 7 }, 
    wrench      = { min = 3, max = 6 },
    crowbar     = { min = 1, max = 3 }, 
}

local FAIL_MULTIPLIER = 1.5
local FALLBACK_DURABILITY_LOSS = 2 -- For unrecognized tools

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function isLockedWorldObject(obj)
    if instanceof(obj, "IsoWindow") then
        if obj:isPermaLocked() then return false end
        return obj:isLocked() and not obj:IsOpen() and not obj:isSmashed()
    elseif instanceof(obj, "IsoDoor") then
        return obj:isLocked() or obj:isLockedByKey()
    elseif instanceof(obj, "IsoThumpable") and obj:isDoor() then
        return obj:isLocked() or obj:isLockedByKey()
    end
    return false
end

local function getWorldCategory(obj)
    if instanceof(obj, "IsoWindow") then
        return "window"
    elseif instanceof(obj, "IsoDoor") then
        local sprite = obj:getSprite()
        if sprite and sprite:getName() then
            local spriteName = tostring(sprite:getName()):lower()
            if spriteName:find("garage") then
                return "garage"
            end
        end
        return "door"
    elseif instanceof(obj, "IsoThumpable") and obj:isDoor() then
        local sprite = obj:getSprite()
        if sprite and sprite:getName() then
            local spriteName = tostring(sprite:getName()):lower()
            if spriteName:find("garage") then
                return "garage"
            end
        end
        return "door"
    end
    return nil
end

-- ============================================
-- HELPER: display name getter (safe)
-- ============================================
local function getItemDisplayName(item)
    if not item then return "tool" end
    if item.getDisplayName then
        local ok, name = pcall(function() return item:getDisplayName() end)
        if ok and name and name ~= "" then return name end
    end
    if item.getName then
        local ok, name = pcall(function() return item:getName() end)
        if ok and name and name ~= "" then return name end
    end
    if item.getType then
        local ok, t = pcall(function() return item:getType() end)
        if ok and t and t ~= "" then return t end
    end
    return "tool"
end

-- ============================================
-- TOOL DURABILITY SYSTEM (CORE, NO MESSAGING)
-- - Returns boolean: true if tool broke (condition <= 0)
-- - Does not perform any client/server messaging. Caller handles notifications.
-- ============================================
local function applyToolDurabilityLoss(tool, failed)
    if not tool then return false end

    local ok, tname = pcall(function() return tool:getType() end)
    local t = (ok and tname) and tostring(tname):lower() or ""

    local loss = 0

    if t:find("screwdriver") then
        -- Screwdriver cepat rusak: instant break (use entire condition)
        local cur = 0
        local okc = pcall(function() cur = tool:getCondition() end)
        if not okc then cur = 0 end
        loss = math.max(1, cur) -- ensure at least 1
    elseif t:find("wrench") then
        -- Wrench cepat rusak juga, but not always instant: reduce by 70% of current (min 1)
        local cur = 0
        local okc = pcall(function() cur = tool:getCondition() end)
        if not okc then cur = 0 end
        loss = math.max(1, math.floor(cur * 0.7))
    elseif t:find("crowbar") then
        -- Crowbar stable: use configured random loss
        local cfg = TOOL_DURABILITY_LOSS.crowbar
        if cfg then
            loss = ZombRand(cfg.min, cfg.max + 1)
        else
            loss = FALLBACK_DURABILITY_LOSS
        end
    else
        -- Unknown/modded tool: use fallback
        loss = FALLBACK_DURABILITY_LOSS
    end

    if failed then
        loss = math.floor(loss * FAIL_MULTIPLIER)
        if loss < 1 then loss = 1 end
    end

    -- Apply damage using condition API (most common)
    local applied = false
    local broke = false
    do
        local okg = pcall(function() return tool:getCondition() end)
        if okg then
            local cur = tool:getCondition() or 0
            local newCond = math.max(0, cur - loss)
            local oks = pcall(function() tool:setCondition(newCond) end)
            applied = true
            if newCond <= 0 then broke = true end
        end
    end

    -- Fallback: used delta API (0..1)
    if (not applied) and tool.getUsedDelta and tool.setUsedDelta then
        local okud = pcall(function() return tool:getUsedDelta() end)
        if okud then
            local cur = tool:getUsedDelta() or 0
            local delta = loss / 100.0
            local newDelta = math.max(0, cur - delta)
            pcall(function() tool:setUsedDelta(newDelta) end)
            applied = true
            if newDelta <= 0 then broke = true end
        end
    end

    -- If nothing applied, try to call setCondition if exists with conservative value
    if (not applied) and tool.setCondition then
        pcall(function() tool:setCondition(math.max(0, (tool.getCondition and tool:getCondition() or 0) - loss)) end)
        if tool.getCondition and tool:getCondition() <= 0 then broke = true end
    end

    return broke
end

-- ============================================
-- MP-SAFE DAMAGE REQUEST
-- - If client: send server request to apply damage (server authoritative)
-- - If server (or singleplayer): apply directly and notify client if broken
-- ============================================
local function requestDamageTool(player, tool, failed)
    if not player or not tool then return end

    -- Prepare payload: try to include item ID for reliable lookup
    local payload = { failed = failed }

    local okid, id = pcall(function() return tool:getID() end)
    if okid and id then
        payload.itemID = id
    else
        -- Fallback: send item type so server can search for a matching item
        local okt, t = pcall(function() return tool:getType() end)
        if okt and t then payload.itemType = t end
    end

    -- If we're on client, ask server to apply damage
    if isClient() and sendServerCommand then
        -- sendServerCommand(character, module, command, args)
        pcall(sendServerCommand, player, "PryDoor", "DamageTool", payload)
        return
    end

    -- If we're on server (or singleplayer), apply immediately
    local broke = applyToolDurabilityLoss(tool, failed)
    if broke then
        -- Notify the player. If server, send client command to display message
        local name = getItemDisplayName(tool)
        if isServer() and sendClientCommand then
            pcall(sendClientCommand, player, "PryDoor", "ShowBroken", { name = name })
        else
            -- Singleplayer or server-side local: just say
            if player and player.Say then
                player:Say("Your " .. name .. " broke!")
            else
                print("Your " .. name .. " broke!")
            end
        end
    end
end

-- ============================================
-- OBJECT DETECTION
-- ============================================
local function findWorldTarget(player)
    local sq = player:getSquare()
    if not sq then return nil, nil end
    
    for dx = -1,1 do
        for dy = -1,1 do
            local checkSq = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if checkSq then
                local objs = checkSq:getObjects()
                for i = 0, objs:size()-1 do
                    local obj = objs:get(i)
                    if isLockedWorldObject(obj) then
                        local category = getWorldCategory(obj)
                        if category then
                            local barricaded = false
                            if obj.isBarricaded then
                                barricaded = obj:isBarricaded()
                            end
                            if not barricaded then
                                return obj, category
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function findVehicleTarget(player)
    local sq = player:getSquare()
    if not sq then return nil, nil end
    for dx = -1,1 do
        for dy = -1,1 do
            local checkSq = getCell():getGridSquare(sq:getX()+dx,sq:getY()+dy,sq:getZ())
            if checkSq then
                local vehicle = checkSq:getVehicleContainer()
                if vehicle then
                    local closestPart = nil
                    local closestDist = 999999
                    for i = 0, vehicle:getPartCount()-1 do
                        local part = vehicle:getPartByIndex(i)
                        if part and part:getDoor() then
                            local door = part:getDoor()
                            if door and door:isLocked() then
                                local area = vehicle:getAreaCenter(part:getArea())
                                if area then
                                    local dist = player:DistToSquared(area:getX(), area:getY())
                                    if dist < closestDist and dist <= 4 then
                                        closestDist = dist
                                        closestPart = part
                                    end
                                end
                            end
                        end
                    end
                    if closestPart then
                        return closestPart, vehicle
                    end
                end
            end
        end
    end
    return nil, nil
end

-- ============================================
-- ENHANCED TOOL & SKILL CHECK
-- ============================================
local function itemMatchesKeywords(item, keywords)
    if not item then return false end
    local ok, itype = pcall(function() return item:getType() end)
    if not ok or not itype then return false end
    local itemType = tostring(itype):lower()
    for _, keyword in ipairs(keywords) do
        if itemType:find(keyword) then
            return true
        end
    end
    return false
end

local function findVehicleTool(player)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    local primary = player:getPrimaryHandItem()
    if itemMatchesKeywords(primary, {"screwdriver", "wrench"}) then
        return primary
    end
    
    local secondary = player:getSecondaryHandItem()
    if itemMatchesKeywords(secondary, {"screwdriver", "wrench"}) then
        return secondary
    end
    
    for i = 0, items:size()-1 do
        local item = items:get(i)
        if itemMatchesKeywords(item, {"screwdriver", "wrench"}) then
            return item
        end
    end
    
    return nil
end

local function findGarageTool(player)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    local primary = player:getPrimaryHandItem()
    if itemMatchesKeywords(primary, {"crowbar"}) then
        return primary
    end
    
    local secondary = player:getSecondaryHandItem()
    if itemMatchesKeywords(secondary, {"crowbar"}) then
        return secondary
    end
    
    for i = 0, items:size()-1 do
        local item = items:get(i)
        if itemMatchesKeywords(item, {"crowbar"}) then
            return item
        end
    end
    
    return nil
end

local function findDoorTool(player)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    local primary = player:getPrimaryHandItem()
    if itemMatchesKeywords(primary, {"crowbar", "screwdriver"}) then
        return primary
    end
    
    local secondary = player:getSecondaryHandItem()
    if itemMatchesKeywords(secondary, {"crowbar", "screwdriver"}) then
        return secondary
    end
    
    for i = 0, items:size()-1 do
        local item = items:get(i)
        if itemMatchesKeywords(item, {"crowbar", "screwdriver"}) then
            return item
        end
    end
    
    return nil
end

local function findToolForObjectType(player, objType)
    if objType == "vehicle" then
        return findVehicleTool(player)
    elseif objType == "garage" then
        return findGarageTool(player)
    elseif objType == "door" then
        return findDoorTool(player)
    elseif objType == "window" then
        return findDoorTool(player)
    end
    return nil
end

local function hasRequiredSkill(player, objType)
    if objType == "vehicle" then
        return player:getPerkLevel(Perks.Mechanics) >= 2
    elseif objType == "garage" then
        return player:getPerkLevel(Perks.MetalWelding) >= 2
    elseif objType == "door" or objType == "window" then
        return player:getPerkLevel(Perks.Woodwork) >= 1
    end
    return false
end

local function getRequiredSkillText(objType)
    if objType == "vehicle" then return "Mechanics level 2"
    elseif objType == "garage" then return "MetalWelding level 2"
    elseif objType == "door" or objType == "window" then return "Woodwork level 1"
    end
    return ""
end

local function getRequiredToolText(objType)
    if objType == "vehicle" then
        return "screwdriver or wrench"
    elseif objType == "garage" then
        return "crowbar"
    elseif objType == "door" then
        return "crowbar or screwdriver"
    elseif objType == "window" then
        return "crowbar or screwdriver"
    end
    return "tool"
end

-- ============================================
-- ACTION CLASS
-- ============================================
PrySimpleAction = ISBaseTimedAction:derive("PrySimpleAction")

function PrySimpleAction:new(player, object, tool, objType, vehicle, vehiclePart)
    local o = ISBaseTimedAction.new(self, player)
    o.object = object
    o.tool = tool
    o.objType = objType
    o.vehicle = vehicle
    o.vehiclePart = vehiclePart

    if objType == "vehicle" then o.maxTime = 200
    elseif objType == "garage" then o.maxTime = 180
    elseif objType == "window" then o.maxTime = 120
    else o.maxTime = 150 end

    o.stopOnWalk = true
    o.stopOnRun = true
    o.forceProgressBar = true
    return o
end

function PrySimpleAction:isValid()
    if not self.character or not self.tool then return false end
    if not self.character:getInventory():contains(self.tool) then return false end

    if not hasRequiredSkill(self.character, self.objType) then return false end

    if self.objType == "vehicle" then
        if not self.vehiclePart or not self.vehicle then return false end
        local door = self.vehiclePart:getDoor()
        if not door or not door:isLocked() then return false end
        local area = self.vehicle:getAreaCenter(self.vehiclePart:getArea())
        if not area or self.character:DistToSquared(area:getX(),area:getY()) > 4 then return false end
        return true
    else
        if not self.object then return false end
        if not isLockedWorldObject(self.object) then return false end
        local sq = self.object:getSquare()
        if not sq or self.character:DistToSquared(sq:getX()+0.5,sq:getY()+0.5) > 4 then return false end
        return true
    end
end

function PrySimpleAction:waitToStart()
    if self.objType == "vehicle" and self.vehicle then
        self.character:faceLocation(self.vehicle:getX(), self.vehicle:getY())
    elseif self.object then
        self.character:faceThisObject(self.object)
    end
    return self.character:shouldBeTurning()
end

function PrySimpleAction:update()
    if self.objType == "vehicle" and self.vehicle then
        self.character:faceLocation(self.vehicle:getX(), self.vehicle:getY())
    elseif self.object then
        self.character:faceThisObject(self.object)
    end
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function PrySimpleAction:start()
    if self.objType == "window" then
        self:setActionAnim("RemoveBarricade")
        self:setAnimVariable("RemoveBarricade","CrowbarHigh")
    else
        self:setActionAnim("RemoveBarricade")
        self:setAnimVariable("RemoveBarricade","CrowbarMid")
    end
    self:setOverrideHandModels(self.tool,nil)
    self.sound = self.character:getEmitter():playSound("CrowbarHit")
end

function PrySimpleAction:stop()
    if self.sound then self.character:getEmitter():stopSound(self.sound) end
    ISBaseTimedAction.stop(self)
end

function PrySimpleAction:perform()
    if self.sound then self.character:getEmitter():stopSound(self.sound) end

    local failed = false

    -- 25% chance to fail
    if ZombRand(100) < 25 then
        failed = true
        self.character:Say("Failed to pry the " .. self.objType .. "!")
    else
        -- Success: complete the action
        if self.objType == "vehicle" then
            self:completeVehicle()
        elseif self.objType == "window" then
            self:completeWindow()
        elseif self.objType == "door" or self.objType == "garage" then
            self:completeDoor()
        end

        -- Add XP only on success
        self.character:getXp():AddXP(Perks.Strength, 2)
        if self.objType == "vehicle" then
            self.character:getXp():AddXP(Perks.Mechanics, 3)
        else
            self.character:getXp():AddXP(Perks.Woodwork, 3)
        end
    end

    -- Apply tool durability loss (happens regardless of success/failure)
    -- MP-safe: request server to apply damage if client; server applies authoritatively.
    requestDamageTool(self.character, self.tool, failed)

    ISBaseTimedAction.perform(self)
end

function PrySimpleAction:completeDoor()
    if not self.object then return end
    self.object:setLocked(false)
    self.object:setLockedByKey(false)
    self.object:sync()
    if isServer() then
        sendServerCommand(self.character,"PryDoor","DoClientOpenDoor",{x=self.object:getX(),y=self.object:getY(),z=self.object:getZ(),playerIndex=self.character:getPlayerNum() or 0})
    end
    if not isClient() then
        if not self.object:IsOpen() then
            self.object:ToggleDoor(self.character)
        end
    end
    self.character:playSound("BreakDoor")
end

function PrySimpleAction:completeWindow()
    if not self.object then return end
    self.object:setIsLocked(false)
    self.object:sync()
    if isServer() then
        sendServerCommand(self.character,"PryDoor","DoClientOpenWindow",{x=self.object:getX(),y=self.object:getY(),z=self.object:getZ(),playerIndex=self.character:getPlayerNum() or 0})
    end
    if not isClient() then
        if ISWorldObjectContextMenu and ISWorldObjectContextMenu.onOpenCloseWindow then
            ISWorldObjectContextMenu.onOpenCloseWindow(self.object,self.character:getPlayerNum())
        end
    end
    self.character:playSound("BreakDoor")
end

function PrySimpleAction:completeVehicle()
    if not self.vehiclePart or not self.vehicle then return end
    local door = self.vehiclePart:getDoor()
    if not door then return end
    door:setLocked(false)
    if self.vehicle.transmitPartDoor then self.vehicle:transmitPartDoor(self.vehiclePart) end
    self.character:playSound("BreakDoor")
end

-- ============================================
-- SERVER COMMAND HANDLER
-- - Handle opening requests (DoClientOpenWindow/DoClientOpenDoor)
-- - Handle DamageTool requests from clients
-- ============================================
local function onServerCommand(module, command, args)
    if module ~= "PryDoor" then return end
    if not args then return end

    -- Door/window open requests (from server-side action invocation)
    if command == "DoClientOpenWindow" then
        if not args.x then return end
        local sq = getCell():getGridSquare(args.x,args.y,args.z)
        if not sq then return end
        local playerObj = getSpecificPlayer(args.playerIndex or 0)
        if not playerObj then return end
        local objs = sq:getObjects()
        for i=0,objs:size()-1 do
            local obj = objs:get(i)
            if instanceof(obj,"IsoWindow") then
                obj:setIsLocked(false)
                if ISWorldObjectContextMenu and ISWorldObjectContextMenu.onOpenCloseWindow then
                    ISWorldObjectContextMenu.onOpenCloseWindow(obj,playerObj:getPlayerNum())
                end
                return
            end
        end
    elseif command == "DoClientOpenDoor" then
        if not args.x then return end
        local sq = getCell():getGridSquare(args.x,args.y,args.z)
        if not sq then return end
        local playerObj = getSpecificPlayer(args.playerIndex or 0)
        if not playerObj then return end
        local objs = sq:getObjects()
        for i=0,objs:size()-1 do
            local obj = objs:get(i)
            if instanceof(obj,"IsoDoor") or (instanceof(obj,"IsoThumpable") and obj:isDoor()) then
                obj:setLocked(false)
                obj:setLockedByKey(false)
                if not obj:IsOpen() then obj:ToggleDoor(playerObj) end
                return
            end
        end
    elseif command == "DamageTool" then
        -- args: { itemID = <id> (optional), itemType = <type> (optional), failed = bool }
        -- 'player' in this server callback is not provided - we must use args.playerIndex if sent by client.
        -- However when sendServerCommand is called from client with player object, server receives the command with args only,
        -- and we can identify the sender using the network player mapping via getSpecificPlayer if playerIndex included.
        -- Best-effort: use args.playerIndex, otherwise assume player 0.
        local playerIndex = args.playerIndex or 0
        local playerObj = getSpecificPlayer(playerIndex)
        if not playerObj then
            -- Try fallback: assume first player
            playerObj = getSpecificPlayer(0)
        end
        if not playerObj then return end

        local inv = playerObj:getInventory()
        local toolItem = nil

        if args.itemID and inv.getItemFromID then
            pcall(function() toolItem = inv:getItemFromID(args.itemID) end)
        end

        if not toolItem and args.itemType and inv.getItems then
            -- search for matching item type in inventory
            local items = inv:getItems()
            for i = 0, items:size()-1 do
                local it = items:get(i)
                if it and it.getType and it:getType() == args.itemType then
                    toolItem = it
                    break
                end
            end
        end

        -- fallback to hands if still not found
        if not toolItem then
            local primary = playerObj:getPrimaryHandItem()
            if primary and primary.getType and args.itemType and primary:getType() == args.itemType then
                toolItem = primary
            else
                local secondary = playerObj:getSecondaryHandItem()
                if secondary and secondary.getType and args.itemType and secondary:getType() == args.itemType then
                    toolItem = secondary
                end
            end
        end

        -- final fallback: try player's primary/secondary hand anyway
        if not toolItem then
            if playerObj:getPrimaryHandItem() then toolItem = playerObj:getPrimaryHandItem() end
            if not toolItem and playerObj:getSecondaryHandItem() then toolItem = playerObj:getSecondaryHandItem() end
        end

        if not toolItem then return end

        local failed = args.failed and true or false
        local broke = applyToolDurabilityLoss(toolItem, failed)

        if broke then
            local name = getItemDisplayName(toolItem)
            if sendClientCommand then
                pcall(sendClientCommand, playerObj, "PryDoor", "ShowBroken", { name = name })
            else
                if playerObj and playerObj.Say then
                    playerObj:Say("Your " .. name .. " broke!")
                end
            end
        end
    elseif command == "ShowBroken" then
        -- server can ignore; ShowBroken is intended for client display
        return
    end
end

-- ============================================
-- CLIENT: handler for server->client commands (show broken message)
-- ============================================
local function onClientCommand(module, command, args)
    if module ~= "PryDoor" then return end
    if command == "ShowBroken" and args and args.name then
        local player = getPlayer() -- local player (singleplayer/client)
        if player and player.Say then
            player:Say("Your " .. tostring(args.name) .. " broke!")
        else
            print("Your " .. tostring(args.name) .. " broke!")
        end
    end
end

-- Register server/client handlers safely
pcall(function() Events.OnServerCommand.Add(onServerCommand) end)
pcall(function() Events.OnClientCommand.Add(onClientCommand) end)

-- ============================================
-- KEYBIND SUPPORT
-- ============================================
local function onKeyPressed(key)
    if key ~= Keyboard.KEY_GRAVE then return end
    local player = getSpecificPlayer(0)
    if not player or player:getVehicle() then return end
    
    -- Check for vehicle first
    local vehiclePart, vehicle = findVehicleTarget(player)
    if vehiclePart and vehicle then
        -- Check skill first
        if not hasRequiredSkill(player,"vehicle") then
            player:Say("You need Mechanics level 2 to pry this vehicle!")
            return
        end
        
        -- Check for specific tool (screwdriver or wrench)
        local tool = findVehicleTool(player)
        if not tool then
            player:Say("You need a screwdriver or wrench to pry vehicle doors!")
            return
        end
        
        ISTimedActionQueue.add(PrySimpleAction:new(player,nil,tool,"vehicle",vehicle,vehiclePart))
        return
    end
    
    -- Check for world objects (door, garage, window)
    local worldObj, category = findWorldTarget(player)
    if worldObj and category then
        -- Check skill first
        if not hasRequiredSkill(player,category) then
            local skillText = getRequiredSkillText(category)
            player:Say("You need "..skillText.." to pry this "..category.."!")
            return
        end
        
        -- Check for specific tool based on object type
        local tool = findToolForObjectType(player, category)
        if not tool then
            local toolText = getRequiredToolText(category)
            player:Say("You need a "..toolText.." to pry this "..category.."!")
            return
        end
        
        ISTimedActionQueue.add(PrySimpleAction:new(player,worldObj,tool,category,nil,nil))
        return
    end
    
    player:Say("Nothing locked to pry nearby.")
end

-- ============================================
-- INITIALIZATION
-- ============================================
local function init()
    print("=======================================")
    print("PRY DOOR ADVANCED v"..PRY_MOD.VERSION)
    print("Keybind: ` (Backtick)")
    print("Features:")
    print("  - Realistic tool durability system (MP-safe)")
    print("  - Tools wear out with each use (screwdriver & wrench fast; crowbar slow)")
    print("  - Failed attempts cause extra damage")
    print("  - Supports modded tools (fallback damage)")
    print("Tool Requirements:")
    print("  - Vehicle: Screwdriver or Wrench")
    print("  - Garage: Crowbar only")
    print("  - Door: Crowbar or Screwdriver")
    print("  - Window: Crowbar or Screwdriver")
    print("=======================================")
    Events.OnKeyPressed.Add(onKeyPressed)
    -- onServerCommand/onClientCommand already registered above
    print("[PRY-MOD] Successfully Loaded!")
end

Events.OnGameStart.Add(init)
if isClient() then init() end