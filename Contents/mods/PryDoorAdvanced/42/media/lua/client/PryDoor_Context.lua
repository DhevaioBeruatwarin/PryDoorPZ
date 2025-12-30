-- ============================================
-- PRY DOOR ADVANCED - FIXED VERSION
-- Version: 3.1.0 | Bug-Free Edition
-- ============================================

require "ISInventoryPaneContextMenu"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISBaseTimedAction"

local PRY_MOD = {
    VERSION = "3.1.0",
    DEBUG = true  -- Set true untuk debugging
}

-- ============================================
-- SIMPLE OBJECT DETECTION (FIXED)
-- ============================================

local function canPryObject(obj)
    if not obj then return nil end
    
    -- Door
    if instanceof(obj, "IsoDoor") and obj:isLocked() and not obj:isBarricaded() then
        local sprite = obj:getSprite()
        if sprite and sprite:getName() and sprite:getName():contains("Garage") then
            return "garage"
        end
        return "door"
    end
    
    -- Window (FIXED INI!)
    if instanceof(obj, "IsoWindow") then
        if obj:isLocked() or obj:isBarricaded() then
            return "window"
        end
    end
    
    -- Vehicle Door
    if instanceof(obj, "VehicleDoor") and obj:isLocked() then
        return "vehicle"
    end
    
    return nil
end

-- ============================================
-- TOOL FINDER (SIMPLE VERSION)
-- ============================================

local function findToolInInventory(player)
    local inv = player:getInventory()
    
    -- Cek tool berurutan
    local tools = {
        "Base.Crowbar",
        "Base.Axe", 
        "Base.Screwdriver",
        "Base.Hammer",
        "Base.Wrench"
    }
    
    for _, toolType in ipairs(tools) do
        local item = inv:getFirstType(toolType)
        if item then
            return item, toolType
        end
    end
    
    return nil, nil
end

-- ============================================
-- SIMPLE ACTION CLASS (FIXED)
-- ============================================

PrySimpleAction = ISBaseTimedAction:derive("PrySimpleAction")

function PrySimpleAction:new(player, object, tool, objType)
    local o = ISBaseTimedAction.new(self, player)
    o.object = object
    o.tool = tool
    o.objType = objType or "door"
    
    -- Adjust time
    if o.objType == "vehicle" then
        o.maxTime = 200
    elseif o.objType == "garage" then
        o.maxTime = 180
    elseif o.objType == "window" then
        o.maxTime = 120
    else
        o.maxTime = 150
    end
    
    o.stopOnWalk = true
    o.stopOnRun = true
    o.forceProgressBar = true
    
    print("[PRY-DEBUG] Action created: " .. objType .. " | Time: " .. o.maxTime)
    
    return o
end

function PrySimpleAction:isValid()
    if not self.character or not self.object or not self.tool then 
        print("[PRY-DEBUG] Invalid: Missing params")
        return false 
    end
    
    if not self.character:getInventory():contains(self.tool) then
        print("[PRY-DEBUG] Invalid: Tool not in inventory")
        return false
    end
    
    -- Object validation
    if self.objType == "door" or self.objType == "garage" then
        return instanceof(self.object, "IsoDoor") and self.object:isLocked()
    elseif self.objType == "window" then
        return instanceof(self.object, "IsoWindow") and (self.object:isLocked() or self.object:isBarricaded())
    elseif self.objType == "vehicle" then
        return instanceof(self.object, "VehicleDoor") and self.object:isLocked()
    end
    
    print("[PRY-DEBUG] Invalid: No matching object type")
    return false
end

function PrySimpleAction:start()
    print("[PRY-DEBUG] Action started")
    
    -- Set animation
    if self.objType == "window" then
        self:setActionAnim("AttackWindow")
    else
        self:setActionAnim("AttackDoor")
    end
    
    self:setOverrideHandModels(self.tool, nil)
    self.character:playSound("BreakDoor")
end

