local ecs = ...
local world = ecs.world
local au = require "asset.util"
local shadermgr = require "render.resources.shader_mgr"
local asset     = require "asset"
local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "constant"

add_entity_sys.depend "constant_init_sys"
add_entity_sys.dependby "iup_message"

function add_entity_sys:init()
    local ms = self.math_stack

    do
        local bunny_eid = world:new_entity("position", "rotation", "scale", "render", "name", "can_select")        
        local bunny = world[bunny_eid]
        bunny.name.n = "bunny"

        -- should read from serialize file
        
        ms(bunny.scale.v, {0.2, 0.2, 0.2, 0}, "=")
        ms(bunny.position.v, {0, 0, 3, 1}, "=")
        ms(bunny.rotation.v, {0, -60, 0, 0}, "=")

        local rinfo = asset.load("bunny.render")

        local utime_setter_tb = {shadermgr.create_uniform_setter("u_time", ~self.constant.colors.red)}
    
        bunny.render.info = rinfo
        bunny.render.uniforms = {utime_setter_tb, utime_setter_tb}
    end

    local cubematerial_fn = "mem://cube_material.material"
    au.write_to_file(cubematerial_fn, [[
        shader = {
            vs = "vs_mesh",
            fs = "fs_mesh",
        }
        state = "default.state"
    ]])

    local cuberender_fn = "mem://cube.render"
    au.write_to_file(cuberender_fn, [[
        mesh = "cube.mesh"
        binding ={material = "mem://cube_material.material",}
        srt = {s={0.01}}
    ]])

    local sphererender_fn = "mem://sphere.render"
    au.write_to_file(sphererender_fn, [[
        mesh = "sphere.mesh"
        binding ={material = "mem://cube_material.material",}
        srt = {s={0.01}}
    ]])
    
    local function create_entity(name, renderfile)
        local cube_eid = world:new_entity("rotation", "position", "scale", "render", "name", "can_select")
        local cube = world[cube_eid]
        cube.name.n = name
        
        ms(cube.scale.v, {1, 1, 1}, "=")
        ms(cube.position.v, {0, 0, 0, 1}, "=") 
        ms(cube.rotation.v, {0, 0, 0}, "=")

        local rinfo = asset.load(renderfile) 
        cube.render.info = rinfo

        local color_setter_tb = {
            shadermgr.create_uniform_setter("u_color", ~self.constant.colors.red), 
            shadermgr.create_uniform_setter("u_time", ~self.constant.colors.green),
        }
        cube.render.uniforms = {color_setter_tb}
        cube.render.visible = true

        return cube_eid
    end

    do
        local hierarchy_eid = world:new_entity("editable_hierarchy", "hierarchy_name_mapper",
            "scale", "rotation", "position", 
            "name")
        local hierarchy_e = world[hierarchy_eid]

        hierarchy_e.name.n = "hierarchy_test"

        ms(hierarchy_e.scale.v, {1, 1, 1}, "=")
        ms(hierarchy_e.rotation.v, {0, 60, 0}, "=")
        ms(hierarchy_e.position.v, {10, 0, 0, 1}, "=")

        local hierarchy = hierarchy_e.editable_hierarchy.root

        hierarchy[1] = {
            name = "h1_cube",
            transform = {
                t = {3, 4, 5},
                s = {1, 1, 1},
            }
        }

        hierarchy[2] = {
            name = "h1_sphere",
            transform = {
                t = {1, 2, 3},
                s = {1, 1, 1},
            }
        }

        hierarchy[1][1] = {
            name = "h1_h1_cube",
            transform = {
                t = {3, 3, 3},
                s = {1, 1, 1},
            }
        }


        local cube_eid = create_entity("h1_cube", cuberender_fn)
        local cube_eid_1 = create_entity("h1_h1_cube", cuberender_fn)
        do
            local e = world[cube_eid_1] 
            ms(e.scale.v, {0.5, 0.5, 0.5}, "=")
        end

        local sphere_eid = create_entity("h1_sphere", sphererender_fn)
        local name_mapper = assert(hierarchy_e.hierarchy_name_mapper.v)

        name_mapper.h1_cube     = cube_eid
        name_mapper.h1_h1_cube  = cube_eid_1
        name_mapper.h1_sphere   = sphere_eid
    end
end