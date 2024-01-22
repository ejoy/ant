local ecs   = ...
local world = ecs.world
local w     = world.w

local ImGui = import_package "ant.imgui"

local md = {} md.__index = md

local wndflags = ImGui.Flags.Window {
    "NoDocking",
    "NoCollapse",
}

function md.open(materialfile)
    ImGui.Begin("MaterialEditor", wndflags) do
        
        ImGui.End()
    end
end

return md