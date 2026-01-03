-- ============================================
-- PRY DOOR ADVANCED - KEYBIND ONLY
-- Version: 3.6.5 | Keybind: `
-- Features: Door, Garage, Window, Vehicle
-- Adds: Skill Check, Tool Check, Chance Fail
-- ENHANCED: Specific tool requirements per object type
-- ============================================

require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISBaseTimedAction"
require "ISUI/ISWorldObjectContextMenu"

local PRY_MOD = { VERSION = "3.6.5-ENHANCED", DEBUG = false }

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

-- Helper function to check if item type matches keywords
local function itemMatchesKeywords(item, keywords)
    if not item then return false end
    local itemType = item:getType():lower()
    for _, keyword in ipairs(keywords) do
        if itemType:find(keyword) then
            return true
        end
    end
    return false
end

-- NEW: Find specific tool for vehicle (screwdriver or wrench)
local function findVehicleTool(player)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    -- Check primary hand
    local primary = player:getPrimaryHandItem()
    if itemMatchesKeywords(primary, {"screwdriver", "wrench"}) then
        return primary
    end
    
    -- Check secondary hand
    local secondary = player:getSecondaryHandItem()
    if itemMatchesKeywords(secondary, {"screwdriver", "wrench"}) then
        return secondary
    end
    
    -- Check inventory
    for i = 0, items:size()-1 do
        local item = items:get(i)
        if itemMatchesKeywords(item, {"screwdriver", "wrench"}) then
            return item
        end
    end
    
    return nil
end

-- NEW: Find specific tool for garage (crowbar only)
local function findGarageTool(player)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    -- Check primary hand
    local primary = player:getPrimaryHandItem()
    if itemMatchesKeywords(primary, {"crowbar"}) then
        return primary
    end
    
    -- Check secondary hand
    local secondary = player:getSecondaryHandItem()
    if itemMatchesKeywords(secondary, {"crowbar"}) then
        return secondary
    end
    
    -- Check inventory
    for i = 0, items:size()-1 do
        local item = items:get(i)
        if itemMatchesKeywords(item, {"crowbar"}) then
            return item
        end
    end
    
    return nil
end

-- NEW: Find specific tool for door (crowbar or screwdriver)
local function findDoorTool(player)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    -- Check primary hand
    local primary = player:getPrimaryHandItem()
    if itemMatchesKeywords(primary, {"crowbar", "screwdriver"}) then
        return primary
    end
    
    -- Check secondary hand
    local secondary = player:getSecondaryHandItem()
    if itemMatchesKeywords(secondary, {"crowbar", "screwdriver"}) then
        return secondary
    end
    
    -- Check inventory
    for i = 0, items:size()-1 do
        local item = items:get(i)
        if itemMatchesKeywords(item, {"crowbar", "screwdriver"}) then
            return item
        end
    end
    
    return nil
end

-- NEW: Find tool based on object type
local function findToolForObjectType(player, objType)
    if objType == "vehicle" then
        return findVehicleTool(player)
    elseif objType == "garage" then
        return findGarageTool(player)
    elseif objType == "door" then
        return findDoorTool(player)
    elseif objType == "window" then
        -- Window can use crowbar or screwdriver
        return findDoorTool(player)
    end
    return nil
end

-- OLD function kept for backward compatibility
local function findToolInInventory(player)
    local inv = player:getInventory()
    local tools = {"Base.Crowbar","Base.Axe","Base.Screwdriver","Base.Hammer","Base.Wrench"}
    for _, t in ipairs(tools) do
        local item = inv:getFirstType(t)
        if item then return item end
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

-- NEW: Get required tool text
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

    -- Chance fail (20%)
    local failChance = ZombRand(100)
    if failChance < 20 then
        self.character:Say("Failed to pry the " .. self.objType .. ", your tool was not strong enough.")
        ISBaseTimedAction.perform(self)
        return
    end

    if self.objType == "vehicle" then
        self:completeVehicle()
    elseif self.objType == "window" then
        self:completeWindow()
    elseif self.objType == "door" or self.objType == "garage" then
        self:completeDoor()
    end

    -- Add XP
    self.character:getXp():AddXP(Perks.Strength, 2)
    if self.objType == "vehicle" then
        self.character:getXp():AddXP(Perks.Mechanics, 3)
    else
        self.character:getXp():AddXP(Perks.Woodwork, 3)
    end

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
-- ============================================
local function onServerCommand(module, command, args)
    if module ~= "PryDoor" then return end
    if not args or not args.x then return end
    local sq = getCell():getGridSquare(args.x,args.y,args.z)
    if not sq then return end
    local playerObj = getSpecificPlayer(args.playerIndex or 0)
    if not playerObj then return end
    if command == "DoClientOpenWindow" then
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
    end
end

-- ============================================
-- KEYBIND SUPPORT (ENHANCED WITH SPECIFIC TOOL CHECK)
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
    print("ENHANCED: Specific Tool Requirements")
    print("  - Vehicle: Screwdriver or Wrench")
    print("  - Garage: Crowbar only")
    print("  - Door: Crowbar or Screwdriver")
    print("  - Window: Crowbar or Screwdriver")
    print("=======================================")
    Events.OnKeyPressed.Add(onKeyPressed)
    Events.OnServerCommand.Add(onServerCommand)
    print("[PRY-MOD] Successfully Loaded!")
end

Events.OnGameStart.Add(init)
if isClient() then init() end