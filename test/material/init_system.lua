local ecs   = ...
local world = ecs.world
local w     = world.w

local imesh     = ecs.import.interface "ant.asset|imesh"
local imateral  = ecs.import.interface "ant.asset|imaterial"

local is = ecs.system "init_system"

function is:init()
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            scene = {srt={}},
            material = "/pkg/ant.test.material/assets/test.material",
            simplemesh = imesh.init_mesh{
                vb = {
                    start = 0,
                    num = 4,
                    {
                        declname = "p2|t2",
                        memory = {"ffff", {
                            -0.1,  0.1, 0.0, 0.0,
                             0.1,  0.1, 0.0, 1.0,
                            -0.1, -0.1, 0.0, 0.0,
                             0.1, -0.1, 0.0, 1.0,
                        }},
                    }
                }
            },
            owned_mesh_buffer = true,
            filter_state = "main_view",
            name = "test_material",
            on_ready = function (e)
                w:sync("render_object:in", e)
                local math3d = require "math3d"
                --local aa = e.render_object.material.material:attribs()
                imateral.set_property(e, "u_color", math3d.vector(1, 0, 0, 1))
            end
        }
    }
end

function is:init_world()

end

function is:data_changed()

end