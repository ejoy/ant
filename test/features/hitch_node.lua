local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local iom   = ecs.import.interface "ant.objcontroller|iobj_motion"

local hn_test_sys = ecs.system "hitch_node_test_system"
local hitch_test_group_id<const> = 1000
local skeleton_test_group_id<const> = 1001

local function create_simple_test_group()
    local defgroup = ecs.group(0)
    defgroup:create_entity {
        policy = "ant.scene|hitch_object",
        data = {
            scene = {
                t = {0, 3, 0},
            },
            hitch = {
                group = hitch_test_group_id
            },
        }
    }
    defgroup:create_entity {
        policy = "ant.scene|hitch_object",
        data = {
            scene = {
                t = {1, 2, 0},
            },
            hitch = {
                group = hitch_test_group_id
            },
        }
    }
    defgroup:create_entity {
        policy = "ant.scene|hitch_object",
        data = {
            scene = {
                t = {0, 0, 3},
            },
            hitch = {
                group = hitch_test_group_id
            },
        }
    }

    local static_group = ecs.group(hitch_test_group_id)
    --standalone sub tree
    static_group:enable "scene_update"
    local p1 = static_group:create_entity {
        policy = {
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            material = "/pkg/ant.resources.binary/meshes/base/cube.glb|materials/lambert1.001.material",
            visible_state = "main_view",
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
            visible_state = "main_view",
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

local change_hitch_eid

local function create_skeleton_test_group()
    --dynamic
    ecs.create_entity {
        policy = "ant.scene|hitch_object",
        data = {
            scene = {
                s = 0.1,
                t = {0.0, 0.0, -5.0},
            },
            hitch = {
                group = skeleton_test_group_id
            },
        }
    }

    change_hitch_eid = ecs.create_entity {
        policy = "ant.scene|hitch_object",
        data = {
            scene = {
                s = 0.1,
                r = {0.0, 0.8, 0.0},
                t = {5.0, 0.0, 0.0},
            },
            hitch = {
                group = skeleton_test_group_id
            },
        }
    }

    local dynamic_group = ecs.group(skeleton_test_group_id)
    dynamic_group:enable "scene_update"

    local function create_obj(g, file)
        local p = g:create_instance(file)
        p.on_init = function ()
            world:entity(p.root).standalone_scene_object = true
            for _, eid in ipairs(p.tag["*"]) do
                world:entity(eid).standalone_scene_object = true
            end
        end
        world:create_object(p)
    end

    create_obj(dynamic_group, "/pkg/ant.test.features/assets/glb/inserter.glb|mesh.prefab")
    local d2g = ecs.group(skeleton_test_group_id+1)
    d2g:enable "scene_update"
    create_obj(d2g, "/pkg/ant.test.features/assets/glb/headquater.glb|mesh.prefab")
end

function hn_test_sys:init()
    --create_simple_test_group()
    create_skeleton_test_group()
end

local key_mb = world:sub {"keyboard"}
function hn_test_sys:data_changed()
    for _, key, press in key_mb:unpack() do
        if key == "Y" and press == 0 then
            world:entity(change_hitch_eid).hitch.group = skeleton_test_group_id+1
        end
    end
end
