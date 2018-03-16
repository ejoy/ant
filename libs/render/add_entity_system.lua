local ecs = ...
local world = ecs.world
local cu = require "render.components.util"
local mu = require "math.util"
local mesh_util     = require "render.resources.mesh_util"
local shader_mgr    = require "render.resources.shader_mgr"

local asset_lib     = require "asset"
local bgfx          = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "viewport"

function add_entity_sys:init()
    do
        local bunny_eid = world:new_entity(table.unpack(cu.get_sceneobj_compoent_names()))
        local bunny = world[bunny_eid]

        -- should read from serialize file
        local ms = self.math_stack
        ms(bunny.scale.v, {1, 1, 1}, "=")
        ms(bunny.position.v, {0, 0, 0, 1}, "=")
        ms(bunny.direction.v, {0, 0, 1, 0}, "=")

        bunny.render = asset_lib["test/simplerender/bunny.render"]
    
        -- bind the update function. this update should add by material editor
        local uniforms = bunny.render.material.uniform
        local u_time = uniforms.u_time
        assert(u_time, "need define u_time uniform")

        u_time.update = function (self)
            if self.value == nil then
                self.value = 0
            end

            self.value = self.value + 1
            return self.value
        end
    end
    
    do
        local camera_eid = world:new_entity(table.unpack(cu.get_camera_component_names()))
        local camera = world[camera_eid]
        camera.viewid.id = 0

        local vp = self.viewport
        local ci = vp.camera_info
    
        self.math_stack(camera.position.v,    assert(ci.default.eye),         "=")
        self.math_stack(camera.direction.v,   assert(ci.default.direction),   "n=")

        local frustum = camera.frustum
        mu.frustum_from_fov(frustum, ci.near, ci.far, ci.fov, vp.width/vp.height)
    end
end