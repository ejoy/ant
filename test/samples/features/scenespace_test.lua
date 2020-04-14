local ecs = ...
local world = ecs.world

local sp_test_sys = ecs.system "scenespace_test_system"
sp_test_sys.require_policy "ant.render|render"
sp_test_sys.require_policy "ant.scene|transform"
sp_test_sys.require_policy "ant.scene|hierarchy"


function sp_test_sys:init()
    local rooteid = world:create_entity{
        policy = {
            "ant.render|name",
        },
        data = {
            name = "root",
        }
    }

    local child1 = world:create_entity{
        policy = {
            "ant.scene|hierarchy",
            "ant.render|render",
            "ant.render|name",
            "ant.render|mesh",
        },
        data = {
            name = "child1",
            parent = rooteid,
            can_render = true,
            rendermesh = {},
            material = "/pkg/ant.resources/depiction/materials/singlecolor.material",
            mesh = "/pkg/ant.resources/depiction/meshes/sphere.mesh",
            transform = {
                srt = {t = {1, 2, 0, 1}},
            },
            scene_entity = true,
        }
    }

    local child1_1 = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.scene|hierarchy",
            "ant.render|name",
            "ant.render|mesh",
        },
        data = {
            name = "child1_1",
            parent = child1,
            scene_entity = true,
            can_render = true,
            rendermesh = {},
            mesh = "/pkg/ant.resources/depiction/meshes/cube.mesh",
            material = "/pkg/ant.resources/depiction/materials/singlecolor.material",
            transform = {srt={
                r = {math.rad(math.cos(30)), 0, 0, math.rad(math.sin(30))}, --rotate 60 degree
                t = {1, 2, 0, 1}
            }}
        }
    }

    local child2 = world:create_entity {
        policy = {
            "ant.render|name",
            "ant.scene|hierarchy",
            "ant.scene|transform",
        },
        data = {
            name = "child2",
            transform = {srt={
                s = {1, 2, 1, 0},
                t = {3, 3, 5},
            }},
            parent = rooteid,
            scene_entity = true,
        }
    }

    local child2_1 = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.scene|hierarchy",
            "ant.render|name",
            "ant.render|mesh",
        },
        data = {
            name = "child2_1",
            parent = child2,
            can_render = true,
            scene_entity = true,
            rendermesh = {},
            material = "/pkg/ant.resources/depiction/materials/singlecolor.material",
            mesh = "/pkg/ant.resources/depiction/meshes/cube.mesh",
            transform = {srt={
                t = {1, 2, 0, 1}
            }},
        }
    }
end