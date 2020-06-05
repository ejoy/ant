local ecs = ...
local world = ecs.world

local sp_test_sys = ecs.system "scenespace_test_system"

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

function sp_test_sys:init()
    local rooteid = world:create_entity{
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy",
        },
        data = {
            name = "root",
            transform = computil.create_transform(world, {
                srt={t={0, 1, 0, 1}}
            })
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
            can_render = true,
            material = material,
            mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/sphere.glb|meshes/pSphere1_P1.meshbin",
            transform = computil.create_transform(world, {
                srt={
                    s = {100,},
                    t={1, 2, 0, 1},
                }
            }),
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
            can_render = true,
            mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            material = material,
            transform = computil.create_transform(world, {
                srt = {
                    s = {100,},
                    r = {math.rad(math.cos(30)), 0, 0, math.rad(math.sin(30))}, --rotate 60 degree
                    t = {1, 2, 0, 1}
                }
            }),
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
            transform = computil.create_transform(world,
                { srt = {s = {1, 2, 1, 0},
                t = {3, 3, 5}}}),
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
            can_render = true,
            scene_entity = true,
            material = material,
            mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
            transform = computil.create_transform(world, {
                srt={
                    s = {100,},
                    t ={1, 2, 0, 1}
                }
            }),
        },
        action = {
            mount = child2,
        }
    }
end