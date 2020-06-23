local ecs = ...
local world = ecs.world

local sp_test_sys = ecs.system "scenespace_test_system"

local ies = world:interface "ant.scene|ientity_state"

local function material_hierarchy_test()
    local root = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.render|render",
        },
        data = {
            name = "hierarhcy_root",
            material = world.component "resource"("/pkg/ant.resources/materials/bunny.material")
        }
    }

    local ceid = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render",
        },
        data = {
            name = "hierarchy_child",
            mesh = world.component "resource" ("/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin"),
            state = ies.create_state "visible",
            transform = {s = {10}, t = {5, 0, 0}}
        },
        action = {
            mount=root,
        }
    }

    
    local ceid2 = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render",
        },
        data = {
            name = "hierarchy_child_2",
            mesh = world.component "resource" ("/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin"),
            state = ies.create_state "visible",
            transform = {s = {10}, t = {5, 0, 0}},
        },
        action = {
            mount=root,
        }
    }

    local ceid2_1 = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.render|render",
        },
        data = {
            name = "hierarchy_child",
            mesh = world.component "resource" ("/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin"),
            state = ies.create_state "visible",
            transform = {s = {10}, t = {5, 0, 0}},
        },
        action = {
            mount=ceid2,
        }
    }
end

local function space_test()
    local rooteid = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy",
        },
        data = {
            name = "root",
            transform =  {t={0, 1, 0, 1}},
            scene_entity = true,
        }
    }

    local material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material"

    local child1 = world:create_entity{
        policy = {
            "ant.scene|hierarchy_policy",
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            name = "child1",
            material = material,
            mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/sphere.glb|meshes/pSphere1_P1.meshbin",
            transform =  {
                s = {100,},
                t={1, 2, 0, 1},
            },
            state = ies.create_state "visible|selectable",
            scene_entity = true,
        },
        action = {
            mount=rooteid
        }
    }

    local child1_1 = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.scene|hierarchy_policy",
            "ant.general|name",
        },
        data = {
            name = "child1_1",
            scene_entity = true,
            state = ies.create_state "visible|selectable",
            mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            material = material,
            transform =  {
                s = {100,},
                r = {math.rad(math.cos(30)), 0, 0, math.rad(math.sin(30))}, --rotate 60 degree
                t = {1, 2, 0, 1}
            },
        },
        action = {
            mount= child1
        }
    }

    local child2 = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|hierarchy_policy",
            "ant.scene|transform_policy",
        },
        data = {
            name = "child2",
            transform =  {
                s = {1, 2, 1, 0},
                t = {3, 3, 5}
            },
            scene_entity = true,
        },
        action = {
            mount=rooteid
        }
    }

    local child2_1 = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.scene|hierarchy_policy",
            "ant.general|name",
        },
        data = {
            name = "child2_1",
            state = ies.create_state "visible|selectable",
            scene_entity = true,
            material = material,
            mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            transform =  {
                s = {100,},
                t ={1, 2, 0, 1}
            },
        },
        action = {
            mount = child2,
        }
    }
end

function sp_test_sys:init()
    space_test()
    --material_hierarchy_test()
end