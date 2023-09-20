local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local imesh     = ecs.require "ant.asset|mesh"


local S         = ecs.system "init_system"

local function create_instance(prefab, on_ready)
    world:create_instance {
        prefab = prefab,
        on_ready = on_ready,
    }
end

local function raymarch_entity()
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh = imesh.init_mesh{
                vb = {
                    start = 0,
                    num = 8,
                    declname = "p4",
                    memory = {"ffff", {
                        -1.0, -1.0, 0.0, 1.0,
                        -1.0,  1.0, 0.0, 1.0,
                         1.0,  1.0, 0.0, 1.0,
                         1.0, -1.0, 0.0, 1.0,
                    }},
                    owned = true,
                },
                ib = {
                    start = 0,
                    num = 6,
                    memory = {"w", {
                        0, 1, 2, 2, 3, 0
                    }},
                    owned = true,
                }
            },
            material = "/pkg/ant.test.atmosphere/assets/raymarch.material",
            scene = {},
            visible_state = "main_view",
        }
    }
end

local function create_precompute_atmosphere_entities()

end

function S.init()
    create_instance( "/pkg/ant.test.atmosphere/assets/light.prefab", function (e)
        local leid = e.tag['*'][1]
        local le<close> = world:entity(leid, "scene:update")
        iom.set_direction(le, math3d.vector(0.6, -1.0, -0.8))
    end)

    create_precompute_atmosphere_entities()

    raymarch_entity()
end

function S.init_world()
    local mq = w:first("main_queue camera_ref:in")
    local camera_ref<close> = world:entity(mq.camera_ref)
    local eyepos = math3d.vector(0, 8, -8)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(math3d.vector(0.0, 0.0, 0.0, 1.0), eyepos))
    iom.set_direction(camera_ref, dir)
end

function S:camera_usage()
 
end
