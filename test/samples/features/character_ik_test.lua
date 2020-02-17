local ecs = ...
local world = ecs.world

local serialize = import_package "ant.serialize"
local fs = require "filesystem"

local mathpkg = import_package "ant.math"
local ms, mu = mathpkg.stack, mathpkg.util

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local iktest_sys = ecs.system "character_ik_test"
iktest_sys.require_policy "ant.character|foot_ik_raycast"

local function foot_ik_test()
    local tmp_ozzrespath = fs.path '/pkg/ant.test.features'
    local tmp_assetpath = tmp_ozzrespath / 'assets' / 'tmp'

    local assetpath = fs.path '/pkg/ant.resources.binary/meshes/ozz'
    return world:create_entity {
        policy = {
            "ant.serialize|serialize",
            "ant.render|render",
            "ant.animation|animation",
            "ant.animation|ozzmesh",
            "ant.animation|ik",
            "ant.animation|ozz_skinning",
            "ant.render|shadow_cast",
            "ant.render|name",
            "ant.character|character",
            "ant.character|foot_ik_raycast",
        },
        data = {
            transform = mu.translate_mat {-2.5, 0, -6, 1},
            rendermesh = {},
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/skin_model_sample.material",
            },
            mesh = {
                ref_path = assetpath / 'mesh.ozz'
            },
            skeleton = {
                ref_path = assetpath / 'human_skeleton.ozz'
            },
            animation = {
                anilist = {
                    idle = {
                        ref_path = tmp_assetpath / 'animation.ozz',
                        scale = 1,
                        looptimes = 0,
                    },
                },
                birth_pose = "idle",
            },
            ik = {
                jobs = {
                    {
                        name        = "left_leg",
                        type        = "two_bone",
                        target      = {0, 0, 0, 1},
                        pole_vector = {0, 1, 0, 0},
                        mid_axis    = {0, 0, 1, 0},
                        weight      = 1.0,
                        twist_angle = 0,
                        soften      = 1.0,
                        joints      = {"LeftUpLeg", "LeftLeg", "LeftFoot",},
                    },
                    -- {
                    --     name        = "left_sole",
                    --     type        = "aim",
                    --     target      = {0, 0, 0, 1},
                    --     pole_vector = {0, 1, 0, 0},
                    --     up_axis     = {0, 1, 0, 0},
                    --     forward     = {1, 0, 0, 0},
                    --     offset      = {0, 0, 0, 0},
                    --     weight      = 1.0,
                    --     twist_angle = 0,
                    --     joints      = {"LeftFoot",}
                    -- },
                    {
                        name        = "right_leg",
                        type        = "two_bone",
                        target      = {0, 0, 0, 1},
                        pole_vector = {0, 1, 0, 0},
                        mid_axis    = {0, 0, 1, 0},
                        weight      = 1.0,
                        twist_angle = 0,
                        soften      = 1.0,
                        joints      = {"RightUpLeg", "RightLeg", "RightFoot",},
                    },
                    -- {
                    --     name        = "right_sole",
                    --     type        = "aim",
                    --     target      = {0, 0, 0, 1},
                    --     pole_vector = {0, 1, 0, 0},
                    --     up_axis     = {0, 1, 0, 0},
                    --     forward     = {1, 0, 0, 0},
                    --     offset      = {0, 0, 0, 0},
                    --     weight      = 1.0,
                    --     twist_angle = 0,
                    --     joints      = {"RightFoot",}
                    -- },
                }
            },
            foot_ik_raycast = {
                cast_dir = {0, -2, 0, 0},
                foot_height = 0.2,
                trackers = {
                    {
                        leg = "left_leg",
                        --sole = "left_sole",
                    },
                    {
                        leg = "right_leg",
                        --sole = "right_sole",
                    },
                },
            },
            character = {movespeed = 1.0,},
            collider = {
                capsule = {
                    {
                        origin = {0, 1, 0, 1},
                        radius = 0.5,
                        height = 1,
                        axis = "Y",
                    }
                }
            },
            serialize = serialize.create(),
            name = "foot_ik_test",
            can_cast = true,
            can_render = true,
        }
    }
    
end

local function create_plane_test()
    computil.create_plane_entity(world,
    mu.srt(
        {5, 1, 5, 1},
        ms:euler2quat({math.rad(5), 0, 0, 0}, true),
        {0, 0, -5, 1}),
    fs.path "/pkg/ant.resources/depiction/materials/test/singlecolor_tri_strip.material",
    {0.5, 0.5, 0, 1},
    "test shadow plane",
    {
        ["ant.collision|collider"] = {
            collider = {
                box = {
                    {
                        origin = {0, 0, 0, 1},
                        size = {0.5, 0.0001, 0.5},
                    }
                }
            },
        },
        ["ant.render|debug_mesh_bounding"] = {
            debug_mesh_bounding = true,
        }
    })
end

function iktest_sys:init()
    create_plane_test()
    foot_ik_test()
end