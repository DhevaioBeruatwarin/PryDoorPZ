require "TimedActions/ISBaseTimedAction"

PryDoorScrewdriverAction = ISBaseTimedAction:derive("PryDoorScrewdriverAction")

function PryDoorScrewdriverAction:new(player, door, tool)
    local o = ISBaseTimedAction.new(self, player)
    o.door = door
    o.tool = tool
    o.maxTime = 250
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function PryDoorScrewdriverAction:isValid()
    return self.door and self.door:isLocked() and self.character:getInventory():contains(self.tool)
end

function PryDoorScrewdriverAction:start()
    self:setActionAnim("Disassemble")
    self:setOverrideHandModels(self.tool, nil)
end

function PryDoorScrewdriverAction:perform()
    local sq = self.door:getSquare()
    sendClientCommand(self.character, "PryDoor", "tryPry", {
        x=sq:getX(), y=sq:getY(), z=sq:getZ(),
        tool="screwdriver"
    })
    ISBaseTimedAction.perform(self)
end
