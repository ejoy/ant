local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"
local bgfx = require "bgfx"

local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant

local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local assetmgr = import_package "ant.asset"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local S = ecs.system "init_system"

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"

local function create_instance(prefab, on_ready)
    local p = ecs.create_instance(prefab)
    p.on_ready = on_ready
    world:create_object(p)
end

local function create_simple_triangles()
    -- local function add_v(vertices, p, n, t)
    --     local px, py, pz = math3d.index(p, 1, 2, 3)
    --     local q = mu.pack_tangent_frame(n, t)
    --     vertices[#vertices+1] = px
    --     vertices[#vertices+1] = py
    --     vertices[#vertices+1] = py

    --     local qx, qy, qz, qw = math3d.index(q, 1, 2, 3, 4)
    --     vertices[#vertices+1] = qx
    --     vertices[#vertices+1] = qy
    --     vertices[#vertices+1] = qz
    --     vertices[#vertices+1] = qw
    -- end
    -- local vertices = {}
    -- local n, t = math3d.normalize(math3d.vector(1, 10, 0)), math3d.normalize(math3d.vector(1.0, 0.0, 0.0))
    -- add_v(vertices, math3d.vector(0.0, 0.0, 0.0), n, t)
    -- add_v(vertices, math3d.vector(0.0, 0.0, 1.0), n, t)
    -- add_v(vertices, math3d.vector(1.0, 0.0, 0.0), n, t)
    local nx, ny, nz = math3d.index(math3d.normalize(math3d.vector(1, 10, 0.0)), 1, 2, 3, 4)
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            simplemesh = {
                vb = {
                    start = 0,
                    num = 6,
                    handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fffffffffff", {
                        0.0, 0.0, 0.0, nx, ny, nz, 1.0, 0.0, 0.0, 0.0, 1.0,
                        0.0, 0.0, 1.0, nx, ny, nz, 1.0, 0.0, 0.0, 0.0, 0.0,
                        1.0, 0.0, 1.0, nx, ny, nz, 1.0, 0.0, 0.0, 1.0, 1.0,
                        1.0, 0.0, 1.0, nx, ny, nz, 1.0, 0.0, 0.0, 1.0, 1.0,
                        1.0, 0.0, 0.0, nx, ny, nz, 1.0, 0.0, 0.0, 1.0, 0.0,
                        0.0, 0.0, 0.0, nx, ny, nz, 1.0, 0.0, 0.0, 0.0, 1.0,
                    }), declmgr.get "p3|n3|T3|t2".handle)
                },
            },
            material = "/pkg/ant.test.light/assets/materials/default.material",
            visible_state  = "main_view",
            render_layer = "opacity",
            name = "test",
            scene = {
                r = {0.0, 0.0, 0.8}
            },
        }
    }

    -- local p1 = math3d.vector(0.0, 0.0, 1.0)
    -- local p2 = math3d.vector(0.0, 1.0, 2.0)
    -- local p3 = math3d.vector(1.0, 0.0, 2.0)

    -- local n = math3d.normalize(math3d.cross(math3d.sub(p2, p1), math3d.sub(p3, p1)))
    -- print(math3d.tostring(n))
end

function S.init()
    create_instance( "/pkg/ant.test.light/assets/light.prefab", function (e)
        --local leid = e.tag['*'][1]
        --local le<close> = w:entity(leid, "scene:update")
        --iom.set_direction(le, math3d.vector(1.0, 1.0, 1.0))
    end)

    --ecs.create_instance "/pkg/ant.test.light/assets/skybox.prefab"
end

local peids

function S.init_world()
    local mq = w:first("main_queue camera_ref:in")
    local camera_ref<close> = w:entity(mq.camera_ref)
    local eyepos = math3d.vector(0, 8, -8)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(math3d.vector(0.0, 0.0, 0.0, 1.0), eyepos))
    iom.set_direction(camera_ref, dir)

    -- create_simple_triangles()

    -- create_instance("/pkg/ant.test.light/assets/building_station.prefab", function (e)
    --     local leid = e.tag['*'][1]
    --     local le<close> = w:entity(leid, "scene:update")
    --     iom.set_scale(le, 0.1)
    -- end)

    create_instance("/pkg/ant.test.light/assets/world_simple.glb|mesh.prefab", function (e)
        peids = e.tag['*']
        local leid = e.tag['*'][1]
        local le<close> = w:entity(leid, "scene:update")
        iom.set_scale(le, 0.1)
    end)

    -- create_instance("/pkg/ant.test.light/assets/plane.glb|mesh.prefab", function (e)
    --     local normaltex = assetmgr.resource "/pkg/ant.test.light/assets/normal.texture"
    --     local leidobj = e.tag['*'][2]
    --     local obj<close> = w:entity(leidobj)

    --     imaterial.set_property(obj, "s_normal", normaltex.id)
    -- end)

    -- create_instance("/pkg/ant.test.light/assets/ground_01.glb|mesh.prefab", function (e)
    --     local leid = e.tag['*'][1]
    --     local le<close> = w:entity(leid, "scene:update")
    --     iom.set_scale(le, 0.1)
    --     iom.set_position(le, math3d.vector(5, 0, 0))
    -- end)

    -- ecs.create_entity{
    --     policy = {
    --         "ant.render|render",
    --         "ant.general|name",
    --     },
    --     data = {
    --         material = "/pkg/ant.test.light/assets/materials/default.material",
    --         mesh = "/pkg/ant.test.light/assets/ground_01.glb|meshes/Plane.007_P1.meshbin",
    --         name = "ground_01",
    --         scene = {
    --             s = 0.1
    --         },
    --         visible_state = "main_view",
    --     }
    -- }

    --create_simple_triangles()

    --create_simple_triangles()
    -- iom.set_position(camera_ref, math3d.vector(0, 2, -5))
    -- iom.set_direction(camera_ref, math3d.vector(0.0, 0.0, 1.0))
end

local kb_mb = world:sub{"keyboard"}

function S:data_changed()
    for _, code, press, state in kb_mb:unpack() do
        if code == "T" and press == 0 then
            for _, eid in ipairs(peids) do
                local e<close> = w:entity(eid)
                w:remove(e)
            end
        end
    end
end

function S:camera_usage()
 
end
