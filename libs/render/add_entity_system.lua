local ecs = ...
local world = ecs.world
local render_util   = require "render.render_util"
local mesh_util     = require "render.resources.mesh_util"
local shader_mgr    = require "render.resources.shader_mgr"

local material_util = require "render.material.material_data_def"
local bgfx          = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math3d"

function add_entity_sys:init()
    print("add_entity_sys:init")

    do
        local bunny_eid = world:new_entity("worldmat_comp", "material", "mesh")
        local bunny = world[bunny_eid]

        local function mesh_init(mesh)
            local mesh_path = "assets/meshes/bunny.bin"
            mesh.path = mesh_path
            mesh.mesh_ref = mesh_util.meshLoad(mesh_path)
    
            assert(mesh.mesh_ref ~= nil and mesh.mesh_ref.group and #mesh.mesh_ref.group >0)
        end

        mesh_init(bunny.mesh)

        local function shader_init(shader)
            shader.vs_path = "vs_mesh"  
            shader.ps_path = "fs_mesh"
            
            shader.prog = shader_mgr.programLoad(shader.vs_path, shader.ps_path)
            if shader.prog == nil then
                print("create shader failed")
            end
        end

        shader_init(bunny.material.shader)

        local function uniform_init(uniforms)
            local uniform = material_util.create_uniform_data()
            uniform.name = "u_time"
            uniform.type = "v4"
            local time = 0
            uniform.value_calculator = function ()
                time = time + 1
                return {time}
            end
            uniform.uniform_id = bgfx.create_uniform(uniform.name, uniform.type)
            uniforms[uniform.name] = uniform
        end

        uniform_init(bunny.material.uniforms)
    end
    
    do
        local camera_eid = world:new_entity("view_transform", "frustum")
        local camera = world[camera_eid]
        local vt = camera.view_transform
        vt.eye 			= self.math3d({0, 10, -10, 1}, "M")
        vt.direction 	= self.math3d({0, 1, 1, 0}, "M")

        -- vt.eye 			= self.math3d({0, 0, 0, 1}, "M")
        -- vt.direction 	= self.math3d({0, 0, 1, 0}, "M")

        camera.frustum.projMat = self.math3d({type = "proj", fov = 90, aspect = 1024/768, n = 0.1, f = 10000}, "M")
    end
end