require "TimedActions/ISBaseTimedAction"
require "PryDoor/PryDoor_Config"
require "PryDoor/PryDoor_Utils"

PryDoorAction = ISBaseTimedAction:derive("PryDoorAction")

local Config = PryDoor.Config
local Utils = PryDoor.Utils

function PryDoorAction:new(player,obj,tool,type,vehicle,part)
    local o = ISBaseTimedAction.new(self,player)
    o.object=obj; o.tool=tool; o.objType=type
    o.vehicle=vehicle; o.vehiclePart=part
    o.maxTime=Config.DURATION[type] or 150
    return o
end

function PryDoorAction:perform()
    local success = ZombRand(100) < Utils.calculateSuccessChance(self.character,self.tool,self.objType)*100
    if success then
        if self.object then
            self.object:setLocked(false)
            self.object:setLockedByKey(false)
            self.object:sync()
        end
        self.character:Say(Config.MESSAGES.SUCCESS)
    else
        Utils.handleFailure(self.character)
    end
    Utils.applyFatigue(self.character,self.objType)
    ISBaseTimedAction.perform(self)
end

return PryDoorAction
