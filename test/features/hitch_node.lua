local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local iom   = ecs.import.interface "ant.objcontroller|iobj_motion"

local hn_test_sys = ecs.system "hitch_node_test_system"
local hitch_test_group_id<const> = 1000
local skeleton_test_group_id<const> = 1001

local function create_static_group()
    ecs.create_entity{
        policy = {
            "ant.scene|hitch_object",
            "ant.general|name",
        },
        data = {
            name = "hitch_scene_test1",
            scene = {
                t = {0, 3, 0},
            },
            hitch = {
                group = hitch_test_group_id,
            },
        }
    }

    ecs.create_entity{
        policy = {
            "ant.scene|hitch_object",
            "ant.general|name",
        },
        data = {
            name = "hitch_scene_test2",
            scene = {
                t = {1, 2, 0},
            },
            hitch = {
                group = hitch_test_group_id,
            },
        }
    }

    ecs.create_entity{
        policy = {
            "ant.scene|hitch_object",
            "ant.general|name",
        },
        data = {
            name = "hitch_scene_test3",
            scene = {
                t = {0, 0, 3},
            },
            hitch = {
                group = hitch_test_group_id,
            },
        }
    }

    local static_group = ecs.group(hitch_test_group_id)
    --standalone sub tree
    local p1 = static_group:create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/lambert1.001.material",
            filter_state = "main_view",
            scene = {},
            on_ready = function (e)
                w:sync("scene:in id:in", e)
                iom.set_position(e, math3d.vector(0, 2, 0))
                iom.set_scale(e, 3)
                w:sync("scene:out", e)
            end,
            standalone_scene_object=true,
            name = "virtual_node_p1",
        },
    }

    static_group:create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cone.glb|materials/lambert1.material",
            filter_state = "main_view",
            scene = {
                parent = p1,
            },
            on_ready = function (e)
                w:sync("scene:in id:in", e)
                iom.set_position(e, math3d.vector(1, 2, 3))
                w:sync("scene:out", e)
            end,
            standalone_scene_object = true,
            name = "virtual_node",
        },
    }
end

local function create_dynamic_group()
    --dynamic
    ecs.create_entity{
        policy = {
            "ant.scene|hitch_object",
            "ant.general|name",
        },
        data = {
            name = "virtual_scene_test1",
            scene = {
                s = 0.1,
                t = {0, 0, 0},
            },
            hitch = {
                group = skeleton_test_group_id,
            },
        }
    }
    local dynamic_group = ecs.group(skeleton_test_group_id)
    local p = dynamic_group:create_instance "/pkg/ant.test.features/assets/glb/inserter.glb|mesh.prefab"
    p.on_init = function ()
        for eid in ipairs(p.tag["*"]) do
            world:entity(eid).standalone_scene_object = true
        end
    end
    p.on_ready = function (e)
        iom.set_scale(world:entity(e.root), 0.1)
    end
    world:create_object(p)
end

function hn_test_sys:init()
    create_static_group()
    create_dynamic_group()
end
