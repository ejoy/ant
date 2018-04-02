local ecs = ...
local world = ecs.world
local cu = require "render.components.util"
local mu = require "math.util"
local ru = require "render.util"

local asset     = require "asset"
local bgfx          = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"
add_entity_sys.singleton "math_stack"
add_entity_sys.dependby "iup_message"

function add_entity_sys:init()
    local ms = self.math_stack

    do
        local bunny_eid = world:new_entity("position", "rotation", "scale", "render", "name")        
        local bunny = world[bunny_eid]
        bunny.name.n = "bunny"

        -- should read from serialize file
        
        ms(bunny.scale.v, {1, 1, 1, 1}, "=")
        ms(bunny.position.v, {0, 0, 0, 1}, "=")
        ms(bunny.rotation.v, {0, 0, 0, 0}, "=")

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
        local cube_eid = world:new_entity("rotation", "position", "scale", "render", "name")
        local cube = world[cube_eid]
        cube.name.n = "cube"
        
        ms(cube.scale.v, {1, 1, 1}, "=")
        ms(cube.position.v, {0, 0, 0, 1}, "=") 
        ms(cube.rotation.v, {0, 0, 1, 0}, "=")

        local function write_to_memfile(fn, content)
            local f = io.open(fn, "w")
            f:write(content)
            f:close()
        end

        local cuberender_fn = "mem://cube.render"
        write_to_memfile(cuberender_fn, [[
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
    end
    
    do
        local camera_eid = world:new_entity("main_camera", "viewid", "rotation", "position", "frustum", "view_rect", "clear_component", "name")        
        local camera = world[camera_eid]
        camera.viewid.id = 0
        camera.name.n = "main_camera"
    
        ms(camera.position.v,    {10, 10, -10, 1},  "=")
        ms(camera.rotation.v,   {45, -45, 0, 0},   "=")

        local frustum = camera.frustum
        mu.frustum_from_fov(frustum, 0.1, 10000, 60, 1)
    end

    do
        local axisid = world:new_entity("rotation", "position", "scale", "render", "name")
        local axis = world[axisid]

        ms(axis.rotation.v, {0, 0, 0, 0}, "=")
        ms(axis.position.v, {0, 0, 0, 1}, "=")
        ms(axis.scale.v, {1, 1, 1}, "=")

        axis.name.n = "axis-tips"
        local material_name = "line.material"

        local vdecl = bgfx.vertex_decl {
                { "POSITION", 3, "FLOAT" },
                { "COLOR0", 4, "UINT8", true }
            }

        local render = axis.render
        render.info = {
            {
                mesh = {
                    handle = {
                        group = {
                            {
                                vdecl = vdecl,
                                vb = bgfx.create_vertex_buffer({"fffd",
                                0.0, 0.0, 0.0, 0xff0000ff,  -- x-axis
                                1.0, 0.0, 0.0, 0xff0000ff,
                                0.0, 0.0, 0.0, 0xff00ff00,  -- y-axis
                                0.0, 1.0, 0.0, 0xff00ff00,
                                0.0, 0.0, 0.0, 0xffff0000,  -- z-axis
                                0.0, 0.0, 1.0, 0xffff0000}, vdecl)
                            },
                        }
                    }
                },
                binding = {{
                    material = asset.load(material_name),
                    meshids = {1}
                }},
                srt = {s={0.2, 0.2, 0.2}, r={0, 0, 0}, t={0, 0, 0}}
            },
        }
    end
end