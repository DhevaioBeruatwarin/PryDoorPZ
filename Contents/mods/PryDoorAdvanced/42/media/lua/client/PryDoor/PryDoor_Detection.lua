require "PryDoor/PryDoor_Config"
require "PryDoor/PryDoor_Utils"

PryDoor = PryDoor or {}
PryDoor.Detection = {}

local Utils = PryDoor.Utils
local Config = PryDoor.Config

function PryDoor.Detection.findWorldTarget(player)
    local sq = player:getSquare()
    for dx=-1,1 do for dy=-1,1 do
        local s = getCell():getGridSquare(sq:getX()+dx, sq:getY()+dy, sq:getZ())
        if s then
            local objs = s:getObjects()
            for i=0,objs:size()-1 do
                local obj = objs:get(i)
                if Utils.isLockedWorldObject(obj) then
                    local cat = Utils.getWorldCategory(obj)
                    if cat then return obj, cat end
                end
            end
        end
    end end
end

function PryDoor.Detection.findVehicleTarget(player)
    local sq = player:getSquare()
    for dx=-1,1 do for dy=-1,1 do
        local s = getCell():getGridSquare(sq:getX()+dx, sq:getY()+dy, sq:getZ())
        if s then
            local v = s:getVehicleContainer()
            if v then
                for i=0,v:getPartCount()-1 do
                    local p = v:getPartByIndex(i)
                    if p and p:getDoor() and p:getDoor():isLocked() then
                        return p, v
                    end
                end
            end
        end
    end end
end

return PryDoor.Detection
