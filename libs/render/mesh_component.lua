local ecs = ...
local world = ecs.world

local mesh_comp = ecs.component "mesh" {
    path = "",     
}

function mesh_comp:init()
    self.mesh_ref = -1
end

