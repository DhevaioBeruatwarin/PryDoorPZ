PryDoor = PryDoor or {}
PryDoor.Network = {}

local function onServerCommand(module,command,args)
    if module~="PryDoor" then return end
end

Events.OnServerCommand.Add(onServerCommand)
return PryDoor.Network
