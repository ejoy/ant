local ecs = ...

local render_util = require "ant.util"

local mesh_comp = ecs.component "mesh" {
    path = "",
    mesh_ref = nil
}

local mesh_init_sys = ecs.system "mesh_init_system"
mesh_init_sys.singleton "mesh"

function mesh_init_sys:init()
    self.mesh.path = "meshes/bunny.bin"
    self.mesh.mesh = render_util.meshLoad(self.mesh.path)
end