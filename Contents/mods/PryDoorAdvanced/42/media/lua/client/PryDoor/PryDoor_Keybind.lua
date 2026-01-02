require "TimedActions/ISTimedActionQueue"
require "PryDoor/PryDoor_Config"
require "PryDoor/PryDoor_Utils"
require "PryDoor/PryDoor_Detection"
require "PryDoor/PryDoor_Action"

local Config=PryDoor.Config
local Utils=PryDoor.Utils
local Detect=PryDoor.Detection

local function onKeyPressed(key)
    if key~=Config.KEYBIND then return end
    local player=getSpecificPlayer(0)
    local tool=Utils.findTool(player)
    if not tool then player:Say(Config.MESSAGES.NO_TOOL) return end

    local obj,cat=Detect.findWorldTarget(player)
    if obj then
        ISTimedActionQueue.add(PryDoorAction:new(player,obj,tool,cat))
    else
        player:Say(Config.MESSAGES.NOTHING_LOCKED)
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
