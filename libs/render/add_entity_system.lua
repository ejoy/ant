local ecs = ...
local world = ecs.world
local cu = require "render.components.util"
local mu = require "math.util"
local shader_mgr    = require "render.resources.shader_mgr"

local asset     = require "asset"
local bgfx          = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
add_entity_sys.dependby "iup_message"

function add_entity_sys:init()
    do
        local bunny_eid = world:new_entity(table.unpack(cu.get_sceneobj_compoent_names()))
        local bunny = world[bunny_eid]

        -- should read from serialize file
        local ms = self.math_stack
        ms(bunny.scale.v, {1, 1, 1}, "=")
        ms(bunny.position.v, {0, 0, 0, 1}, "=")
        ms(bunny.direction.v, {0, 0, 1, 0}, "=")

        bunny.render = asset.load("bunny.render")
        local bindings = bunny.render.binding        
        assert(#bindings > 0)
        local material = assert(bindings[1].material)
        local uniforms = material.uniform.defines
        local u_time = uniforms.u_time
        u_time.update = function (uniform)
            return 1
        end
    end
    
    do
        local camera_eid = world:new_entity("main_camera", "viewid", "direction", "position", "frustum", "view_rect", "clear_component")
        local camera = world[camera_eid]
        camera.viewid.id = 0
    
        self.math_stack(camera.position.v,    {0, 0, -5, 1},  "=")
        self.math_stack(camera.direction.v,   {0, 0, 1, 0},   "=")

        local frustum = camera.frustum
        mu.frustum_from_fov(frustum, 0.1, 10000, 60, 1)
    end
end