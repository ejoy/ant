local ecs = ...
local world = ecs.world
local render_util = require "lbgfx.util"

local mesh_comp = ecs.component "mesh" {
    path = "", 
    mesh_ref = {type="userdata", {}}
}

