local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util
local math3d    = require "math3d"

local renderpkg = import_package "ant.render"
local computil  = renderpkg.components

local char_ik_test_sys = ecs.system "character_ik_test_system"

local function v4(...)return world.component:vector(...)end

local function foot_ik_test()

    return world:create_entity {
        policy = {
            "ant.render|render",
            "ant.animation|animation",
            "ant.animation|animation_controller.birth",
            "ant.animation|ozzmesh",
            "ant.animation|ik",
            "ant.animation|ozz_skinning",
            "ant.render|shadow_cast_policy",
            "ant.general|name",
            "ant.character|character",
            "ant.character|foot_ik_raycast",
        },
        data = {
            transform = computil.create_transform(world, {srt = { t= {-2.5, 0, -6, 1}}}),
            material = world.component:resource "/pkg/ant.resources/materials/skin_model_sample.material",
            mesh = world.component:resource '/pkg/ant.resources.binary/meshes/ozz/mesh.ozz',
            skeleton = world.component:resource '/pkg/ant.resources.binary/meshes/ozz/human_skeleton.ozz',
            animation = {
                anilist = {
                    idle = world.component:resource '/pkg/ant.test.features/assets/tmp/animation.ozz',
                },
            },
            animation_birth = "idle",
            ik = {
                jobs = {
                    left_leg = {
                        type        = "two_bone",
                        target      = v4{0, 0, 0, 1},
                        pole_vector = v4{0, 1, 0, 0},
                        mid_axis    = v4{0, 0, 1, 0},
                        weight      = 1.0,
                        twist_angle = 0,
                        soften      = 1.0,
                        joints      = {"LeftUpLeg", "LeftLeg", "LeftFoot",},
                    },
                    left_sole = {
                        type        = "aim",
                        target      = v4{0, 0, 0, 1},
                        pole_vector = v4{0, 1, 0, 0},
                        up_axis     = v4{0, 1, 0, 0},
                        forward     = v4{-1, 0, 0, 0},
                        offset      = v4{0, 0, 0, 0},
                        weight      = 1.0,
                        twist_angle = 0,
                        joints      = {"LeftFoot",}
                    },
                    right_leg = {
                        type        = "two_bone",
                        target      = v4{0, 0, 0, 1},
                        pole_vector = v4{0, 1, 0, 0},
                        mid_axis    = v4{0, 0, 1, 0},
                        weight      = 1.0,
                        twist_angle = 0,
                        soften      = 1.0,
                        joints      = {"RightUpLeg", "RightLeg", "RightFoot",},
                    },
                    right_sole = {
                        type        = "aim",
                        target      = v4{0, 0, 0, 1},
                        pole_vector = v4{0, 1, 0, 0},
                        up_axis     = v4{0, 1, 0, 0},
                        forward     = v4{-1, 0, 0, 0},
                        offset      = v4{0, 0, 0, 0},
                        weight      = 1.0,
                        twist_angle = 0,
                        joints      = {"RightFoot",}
                    },
                }
            },
            foot_ik_raycast = {
                cast_dir = v4{0, -2, 0, 0},
                foot_height = 0.5,
                trackers = {
                    {
                        leg = "left_leg",
                        sole = "left_sole",
                    },
                    {
                        leg = "right_leg",
                        sole = "right_sole",
                    },
                },
            },
            character = {movespeed = 1.0,},
            collider = world.component:collider{
                capsule = {
                    world.component:capsule_shape{
                        origin = v4{0, 1, 0, 1},
                        radius = 0.5,
                        height = 1,
                        axis = "Y",
                    }
                }
            },
            name = "foot_ik_test",
            can_cast = true,
            can_render = true,
            scene_entity = true,
        }
    }
    
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