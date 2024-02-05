local ecs   = ...
local world = ecs.world
local w     = world.w

local ImGui = require "imgui"

local md = {} md.__index = md

local wndflags = ImGui.WindowFlags {
    "NoDocking",
    "NoCollapse",
}

function md.open(materialfile)
    ImGui.Begin("MaterialEditor", nil, wndflags) do
        
        ImGui.End()
    end
end

return md