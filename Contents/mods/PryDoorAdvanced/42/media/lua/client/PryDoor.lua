-- ============================================
-- PRY DOOR ADVANCED v3.8.1-ANIMATED
-- Keybind: ` (Backtick) | Trigger: LEFT CLICK
-- Features: Animated Pry + Mini Game + Tool Durability
-- MP-Safe | Supports: Door, Garage, Window, Vehicle
-- This mod made by Dhevaio AKA dheva1o
-- ============================================

require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISBaseTimedAction"
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/ISPanel"

local PRY_MOD = { VERSION = "3.8.1-ANIMATED", DEBUG = false }

-- ============================================
-- CONFIGURATION (REVISED - TOOLS LAST LONGER)
-- ============================================
local MINIGAME = {
    width = 500,       
    height = 180,       
    sliderWidth = 10,   
    sliderHeight = 70, 
    pivotWidth = 70,    
    speed = 20,
    autoCenterPivot = true,
    debug = false
}


local TOOL_DURABILITY_LOSS = {
    screwdriver = { min = 1, max = 2 },  
    wrench      = { min = 1, max = 2 },  
    crowbar     = { min = 1, max = 1 },  
}

local FAIL_MULTIPLIER = 1.2
local FALLBACK_DURABILITY_LOSS = 5  

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function debugPrint(msg)
    if PRY_MOD.DEBUG or MINIGAME.debug then
        print("[PRY-DEBUG] " .. tostring(msg))
    end
end

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
-- TOOL DURABILITY SYSTEM (MP-SAFE) - IMPROVED
-- ============================================
local function applyToolDurabilityLoss(player, tool, failed)
    if not tool then return false end

    local t = tool:getType():lower()
    local cfg = nil

    if t:find("screwdriver") then
        cfg = TOOL_DURABILITY_LOSS.screwdriver
    elseif t:find("wrench") then
        cfg = TOOL_DURABILITY_LOSS.wrench
    elseif t:find("crowbar") then
        cfg = TOOL_DURABILITY_LOSS.crowbar
    end

    local loss = 0
    
    if cfg then
        loss = ZombRand(cfg.min, cfg.max + 1)
    else
        loss = FALLBACK_DURABILITY_LOSS
    end

    if failed then
        loss = math.floor(loss * FAIL_MULTIPLIER)
    end

    debugPrint("Tool damage: " .. loss .. " (failed=" .. tostring(failed) .. ")")

    if isClient() then
        sendClientCommand(player, "PryDoor", "ApplyToolDamage", {
            toolType = tool:getType(),
            damage = loss,
            playerIndex = player:getPlayerNum()
        })
    else
        local newCondition = tool:getCondition() - loss
        tool:setCondition(math.max(newCondition, 0))
        
        if newCondition <= 0 then
            player:Say("Your " .. tool:getDisplayName() .. " broke!")
            return true
        end
    end
    
    return false
end

-- ============================================
-- OBJECT DETECTION
-- ============================================
local function findWorldTarget(player)
    local sq = player:getSquare()
    if not sq then return nil, nil end
    
    for dx = -1, 1 do
        for dy = -1, 1 do
            local checkSq = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if checkSq then
                local objs = checkSq:getObjects()
                for i = 0, objs:size() - 1 do
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
    
    for dx = -1, 1 do
        for dy = -1, 1 do
            local checkSq = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if checkSq then
                local vehicle = checkSq:getVehicleContainer()
                if vehicle then
                    local closestPart = nil
                    local closestDist = 999999
                    for i = 0, vehicle:getPartCount() - 1 do
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
-- TOOL DETECTION
-- ============================================
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

local function findToolInInventory(player, keywords)
    local inv = player:getInventory()
    local items = inv:getItems()
    
    local primary = player:getPrimaryHandItem()
    if itemMatchesKeywords(primary, keywords) then
        return primary
    end
    
    local secondary = player:getSecondaryHandItem()
    if itemMatchesKeywords(secondary, keywords) then
        return secondary
    end
    
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if itemMatchesKeywords(item, keywords) then
            return item
        end
    end
    
    return nil
end

local function findToolForObjectType(player, objType)
    if objType == "vehicle" then
        return findToolInInventory(player, {"screwdriver", "wrench"})
    elseif objType == "garage" then
        return findToolInInventory(player, {"crowbar"})
    elseif objType == "door" or objType == "window" then
        return findToolInInventory(player, {"crowbar", "screwdriver"})
    end
    return nil
end

-- ============================================
-- SKILL CHECK
-- ============================================
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
    if objType == "vehicle" then return "Mechanics 2"
    elseif objType == "garage" then return "MetalWelding 2"
    elseif objType == "door" or objType == "window" then return "Woodwork 1"
    end
    return ""
end

local function getRequiredToolText(objType)
    if objType == "vehicle" then return "screwdriver or wrench"
    elseif objType == "garage" then return "crowbar"
    elseif objType == "door" or objType == "window" then return "crowbar or screwdriver"
    end
    return "tool"
end

-- ============================================
-- ANIMATED PRY ACTION
-- ============================================
PryAnimatedAction = ISBaseTimedAction:derive("PryAnimatedAction")

function PryAnimatedAction:new(player, object, tool, objType, vehicle, vehiclePart)
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

function PryAnimatedAction:isValid()
    if not self.character or not self.tool then return false end
    if not self.character:getInventory():contains(self.tool) then return false end
    if self.tool:getCondition() <= 0 then return false end

    if self.objType == "vehicle" then
        if not self.vehiclePart or not self.vehicle then return false end
        local door = self.vehiclePart:getDoor()
        if not door or not door:isLocked() then return false end
        return true
    else
        if not self.object then return false end
        if not isLockedWorldObject(self.object) then return false end
        return true
    end
end

function PryAnimatedAction:waitToStart()
    if self.objType == "vehicle" and self.vehicle then
        self.character:faceLocation(self.vehicle:getX(), self.vehicle:getY())
    elseif self.object then
        self.character:faceThisObject(self.object)
    end
    return self.character:shouldBeTurning()
end

function PryAnimatedAction:update()
    if self.objType == "vehicle" and self.vehicle then
        self.character:faceLocation(self.vehicle:getX(), self.vehicle:getY())
    elseif self.object then
        self.character:faceThisObject(self.object)
    end
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function PryAnimatedAction:start()
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

function PryAnimatedAction:stop()
    if self.sound then self.character:getEmitter():stopSound(self.sound) end
    ISBaseTimedAction.stop(self)
end

function PryAnimatedAction:perform()
    if self.sound then self.character:getEmitter():stopSound(self.sound) end

    -- Complete the pry action
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

    self.character:Say("Successfully pried open!")
    
    -- Apply tool durability loss (REDUCED)
    applyToolDurabilityLoss(self.character, self.tool, false)

    ISBaseTimedAction.perform(self)
end

function PryAnimatedAction:completeDoor()
    if not self.object then return end
    self.object:setLocked(false)
    self.object:setLockedByKey(false)
    self.object:sync()
    if isServer() then
        sendServerCommand(self.character,"PryDoor","DoClientOpenDoor",{
            x=self.object:getX(),
            y=self.object:getY(),
            z=self.object:getZ(),
            playerIndex=self.character:getPlayerNum() or 0
        })
    end
    if not isClient() then
        if not self.object:IsOpen() then
            self.object:ToggleDoor(self.character)
        end
    end
    self.character:playSound("BreakDoor")
end

function PryAnimatedAction:completeWindow()
    if not self.object then return end
    self.object:setIsLocked(false)
    self.object:sync()
    if isServer() then
        sendServerCommand(self.character,"PryDoor","DoClientOpenWindow",{
            x=self.object:getX(),
            y=self.object:getY(),
            z=self.object:getZ(),
            playerIndex=self.character:getPlayerNum() or 0
        })
    end
    if not isClient() then
        if ISWorldObjectContextMenu and ISWorldObjectContextMenu.onOpenCloseWindow then
            ISWorldObjectContextMenu.onOpenCloseWindow(self.object,self.character:getPlayerNum())
        end
    end
    self.character:playSound("BreakDoor")
end

function PryAnimatedAction:completeVehicle()
    if not self.vehiclePart or not self.vehicle then return end
    local door = self.vehiclePart:getDoor()
    if not door then return end
    door:setLocked(false)
    if self.vehicle.transmitPartDoor then self.vehicle:transmitPartDoor(self.vehiclePart) end
    self.character:playSound("BreakDoor")
end

-- ============================================
-- MINI GAME UI PANEL (REVISED - LARGER)
-- ============================================
PryMiniGamePanel = ISPanel:derive("PryMiniGamePanel")

function PryMiniGamePanel:new(x, y, player, object, objType, vehicle, vehiclePart, tool)
    local o = ISPanel:new(x, y, MINIGAME.width, MINIGAME.height)
    setmetatable(o, self)
    self.__index = self
    
    o.player = player
    o.object = object
    o.objType = objType
    o.vehicle = vehicle
    o.vehiclePart = vehiclePart
    o.tool = tool
    
    o.sliderX = 0
    o.sliderDirection = 1
    o.pivotX = MINIGAME.autoCenterPivot and (MINIGAME.width - MINIGAME.pivotWidth) / 2 or ZombRand(50, MINIGAME.width - MINIGAME.pivotWidth - 50)
    o.completed = false
    o.shouldClose = false
    
    o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.9}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    
    o.quitButtonWidth = 100  -- DIPERBESAR
    o.quitButtonHeight = 35  -- DIPERBESAR
    o.quitButtonX = MINIGAME.width - o.quitButtonWidth - 10
    o.quitButtonY = MINIGAME.height - o.quitButtonHeight - 10
    
    debugPrint("Mini game created: pivot at " .. o.pivotX)
    
    return o
end

function PryMiniGamePanel:initialise()
    ISPanel.initialise(self)
    self:setVisible(true)
    self:addToUIManager()
end

function PryMiniGamePanel:update()
    ISPanel.update(self)
    
    if self.completed then
        if self.shouldClose then
            self:close()
        end
        return
    end
    
    self.sliderX = self.sliderX + (MINIGAME.speed * self.sliderDirection)
    
    local maxX = MINIGAME.width - MINIGAME.sliderWidth
    if self.sliderX >= maxX then
        self.sliderX = maxX
        self.sliderDirection = -1
    elseif self.sliderX <= 0 then
        self.sliderX = 0
        self.sliderDirection = 1
    end
end

function PryMiniGamePanel:render()
    ISPanel.render(self)
    
    -- Background
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, 
                  self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, 
                        self.borderColor.r, self.borderColor.g, self.borderColor.b)
    
    -- Main Title
    local title = "PRY " .. self.objType:upper() .. " - LEFT CLICK when in zone!"
    self:drawTextCentre(title, self.width / 2, 15, 1, 1, 1, 1, UIFont.Medium)
    
    -- MOD AUTHOR TITLE (ADDED)
    local authorTitle = "this mod made by Dhevaio AKA dheva1o"
    self:drawTextCentre(authorTitle, self.width / 2, 40, 0.7, 0.7, 1, 1, UIFont.Small)
    
    -- Instruction
    local instruction = "Click QUIT button to exit | Press SHIFT to cancel"
    self:drawTextCentre(instruction, self.width / 2, 65, 0.7, 0.7, 0.7, 1, UIFont.Small)
    
    -- Track & Pivot & Slider
    local trackY = 95
    local trackHeight = 35
    self:drawRect(10, trackY, self.width - 20, trackHeight, 0.5, 0.2, 0.2, 0.2)
    
    -- Pivot Zone
    self:drawRect(10 + self.pivotX, trackY, MINIGAME.pivotWidth, trackHeight, 0.8, 0.8, 0.1, 0.1)
    
    -- Slider
    local sliderY = trackY + (trackHeight - MINIGAME.sliderHeight) / 2
    self:drawRect(10 + self.sliderX, sliderY, MINIGAME.sliderWidth, MINIGAME.sliderHeight, 1, 0.2, 0.8, 0.2)
    
    -- Quit Button
    local mouseX = getMouseX()
    local mouseY = getMouseY()
    local isHovering = mouseX >= self.x + self.quitButtonX and mouseX <= self.x + self.quitButtonX + self.quitButtonWidth and
                       mouseY >= self.y + self.quitButtonY and mouseY <= self.y + self.quitButtonY + self.quitButtonHeight
    
    if isHovering then
        self:drawRect(self.quitButtonX, self.quitButtonY, self.quitButtonWidth, self.quitButtonHeight, 1, 0.9, 0.2, 0.2)
    else
        self:drawRect(self.quitButtonX, self.quitButtonY, self.quitButtonWidth, self.quitButtonHeight, 0.9, 0.7, 0.1, 0.1)
    end
    self:drawRectBorder(self.quitButtonX, self.quitButtonY, self.quitButtonWidth, self.quitButtonHeight, 1, 0.8, 0.8, 0.8)
    
    local buttonText = "QUIT"
    local textWidth = getTextManager():MeasureStringX(UIFont.Medium, buttonText)
    local textX = self.quitButtonX + (self.quitButtonWidth - textWidth) / 2
    local textY = self.quitButtonY + (self.quitButtonHeight - getTextManager():getFontHeight(UIFont.Medium)) / 2
    self:drawText(buttonText, textX, textY, 1, 1, 1, 1, UIFont.Medium)
    
    -- Debug info
    if MINIGAME.debug then
        local debugText = string.format("Slider: %.1f | Pivot: %.1f-%.1f", 
                                        self.sliderX, self.pivotX, self.pivotX + MINIGAME.pivotWidth)
        self:drawText(debugText, 10, self.height - 20, 1, 1, 0, 1, UIFont.Small)
    end
end

function PryMiniGamePanel:onMouseDown(x, y)
    if self.completed then return end
    
    local mouseX = x - self.x
    local mouseY = y - self.y
    
    -- Check if clicking QUIT button
    if mouseX >= self.quitButtonX and mouseX <= self.quitButtonX + self.quitButtonWidth and
       mouseY >= self.quitButtonY and mouseY <= self.quitButtonY + self.quitButtonHeight then
        self.player:Say("You exited the mini game")
        self.completed = true
        self.shouldClose = true
        return true
    end
    
    -- Submit mini-game attempt
    self:submit()
    return true
end

function PryMiniGamePanel:onKeyPress(key)
    if self.completed then return end
    
    if key == Keyboard.KEY_LSHIFT or key == Keyboard.KEY_RSHIFT then
        self.player:Say("You exited the mini game")
        self.completed = true
        self.shouldClose = true
        return true
    end
    
    return false
end

function PryMiniGamePanel:submit()
    if self.completed then return end
    
    self.completed = true
    
    local sliderCenter = self.sliderX + (MINIGAME.sliderWidth / 2)
    local pivotStart = self.pivotX
    local pivotEnd = self.pivotX + MINIGAME.pivotWidth
    
    local success = sliderCenter >= pivotStart and sliderCenter <= pivotEnd
    
    debugPrint(string.format("Submit: center=%.1f, pivot=[%.1f-%.1f], success=%s", 
                             sliderCenter, pivotStart, pivotEnd, tostring(success)))
    
    if success then
        -- WIN: Start animated pry action
        ISTimedActionQueue.add(PryAnimatedAction:new(
            self.player, self.object, self.tool, self.objType, self.vehicle, self.vehiclePart
        ))
        self.shouldClose = true
    else
        -- FAIL: Exit with extra damage (REDUCED)
        self.player:Say("Missed! Try again.")
        applyToolDurabilityLoss(self.player, self.tool, true)
        self.shouldClose = true
    end
end

function PryMiniGamePanel:close()
    self:setVisible(false)
    self:removeFromUIManager()
    debugPrint("Mini game closed")
end

-- ============================================
-- SERVER/CLIENT COMMAND HANDLERS
-- ============================================
local function onServerCommand(module, command, args)
    if module ~= "PryDoor" then return end
    if not args then return end
    
    local playerObj = getSpecificPlayer(args.playerIndex or 0)
    if not playerObj then return end
    
    if command == "DoClientOpenWindow" then
        local sq = getCell():getGridSquare(args.x, args.y, args.z)
        if not sq then return end
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if instanceof(obj, "IsoWindow") then
                obj:setIsLocked(false)
                if ISWorldObjectContextMenu and ISWorldObjectContextMenu.onOpenCloseWindow then
                    ISWorldObjectContextMenu.onOpenCloseWindow(obj, playerObj:getPlayerNum())
                end
                return
            end
        end
    elseif command == "DoClientOpenDoor" then
        local sq = getCell():getGridSquare(args.x, args.y, args.z)
        if not sq then return end
        local objs = sq:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor()) then
                obj:setLocked(false)
                obj:setLockedByKey(false)
                if not obj:IsOpen() then
                    obj:ToggleDoor(playerObj)
                end
                return
            end
        end
    elseif command == "ApplyToolDamage" then
        local inv = playerObj:getInventory()
        local items = inv:getItems()
        
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item:getType() == args.toolType then
                local newCondition = item:getCondition() - args.damage
                item:setCondition(math.max(newCondition, 0))
                
                if newCondition <= 0 then
                    sendServerCommand(playerObj, "PryDoor", "ShowBroken", {
                        toolName = item:getDisplayName()
                    })
                end
                return
            end
        end
    end
end

local function onClientCommand(module, command, args)
    if module ~= "PryDoor" then return end
    
    if command == "ShowBroken" then
        local player = getSpecificPlayer(0)
        if player and args.toolName then
            player:Say("Your " .. args.toolName .. " broke!")
        end
    end
end

-- ============================================
-- KEYBIND HANDLER
-- ============================================
local function onKeyPressed(key)
    if key ~= Keyboard.KEY_GRAVE then return end
    
    local player = getSpecificPlayer(0)
    if not player or player:getVehicle() then return end
    
    -- Check vehicle
    local vehiclePart, vehicle = findVehicleTarget(player)
    if vehiclePart and vehicle then
        if not hasRequiredSkill(player, "vehicle") then
            player:Say("Need " .. getRequiredSkillText("vehicle") .. "!")
            return
        end
        
        local tool = findToolForObjectType(player, "vehicle")
        if not tool then
            player:Say("Need " .. getRequiredToolText("vehicle") .. "!")
            return
        end
        
        if tool:getCondition() <= 0 then
            player:Say("Your tool is broken!")
            return
        end
        
        local panel = PryMiniGamePanel:new(
            getCore():getScreenWidth() / 2 - MINIGAME.width / 2,
            getCore():getScreenHeight() / 2 - MINIGAME.height / 2,
            player, nil, "vehicle", vehicle, vehiclePart, tool
        )
        panel:initialise()
        return
    end
    
    -- Check world objects
    local worldObj, category = findWorldTarget(player)
    if worldObj and category then
        if not hasRequiredSkill(player, category) then
            player:Say("Need " .. getRequiredSkillText(category) .. "!")
            return
        end
        
        local tool = findToolForObjectType(player, category)
        if not tool then
            player:Say("Need " .. getRequiredToolText(category) .. "!")
            return
        end
        
        if tool:getCondition() <= 0 then
            player:Say("Your tool is broken!")
            return
        end
        
        local panel = PryMiniGamePanel:new(
            getCore():getScreenWidth() / 2 - MINIGAME.width / 2,
            getCore():getScreenHeight() / 2 - MINIGAME.height / 2,
            player, worldObj, category, nil, nil, tool
        )
        panel:initialise()
        return
    end
    
    player:Say("Nothing locked nearby.")
end

-- ============================================
-- INITIALIZATION
-- ============================================
local function init()
    print("=======================================")
    print("PRY DOOR ADVANCED v" .. PRY_MOD.VERSION)
    print("This mod made by Dhevaio AKA dheva1o")
    print("=======================================")
    print("Keybind: ` (Backtick) to start")
    print("Features:")
    print("  - Animated pry with character movement")
    print("  - Larger mini-game panel")
    print("  - REDUCED tool durability loss")
    print("  - QUIT button & SHIFT to exit")
    print("  - MP-safe implementation")
    print("Tool Durability (IMPROVED):")
    print("  - Crowbar: ~25-30 uses (was ~20-33)")
    print("  - Screwdriver/Wrench: ~20-25 uses (was ~13-15)")
    print("  - Failed attempts: 1.2x damage")
    print("=======================================")
    
    Events.OnKeyPressed.Add(onKeyPressed)
    Events.OnServerCommand.Add(onServerCommand)
    Events.OnClientCommand.Add(onClientCommand)
    
    print("[PRY-MOD] Successfully Loaded by Dhevaio!")
end

Events.OnGameStart.Add(init)
if isClient() then init() end