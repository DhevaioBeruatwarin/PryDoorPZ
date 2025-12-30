require "TimedActions/ISBaseTimedAction"

PryDoorAxeAction = ISBaseTimedAction:derive("PryDoorAxeAction")

function PryDoorAxeAction:new(player, door, tool)
    local o = ISBaseTimedAction.new(self, player)
    o.door = door
    o.tool = tool
    o.maxTime = 120
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function PryDoorAxeAction:isValid()
    return self.door and self.door:isLocked() and self.character:getInventory():contains(self.tool)
end

function PryDoorAxeAction:start()
    self:setActionAnim("AttackDoor")
    self:setOverrideHandModels(self.tool, nil)
end

function PryDoorAxeAction:perform()
    local sq = self.door:getSquare()
    sendClientCommand(self.character, "PryDoor", "tryPry", {
        x=sq:getX(), y=sq:getY(), z=sq:getZ(),
        tool="axe"
    })
    ISBaseTimedAction.perform(self)
end
