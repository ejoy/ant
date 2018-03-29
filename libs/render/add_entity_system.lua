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
    local ms = self.math_stack

    do
        local bunny_eid = world:new_entity(table.unpack(cu.get_sceneobj_compoent_names()))
        local bunny = world[bunny_eid]

        -- should read from serialize file
        
        ms(bunny.scale.v, {0.01, 0.01, 0.01}, "=")
        ms(bunny.position.v, {0, 0, 0, 1}, "=")
        ms(bunny.direction.v, {0, 0, 1, 0}, "=")

        bunny.render = asset.load("bunny.render")        
        local u_time = assert(bunny.render:get_uniform(1, "u_time"))
        u_time.update = function (uniform)
            return 1
        end
    end

    do
        local cube_eid = world:new_entity("direction", "position", "scale", "render")
        local cube = world[cube_eid]
        
        ms(cube.scale.v, {0.01, 0.01, 0.01}, "=")  -- meter to cm
        ms(cube.position.v, {2, 0, 0, 1}, "=") 
        ms(cube.direction.v, {0, 0, 1, 0}, "=")

        local function write_to_memfile(fn, content)
            local f = io.open(fn, "w")
            f:write(content)
            f:close()
        end

        local cuberender_fn = "mem://cube.render"
        write_to_memfile(cuberender_fn, [[
            mesh_name = "cube.mesh"
            binding = {
                {
                    material_name = "obj_trans/obj_trans.material",
                    mesh_groupids = {1},
                },
            }
        ]])
        cube.render = asset.load(cuberender_fn)        
        local u_color = cube.render:get_uniform(1, "u_color")
        u_color.update = function ()
            return {ms({1, 0, 0, 1}, "m")}
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