function PrySimpleAction:update()
    -- Optional sound effects
    if ZombRand(100) < 10 then
        self.character:playSound("BreakBarricadeWood")
    end
end

function PrySimpleAction:perform()
    print("[PRY-DEBUG] Action performing...")
    
    local sq = nil
    
    -- Get square
    if self.objType == "vehicle" then
        local vehicle = self.object:getVehicle()
        if vehicle then
            sq = vehicle:getSquare()
        end
    else
        sq = self.object:getSquare()
    end
    
    if sq then
        -- Calculate success chance
        local strength = self.character:getPerkLevel(Perks.Strength)
        local baseChance = 50 + (strength * 3)
        baseChance = math.min(95, math.max(10, baseChance))
        
        local roll = ZombRand(100)
        local success = roll < baseChance
        
        local args = {
            x = sq:getX(),
            y = sq:getY(),
            z = sq:getZ(),
            tool = self.tool:getType():lower(),
            objType = self.objType,
            toolType = self.tool:getFullType(),
            success = success,
            chance = baseChance,
            roll = roll
        }
        
        -- Add vehicle data
        if self.objType == "vehicle" then
            local vehicle = self.object:getVehicle()
            if vehicle then
                args.vehicleId = vehicle:getId()
                args.partId = self.object:getId()
            end
        end
        
        print("[PRY-DEBUG] Sending command: " .. self.objType .. " | Chance: " .. baseChance .. "%")
        sendClientCommand(self.character, "PryDoor", "tryPry", args)
        
        -- Local feedback
        if success then
            self.character:playSound("BreakDoor")
            self.character:getXp():AddXP(Perks.Strength, 6)
        else
            self.character:playSound("BreakBarricadeMetal")
        end
    end
    
    ISBaseTimedAction.perform(self)
end

function PrySimpleAction:stop()
    ISBaseTimedAction.stop(self)
end

-- ============================================
-- CONTEXT MENU HANDLER (FIXED - INI YANG BEKERJA!)
-- ============================================

local function onFillWorldObjectContextMenu(player, context, worldobjects)
    print("[PRY-DEBUG] Context menu triggered")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then 
        print("[PRY-DEBUG] No player object")
        return 
    end
    
    -- Cek satu per satu object
    for _, obj in ipairs(worldobjects) do
        print("[PRY-DEBUG] Checking object: " .. tostring(obj))
        
        local objType = canPryObject(obj)
        
        if objType then
            print("[PRY-DEBUG] Found pryable object: " .. objType)
            
            -- Cari tool
            local tool, toolType = findToolInInventory(playerObj)
            
            if tool then
                print("[PRY-DEBUG] Found tool: " .. tool:getType())
                
                -- Buat teks option
                local optionText = ""
                if objType == "window" then
                    optionText = "Pry Open Window"
                elseif objType == "garage" then
                    optionText = "Pry Open Garage"
                elseif objType == "vehicle" then
                    optionText = "Pry Open Vehicle Door"
                else
                    optionText = "Pry Open Door"
                end
                
                -- Tambahkan icon tool jika ada
                optionText = optionText .. " (" .. tool:getDisplayName() .. ")"
                
                -- Add to context menu
                local option = context:addOption(optionText, playerObj, function()
                    print("[PRY-DEBUG] Context menu option clicked!")
                    ISTimedActionQueue.add(PrySimpleAction:new(playerObj, obj, tool, objType))
                end)
                
                -- Add tooltip
                local tooltip = ISToolTip:new()
                tooltip:initialise()
                tooltip:setVisible(false)
                tooltip:setName(optionText)
                
                local tooltipText = "Use " .. tool:getDisplayName() .. " to pry open this " .. objType .. ".\n"
                tooltipText = tooltipText .. "Requires strength and takes some time.\n"
                tooltipText = tooltipText .. "Success chance depends on your Strength skill."
                
                tooltip.description = tooltipText
                option.toolTip = tooltip
                
                -- Hanya tampilkan satu option
                break
            else
                print("[PRY-DEBUG] No tool found in inventory")
                
                -- Show disabled option
                local option = context:addOption("Pry Open (Need Tool)", nil, nil)
                option.notAvailable = true
                
                local tooltip = ISToolTip:new()
                tooltip:initialise()
                tooltip:setVisible(false)
                tooltip.description = "You need a tool (Crowbar, Axe, Screwdriver, Hammer, or Wrench) to pry this open."
                option.toolTip = tooltip
                
                break
            end
        end
    end
