local ecs = ...
local world = ecs.world

local math3d    = require "math3d"

local computil = ecs.import.interface "ant.render|entity"

local char_ik_test_sys = ecs.system "character_ik_test_system"
local imaterial = ecs.import.interface "ant.asset|imaterial"

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
            collider = {
                box = {{
                    origin = {0, 0, 0, 1},
                    size = {5, 0.001, 5},
                }}
            },
        },
        ["ant.render|debug_mesh_bounding"] = {
            debug_mesh_bounding = true,
        }
    })

    imaterial.set_property(eid, "u_color", {0.5, 0.5, 0, 1})
    return eid
end

function char_ik_test_sys:init()
    create_plane_test()
    foot_ik_test()
end