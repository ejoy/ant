local ecs   = ...
local world = ecs.world
local w     = world.w

local imesh     = ecs.require "ant.asset|mesh"
local imaterial = ecs.require "ant.asset|material"
local is = ecs.system "init_system"

function is:init()
    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            scene = {srt={}},
            material = "/pkg/ant.test.material/assets/test.material",
            render_layer = "translcuent",
            simplemesh = imesh.init_mesh{
                vb = {
                    start = 0,
                    num = 4,
                    declname = "p2|t2",
                    memory = {"ffff", {
                        -0.1,  0.1, 0.0, 0.0,
                            0.1,  0.1, 0.0, 1.0,
                        -0.1, -0.1, 1.0, 0.0,
                            0.1, -0.1, 1.0, 1.0,
                    }},
                    owned = true,
                }
            },
            owned_mesh_buffer = true,
            visible_state = "main_view",
            on_ready = function (e)
                local math3d = require "math3d"
                --local aa = e.render_object.material.material:attribs()
                imaterial.set_property(e, "u_color", math3d.vector(1, 0, 0, 1))
            end
        }
    }
end

function is:init_world()

end

function is:data_changed()

end