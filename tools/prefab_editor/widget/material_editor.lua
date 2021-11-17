local ecs   = ...
local world = ecs.world
local w     = world.w

local imgui = require "imgui"

local md = {} md.__index = md

local wndflags = imgui.flags.Window {
    "NoDocking",
    "NoCollapse",
}

function md.open(materialfile)
    imgui.windows.Begin("MaterialEditor", wndflags) do
        
        imgui.windows.End()
    end
end

return md