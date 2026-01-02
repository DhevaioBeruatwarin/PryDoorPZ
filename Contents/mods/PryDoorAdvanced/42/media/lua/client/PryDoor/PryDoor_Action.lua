require "TimedActions/ISBaseTimedAction"
require "PryDoor/PryDoor_Config"
require "PryDoor/PryDoor_Utils"

PryDoorAction = ISBaseTimedAction:derive("PryDoorAction")

local Config=PryDoor.Config
local Utils=PryDoor.Utils

function PryDoorAction:new(player,obj,tool,objType,vehicle,part)
    local o=ISBaseTimedAction.new(self,player)
    o.object=obj; o.tool=tool; o.objType=objType
    o.vehicle=vehicle; o.vehiclePart=part
    o.maxTime=Config.DURATION[objType] or 150
    return o
end

function PryDoorAction:perform()
    local canAttempt, reason = Utils.canPlayerAttempt(self.character, self.objType)
    if not canAttempt then
        self.character:Say(reason)
        return
    end

    -- Success check
    local success = ZombRand(100) < Utils.calculateSuccessChance(self.character,self.tool,self.objType)*100

    -- Tool durability reduction
    if self.tool and self.tool:getCondition() then
        local cost=Config.TOOL_DURABILITY_COST[self.tool:getFullType()] or 1
        self.tool:setCondition(math.max(0,self.tool:getCondition()-cost))
    end

    if success then
        if self.object then
            self.object:setLocked(false)
            self.object:setLockedByKey(false)
            self.object:sync()
        end
        self.character:Say(Config.MESSAGES.SUCCESS)
        Utils.makeNoise(self.character,self.objType,true)
    else
        Utils.handleFailure(self.character,self.objType)
        Utils.makeNoise(self.character,self.objType,false)
    end

    Utils.applyFatigue(self.character,self.objType)
    ISBaseTimedAction.perform(self)
end

return PryDoorAction
