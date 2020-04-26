local ecs = ...
local world = ecs.world
local serializeutil = import_package "ant.serialize"

local anitest_sys = ecs.system "animation_test_system"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local math3d = require "math3d"

local function ozzmesh_animation_test()
    local function v4(...) return world.component:vector(...) end
    return
        world:create_entity {
        policy = {
            "ant.render|render",
            "ant.animation|ozzmesh",
            "ant.animation|animation",
            "ant.animation|animation_controller.birth",
            "ant.animation|ozz_skinning",
            "ant.serialize|serialize",
            "ant.general|name",
            "ant.render|shadow_cast_policy",
            "ant.character|character",
            "ant.render|debug_mesh_bounding",
        },
        data = {
            transform = computil.create_transform(world, {srt = {t={-5, 0, 5, 1}}}),
            material = world.component:resource "/pkg/ant.resources/materials/skin_model_sample.material",
            animation = {
                anilist = {
                    walk = world.component:resource '/pkg/ant.resources.binary/meshes/ozz/animation1.ozz',
                },
            },
            animation_birth = "walk",
            can_render = true,
            scene_entity = true,
            skeleton = world.component:resource '/pkg/ant.resources.binary/meshes/ozz/human_skeleton.ozz',
            mesh = world.component:resource '/pkg/ant.resources.binary/meshes/ozz/mesh.ozz',
            name = 'animation_sample',
            serialize = serializeutil.create(),
            collider = world.component:collider {
                capsule = {
                    world.component:capsule_shape {
                        origin = v4{0, 1, 0, 1},
                        radius = 0.5,
                        height = 1,
                        axis = "Y",
                    }
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
            "ant.render|shadow_cast_policy",
            "ant.general|name",
        },
        data = {
            transform = computil.create_transform(world, {
                srt = {t = {-5, 0, 0, 1}}
            }),
            mesh = world.component:resource "/pkg/ant.resources/meshes/female.mesh",
            material = world.component:resource "/pkg/ant.resources/materials/skin_model_sample.material",
            skeleton = world.component:resource "/pkg/ant.resources.binary/meshes/female/skeleton.ozz",
            animation = {
                anilist = {
                    idle = world.component:resource "/pkg/ant.resources.binary/meshes/female/animations/idle.ozz",
                },
            },
            animation_birth = "idle",
            can_render = true,
            scene_entity = true,
            can_cast = true,
            name = "gltf animation test",
            character = {
                movespeed = 1.0,
            }
        }
    }
end

local function print_ske(ske)
    local trees = {}
    for i=1, #ske do
        local jname = ske:joint_name(i)
        if ske:isroot(i) then
            trees[i] = ""
            print(jname)
        else
            local s = "  "
            local p = ske:parent(i)
            assert(trees[p])
            s = s .. trees[p]
            trees[i] = s
            print(s .. jname)
        end
    end
end

function anitest_sys:init()
    ozzmesh_animation_test()
    gltf_animation_test()
end