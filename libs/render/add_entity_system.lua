local ecs = ...
local world = ecs.world
local render_util   = require "render.render_util"
local mesh_util     = require "render.resources.mesh_util"
local shader_mgr    = require "render.resources.shader_mgr"

local asset_lib     = require "asset"
local bgfx          = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math3d"

function add_entity_sys:init()
    do
        local bunny_eid = world:new_entity("worldmat_comp", "material", "mesh")
        local bunny = world[bunny_eid]

        --we should add a lib path for finding file
        bunny.mesh = asset_lib["test/simplerender/bunny.mesh"]
        assert(bunny.mesh.handle)

        local material = bunny.material        
        material.shader = asset_lib["test/simplerender/bunny.shader"]
        assert(material.shader.prog)
    
        material.state = asset_lib["libs/render/material/data_def/default.state"]

        -- we need to put in shader_mgr
        local uniforms = asset_lib["libs/render/material/data_def/global.uniform"]

        -- bind the update function. this update should add by material editor
        local u_time = uniforms.u_time
        assert(u_time, "need define u_time uniform")

        u_time.update = function (self)
            if self.value == nil then
                self.value = 0
            end

            self.value = self.value + 1
            return self.value
        end

        assert(type(material.uniforms) == "table")
        material.uniforms.u_time = u_time
    end
    
    do
        local camera_eid = world:new_entity("view_transform", "frustum")
        local camera = world[camera_eid]
        local vt = camera.view_transform
        
        self.math3d(vt.eye,         {0, 0, -10, 1}, "=")
        self.math3d(vt.direction,   {0, 0, 1, 0},   "=")

        self.math3d(camera.frustum.proj_mat, 
                    {type = "proj", fov = 90, aspect = 1024/768, n = 0.1, f = 10000}, "=")

    end
end