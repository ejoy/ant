local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx = require "bgfx"

local imesh     = ecs.import.interface "ant.asset|imesh"
local irender   = ecs.import.interface "ant.render|irender"

local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr
local is = ecs.system "init_system"

function is:init()
    ecs.create_entity{
        policy = {
            "ant.test.material|simplerender2",
            "ant.general|name",
        },
        data = {
            scene = {srt={}},
            cmaterial = "/pkg/ant.test.material/assets/test.material",
            simplemesh = imesh.init_mesh({
                ib = {
                    start = 0,
                    num = 6,
                    handle = irender.quad_ib(),
                },
                vb = {
                    start = 0,
                    num = 4,
                    {
                        handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("ffff", {
                            100, 200, 0.0, 0.0,
                            100, 132, 0.0, 1.0,
                            420, 200, 1.0, 0.0,
                            420, 132, 1.0, 1.0,
                        }), declmgr.get "p2|t2".handle)
                    }
                }
            }, true),
            filter_state = "main_view",
            name = "test_material",
        }
    }
end

function is:init_world()

end

function is:data_changed()

end