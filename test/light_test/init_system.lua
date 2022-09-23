local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"
local bgfx = require "bgfx"

local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

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

    -- create_instance("/pkg/ant.test.light/assets/world_simple.glb|mesh.prefab", function (e)
    --     local leid = e.tag['*'][1]
    --     local le<close> = w:entity(leid, "scene:update")
    --     iom.set_scale(le, 0.1)
    -- end)

    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = {
                vb = {
                    start = 0,
                    num = 3,
                    handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fff", {
                        0.0, 0.0, 1.0,
                        0.0, 1.0, 1.0,
                        1.0, 0.0, 1.0
                    }), declmgr.get "p3".handle)
                },
            },
            material = "/pkg/ant.test.light/assets/materials/default.material",
            visible_state  = "main_view",
            name = "test",
            scene = {},
        }
    }
    ecs.create_instance "/pkg/ant.test.light/assets/skybox.prefab"
end

function S.init_world()
    local mq = w:first("main_queue camera_ref:in")
    local camera_ref<close> = w:entity(mq.camera_ref)
    local eyepos = math3d.vector(0, 0, 0) --8, -8)
    iom.set_position(camera_ref, eyepos)
    --local dir = math3d.normalize(math3d.sub(math3d.vector(0.0, 0.0, 0.0, 1.0), eyepos))
    iom.set_direction(camera_ref, math3d.vector(0.0, 0.0, 1.0))
end

function S:camera_usage()
    local mq = w:first("main_queue camera_ref:in")
    local ce<close> = w:entity(mq.camera_ref, "camera:in")
    local viewmat = ce.camera.viewmat
    local pVS = math3d.transform(viewmat, math3d.vector(0.0, 0.0, 1.0, 1.0), 1.0)
    local projmat = ce.camera.projmat

    local pCS = math3d.transform(projmat, pVS, 1.0)
    local pNDC = math3d.mul(pCS, 1.0 / math3d.index(pCS, 4))
    
    -- float A = u_proj[2][2];
	-- float B = u_proj[2][3];
    local projc3 = math3d.index(projmat, 3)
    local A, B = math3d.index(projc3, 3, 4)
    local depthNDC = 0.0
    local depthVS = B / (depthNDC - A)
    print(depthVS)

    local pNDC = math3d.vector(0.0, 0.0, 0.0, 1.0)
    local ppVS = math3d.transform(math3d.inverse(projmat), pNDC, 1)
    ppVS = math3d.mul(ppVS, 1.0 / math3d.index(ppVS, 4))
    print(math3d.tostring(pVS))
end
