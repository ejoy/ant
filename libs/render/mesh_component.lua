local ecs = ...
local world = ecs.world

local mesh_comp = ecs.component "mesh" {
    attributes = {type = "asset", "libs/render/material/data_def/default.mesh"} 
}

function mesh_comp:init()
    self.handle = -1
end

