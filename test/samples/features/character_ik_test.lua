local ecs = ...
local world = ecs.world

local serialize = import_package "ant.serialize"
local fs = require "filesystem"

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util
local math3d    = require "math3d"

local renderpkg = import_package "ant.render"
local computil  = renderpkg.components

local utilitypkg= import_package "ant.utility"
local fs_util = utilitypkg.fs_util

local char_ik_test_sys = ecs.system "character_ik_test_system"

local entitydir = fs.path "/pkg/ant.test.features/assets/entities"

local function v4(...)return world.component:vector(...)end

local function foot_ik_test()
    return world:create_entity(fs_util.read_file(entitydir / "character_ik_test.txt"))
end

local function create_plane_test()
    return computil.create_plane_entity(world,
    {srt = {
        s = {5, 1, 5, 0},
        r = math3d.tovalue(math3d.quaternion{math.rad(10), 0, 0}),
        t = {0, 0, -5, 1}
    }},
    "/pkg/ant.resources/materials/test/singlecolor_tri_strip.material",
    {0.5, 0.5, 0, 1},
    "test shadow plane",
    {
        ["ant.collision|collider_policy"] = {
            collider = world.component:collider{
                box = {
                    world.component:box_shape{
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
end

function char_ik_test_sys:init()
    create_plane_test()
    foot_ik_test()
end