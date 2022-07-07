local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d= require "math3d"

local iom   = ecs.import.interface "ant.objcontroller|iobj_motion"

local vn_test_sys = ecs.system "virtual_node_test_system"
local test_group<const> = 1000
function vn_test_sys:init()
    ecs.create_entity{
        policy = {
            "ant.scene|virtual_scene_object",
            "ant.general|name",
        },
        data = {
            name = "virtual_scene_test1",
            scene = {
                t = {0, 3, 0},
            },
            virtual_scene = {
                group = test_group,
            },
        }
    }

    ecs.create_entity{
        policy = {
            "ant.scene|virtual_scene_object",
            "ant.general|name",
        },
        data = {
            name = "virtual_scene_test1",
            scene = {
                t = {1, 2, 0},
            },
            virtual_scene = {
                group = test_group,
            },
        }
    }

    ecs.create_entity{
        policy = {
            "ant.scene|virtual_scene_object",
            "ant.general|name",
        },
        data = {
            name = "virtual_scene_test1",
            scene = {
                t = {0, 0, 3},
            },
            virtual_scene = {
                group = test_group,
            },
        }
    }

    local g1000 = ecs.group(test_group)
    --standalone sub tree
    local p1 = g1000:create_entity {
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
            static_scene_object=true,
            name = "virtual_node_p1",
        },
    }

    g1000:create_entity {
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
            static_scene_object = true,
            name = "virtual_node",
        },
    }

    g1000:enable "view_visible"
end
