local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"
local bgfx = require "bgfx"

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local ientity   = ecs.import.interface "ant.render|ientity"
local imesh     = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"


local S         = ecs.system "init_system"

local function create_instance(prefab, on_ready)
    local p = ecs.create_instance(prefab)
    p.on_ready = on_ready
    world:create_object(p)
end

local function create_simple_triangles()
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
                    handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fff", {
                        0.0, 0.0, 1.0,
                        0.0, 1.0, 1.0,
                        1.0, 0.0, 1.0,
                        0.0, 0.0, 1.0,
                        1.0, 0.0, 1.0,
                        0.0, 0.0,-1.0,
                    }), declmgr.get "p3".handle)
                },
            },
            material = "/pkg/ant.test.light/assets/materials/default.material",
            visible_state  = "main_view",
            name = "test",
            scene = {},
        }
    }

    -- local p1 = math3d.vector(0.0, 0.0, 1.0)
    -- local p2 = math3d.vector(0.0, 1.0, 2.0)
    -- local p3 = math3d.vector(1.0, 0.0, 2.0)

    -- local n = math3d.normalize(math3d.cross(math3d.sub(p2, p1), math3d.sub(p3, p1)))
    -- print(math3d.tostring(n))
end

local function create_plane()
    ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene = {
                t = {0, 0, 0, 1}, s = {50, 1, 50, 0}
            },
			material 	= "/pkg/ant.resources/materials/mesh_shadow.material",
			visible_state= "main_view",
			name 		= "test_shadow_plane",
			simplemesh 	= imesh.init_mesh(ientity.plane_mesh()),
            debug_mesh_bounding = true,
			on_ready = function (e)
				imaterial.set_property(e, "u_basecolor_factor", math3d.vector(0.8, 0.8, 0.8, 1))
			end,
		}
    }
end

local function raymarch_entity()
    return ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name = "test_raymarch",
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

function S.init()
    create_instance( "/pkg/ant.test.atmosphere/assets/light.prefab", function (e)
        local leid = e.tag['*'][1]
        local le<close> = w:entity(leid, "scene:update")
        iom.set_direction(le, math3d.vector(0.6, -1.0, -0.8))
    end)

    --ientity.create_procedural_sky()
    raymarch_entity()
end

function S.init_world()
    local mq = w:first("main_queue camera_ref:in")
    local camera_ref<close> = w:entity(mq.camera_ref)
    local eyepos = math3d.vector(0, 8, -8)
    iom.set_position(camera_ref, eyepos)
    local dir = math3d.normalize(math3d.sub(math3d.vector(0.0, 0.0, 0.0, 1.0), eyepos))
    iom.set_direction(camera_ref, dir)

    
    -- create_instance("/pkg/ant.test.light/assets/world_simple.glb|mesh.prefab", function (e)
    --     local leid = e.tag['*'][1]
    --     local le<close> = w:entity(leid, "scene:update")
    --     iom.set_scale(le, 0.1)
    -- end)

    --create_simple_triangles()
    -- iom.set_position(camera_ref, math3d.vector(0, 2, -5))
    -- iom.set_direction(camera_ref, math3d.vector(0.0, 0.0, 1.0))
end

function S:camera_usage()
 
end
