local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"

local S = ecs.system "init_system"

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"

local function create_instance(prefab, on_ready)
    local p = ecs.create_instance(prefab)
    p.on_ready = on_ready
    world:create_object(p)
end

function S.init()
    create_instance( "/pkg/ant.test.light/assets/light.prefab", function (e)
        local leid = e.tag['*'][1]
        local le<close> = w:entity(leid, "scene:update")
        iom.set_direction(le, math3d.vector(0.6, -1.0, -0.8))
    end)

    create_instance("/pkg/ant.test.light/assets/world_simple.glb|mesh.prefab", function (e)
        local leid = e.tag['*'][1]
        local le<close> = w:entity(leid, "scene:update")
        iom.set_scale(le, 0.1)
    end)

    ecs.create_instance "/pkg/ant.test.light/assets/skybox.prefab"
end

function S.init_world()
    local mq = w:first("main_queue camera_ref:in")
    local eyepos = math3d.vector(0, 8, -8)
    local camera_ref<close> = w:entity(mq.camera_ref)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(math3d.vector(0.0, 0.0, 0.0, 1.0), eyepos))
    iom.set_direction(camera_ref, dir)
end