end

-- ============================================
-- SERVER SIDE HANDLER (SIMPLE)
-- ============================================

local function onServerCommand(module, command, player, args)
    if module ~= "PryDoor" or command ~= "tryPry" then return end
    
    print("[PRY-SERVER] Received command from " .. player:getDisplayName())
    
    if not args or not args.x then return end
    
    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    if not sq then return end
    
    local targetObj = nil
    local objType = args.objType
    
    -- Find object
    if objType == "vehicle" and args.vehicleId then
        local vehicle = getVehicleById(args.vehicleId)
        if vehicle then
            local part = vehicle:getPartById(args.partId)
            if part and instanceof(part, "VehicleDoor") then
                targetObj = part
            end
        end
    else
        for i = 0, sq:getObjects():size() - 1 do
            local obj = sq:getObjects():get(i)
            
            if objType == "door" and instanceof(obj, "IsoDoor") then
                targetObj = obj
                break
            elseif objType == "window" and instanceof(obj, "IsoWindow") then
                targetObj = obj
                break
            elseif objType == "garage" and instanceof(obj, "IsoDoor") then
                if obj:getSprite() and obj:getSprite():getName():contains("Garage") then
                    targetObj = obj
                    break
                end
            end
        end
    end
    
    if not targetObj then
        print("[PRY-SERVER] Target object not found")
        return
    end
    
    -- Process result
    if args.success then
        print("[PRY-SERVER] Success! Opening " .. objType)
        
        if objType == "door" or objType == "garage" then
            targetObj:setLocked(false)
            targetObj:setLockedByKey(false)
            targetObj:ToggleDoor(player)
        elseif objType == "window" then
            targetObj:setLocked(false)
            targetObj:setBarricaded(false)
            targetObj:ToggleWindow(player)
        elseif objType == "vehicle" then
            targetObj:setLocked(false)
        end
    else
        print("[PRY-SERVER] Failed to open " .. objType)
    end
end

-- ============================================
-- KEYBIND SUPPORT (OPTIONAL)
-- ============================================

local function onKeyPressed(key)
    -- Hold Z untuk quick action
    if key == Keyboard.KEY_Z then
        local player = getSpecificPlayer(0)
        if not player or player:getVehicle() then return end
        
        -- Cari object di sekitar
        local sq = player:getSquare()
        if not sq then return end
        
        for dx = -1, 1 do
            for dy = -1, 1 do
                local checkSq = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
                if checkSq then
                    for i = 0, checkSq:getObjects():size() - 1 do
                        local obj = checkSq:getObjects():get(i)
                        local objType = canPryObject(obj)
                        
                        if objType then
                            local tool = findToolInInventory(player)
                            if tool then
                                ISTimedActionQueue.add(PrySimpleAction:new(player, obj, tool, objType))
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================
-- INITIALIZATION
-- ============================================

local function init()
    print("=======================================")
    print("PRY DOOR ADVANCED v" .. PRY_MOD.VERSION)
    print("Loading...")
    print("=======================================")
    
    -- Register events
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
    Events.OnClientCommand.Add(onServerCommand)
    Events.OnKeyPressed.Add(onKeyPressed)
    
    print("[PRY-MOD] Successfully loaded!")
    print("Features: Door, Window, Garage, Vehicle")
    print("Tools: Crowbar, Axe, Screwdriver, Hammer, Wrench")
    print("=======================================")
end

-- Initialize when game starts
Events.OnGameStart.Add(init)

-- Untuk testing langsung
if isClient() then
    init()
end