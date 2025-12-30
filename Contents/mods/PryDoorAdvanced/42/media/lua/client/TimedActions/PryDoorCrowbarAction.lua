require "TimedActions/ISBaseTimedAction"

PryDoorCrowbarAction = ISBaseTimedAction:derive("PryDoorCrowbarAction")

function PryDoorCrowbarAction:new(player, door, tool)
    local o = ISBaseTimedAction.new(self, player)
    o.door = door
    o.tool = tool
    o.maxTime = 170
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function PryDoorCrowbarAction:isValid()
    return self.door and self.door:isLocked() and self.character:getInventory():contains(self.tool)
end

function PryDoorCrowbarAction:start()
    self:setActionAnim("RemoveBarricade")
    self:setOverrideHandModels(self.tool, nil)
end

function PryDoorCrowbarAction:perform()
    local sq = self.door:getSquare()
    sendClientCommand(self.character, "PryDoor", "tryPry", {
        x=sq:getX(), y=sq:getY(), z=sq:getZ(),
        tool="crowbar"
    })
    ISBaseTimedAction.perform(self)
end
