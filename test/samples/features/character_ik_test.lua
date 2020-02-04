local ecs = ...

local serialize = import_package "ant.serialize"
local fs = require "filesystem"

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local iktest_sys = ecs.system "character_ik_test"

local function foot_ik_test()
    local tmp_ozzrespath = fs.path '/pkg/ant.test.features'
    local assetpath = tmp_ozzrespath / 'assets' / 'tmp'
    return world:create_entity {
        policy = {
            "ant.serialize|serialize",
            "ant.render|render",
            "ant.animation|animation",
            "ant.animation|ozzmesh",
            "ant.animation|ozz_skinning",
            "ant.render|shadow_cast",
            "ant.render|name",
            "ant.character|character",
        },
        data = {
            transform = mu.translate_mat {0, 0, -6, 1},
            rendermesh = {},
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/skin_model_sample.material",
            },
            mesh = {
                ref_path = assetpath / 'mesh.ozz'
            },
            skeleton = {
                ref_path = assetpath / 'skeleton.ozz'
            },
            animation = {
                anilist = {
                    idle = {
                        ref_path = assetpath / 'animation.ozz',
                        scale = 1,
                        looptimes = 0,
                    },
                },
                birth_pose = "idle",
                ik = {
                    jobs = {
                        {
                            type        = "two_bone",
                            target      = {0, 0, 0, 1},
                            pole_vector = {0, 1, 0, 0},
                            mid_axis    = {0, 0, 1, 0},
                            widget      = 1.0,
                            twist_angle = 0,
                            soften      = 0.5,
                            joints      = {
                                "LeftUpLeg", "LeftLeg", "LeftFoot",
                            }
                        },
                        {
                            type        = "aim",
                            target      = {0, 0, 0, 1},
                            pole_vector = {0, 1, 0, 0},
                            up_axis     = {0, 1, 0, 0},
                            forward     = {0, 0, 1, 0},
                            offset      = {0, 0, 0, 0},
                            widget      = 1.0,
                            twist_angle = 0,
                            joints      = {
                                "LeftFoot",
                            }
                        }
                    }
                }
            },
            raycast = {},
            character = {movespeed = 1.0,},
            serialize = serialize.create(),
            name = "foot_ik_test",
            can_cast = true,
            can_render = true,
        }
    }
    
end

local footik_eid
function iktest_sys:init()
    footik_eid = foot_ik_test()
end


function iktest_sys:data_changed()
    
end