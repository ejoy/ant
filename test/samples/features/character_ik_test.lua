local ecs = ...
local world = ecs.world

local math3d    = require "math3d"

local computil = world:interface "ant.render|entity"

local char_ik_test_sys = ecs.system "character_ik_test_system"

local function v4(...)return world.component "vector"(...)end

local function foot_ik_test()
    --return world:instance((entitydir / "character_ik_test.prefab"):string())
end

local function create_plane_test()
    local eid = computil.create_plane_entity(
    {
        s = {5, 1, 5, 0},
        r = math3d.tovalue(math3d.quaternion{math.rad(10), 0, 0}),
        t = {0, 0, -5, 1}
    },
    "/pkg/ant.resources/materials/test/singlecolor_tri_strip.material",
    "test shadow plane",
    {
        ["ant.collision|collider_policy"] = {
            collider = world.component "collider" {
                box = {
                    world.component "box_shape" {
                        origin = v4{0, 0, 0, 1},
                        size = {5, 0.001, 5},
                    }
                }
            },
        },
        ["ant.render|debug_mesh_bounding"] = {
            debug_mesh_bounding = true,
        }
    })

    world:set(eid, "material", {properties={u_color=world.component "vector"{0.5, 0.5, 0, 1}}})
    return eid
end

function char_ik_test_sys:init()
    create_plane_test()
    foot_ik_test()
end