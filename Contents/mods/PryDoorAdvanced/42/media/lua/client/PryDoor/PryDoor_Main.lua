require "PryDoor_Config"
require "PryDoor_Utils"
require "PryDoor_Detection"
require "PryDoor_Action"
require "PryDoor_Network"
require "PryDoor_Keybind"

Events.OnGameStart.Add(function()
    print("PRY DOOR ADVANCED v"..PryDoor.Config.VERSION.." loaded")
end)
