local ecs = ...
local world = ecs.world
local cu = require "render.components.util"
local mu = require "math.util"
local ru = require "render.util"
local au = require "asset.util"

local asset     = require "asset"
local bgfx          = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
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
        local uniforms = {}
        for i=1, #rinfo do           
            local binding = rinfo[i].binding            
            for j=1, #binding do
                local material = binding[j].material
                -- we need to share the uniform
                local mname = material.name                
                if uniforms[mname] == nil then
                    uniforms[mname] = {
                        u_time = ru.create_uniform("u_time", "v4", 1)
                    }
                end                
            end
        end
    
        bunny.render.info = rinfo
        bunny.render.uniforms = uniforms
    end

    do
        local cube_eid = world:new_entity("rotation", "position", "scale", "render", "name", "can_select")
        local cube = world[cube_eid]
        cube.name.n = "cube"
        
        ms(cube.scale.v, {1, 1, 1}, "=")
        ms(cube.position.v, {0, 0, 0, 1}, "=") 
        ms(cube.rotation.v, {0, 0, 1, 0}, "=")



        local cuberender_fn = "mem://cube.render"
        au.write_to_file(cuberender_fn, [[
            mesh = "cube.mesh"
            binding ={material = "obj_trans/obj_trans.material",}
            srt = {s={0.01}}
        ]])

        local rinfo = asset.load(cuberender_fn) 
        cube.render.info = rinfo

        local material = rinfo[1].binding[1].material
        local uniforms = {}
        uniforms[material.name] = {u_color = ru.create_uniform("u_color", "v4", nil, function (uniform) uniform.value = ms({1, 0, 0, 1}, "m") end)}
        cube.render.uniforms = uniforms
        cube.render.visible = false
    end
end