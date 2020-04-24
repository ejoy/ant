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
        },
        data = {
            name = "root",
        }
    }

    local material = world.component:resource "/pkg/ant.resources/materials/singlecolor.material"

    local child1 = world:create_entity{
        policy = {
            "ant.scene|hierarchy_policy",
            "ant.render|render",
            "ant.general|name",
            "ant.render|mesh",
        },
        data = {
            name = "child1",
            parent = rooteid,
            can_render = true,
            material = material,
            mesh = world.component:resource "/pkg/ant.resources/meshes/sphere.mesh",
            transform = computil.create_transform(world, {srt={t={1, 2, 0, 1}}}),
            scene_entity = true,
        }
    }

    local child1_1 = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.scene|hierarchy_policy",
            "ant.general|name",
            "ant.render|mesh",
        },
        data = {
            name = "child1_1",
            parent = child1,
            scene_entity = true,
            can_render = true,
            mesh = world.component:resource "/pkg/ant.resources/meshes/cube.mesh",
            material = material,
            transform = computil.create_transform(world,
                {srt={
                r = {math.rad(math.cos(30)), 0, 0, math.rad(math.sin(30))}, --rotate 60 degree
                t = {1, 2, 0, 1}}}),
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
            parent = rooteid,
            scene_entity = true,
        }
    }

    local child2_1 = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.scene|hierarchy_policy",
            "ant.general|name",
            "ant.render|mesh",
        },
        data = {
            name = "child2_1",
            parent = child2,
            can_render = true,
            scene_entity = true,
            material = material,
            mesh = world.component:resource "/pkg/ant.resources/meshes/cube.mesh",
            transform = computil.create_transform(world, {srt={t ={1, 2, 0, 1}}}),
        }
    }
end