local ecs = ...
local world = ecs.world
local fs = require "filesystem"

local serializeutil = import_package "ant.serialize"

local anitest = ecs.system "animation_test"


local ozzmeshdir = fs.path 'meshes' / 'ozz'
local ozzskepath = ozzmeshdir / 'human_skeleton.ozz'
local ozzmeshpath = ozzmeshdir / 'mesh.ozz'

local ozzrespath = fs.path '/pkg/ant.resources.binary'

local function ozzmesh_animation_test()

    return
        world:create_entity {
        policy = {
            "ant.render|render",
            "ant.animation|ozzmesh",
            "ant.animation|animation",
            "ant.animation|animation_controller.birth",
            "ant.animation|ozz_skinning",
            "ant.serialize|serialize",
            "ant.render|name",
            "ant.render|shadow_cast",
            "ant.character|character",
            "ant.render|debug_mesh_bounding",
        },
        data = {
            transform = {srt = {t={-5, 0, 5, 1}}},
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/skin_model_sample.material"
            },
            animation = {
                anilist = {
                    walk = {
                        ref_path = ozzrespath / ozzmeshdir / 'animation1.ozz',
                        scale = 1,
                        looptimes = 0,
                    },
                },
            },
            animation_birth = "walk",
            can_render = true,
            rendermesh = {},
            skinning = {},
            skeleton = {
                ref_path = ozzrespath / ozzskepath
            },
            mesh = {
                ref_path = ozzrespath / ozzmeshpath
            },
            name = 'animation_sample',
            serialize = serializeutil.create(),
            collider = {
                capsule = {
                    origin = {0, 1, 0, 1},
                    radius = 0.5,
                    height = 1,
                    axis = "Y",
                }
            },
            can_cast = true,
            character = {
                movespeed = 1.0,
            },
            debug_mesh_bounding = true,
        }
    }
end

local function gltf_animation_test()
    world:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|mesh",
            "ant.animation|animation",
            "ant.animation|skinning",
            "ant.animation|animation_controller.birth",
            "ant.render|shadow_cast",
            "ant.render|name",
        },
        data = {
            transform = {srt={t={-5, 0, 0, 1}}},
            rendermesh = {
                submesh_refs = {
                    Beta_Joints = {
                        visible = false,
                    },
                }
            },
            mesh = {
                ref_path = fs.path "/pkg/ant.resources/depiction/meshes/female.mesh",
            },
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/skin_model_sample.material",
            },
            skeleton = {
                ref_path = fs.path "/pkg/ant.resources.binary/meshes/female/skeleton.ozz"
            },
            skinning = {},
            animation = {
                anilist = {
                    idle = {
                        ref_path = fs.path "/pkg/ant.resources.binary/meshes/female/animations/idle.ozz",
                        scale = 1,
                        looptimes = 0,
                    },
                },
            },
            animation_birth = "idle",
            can_render = true,
            can_cast = true,
            name = "gltf animation test",
            character = {
                movespeed = 1.0,
            }
        }
    }
end

function anitest:init()
    ozzmesh_animation_test()
    gltf_animation_test()
end