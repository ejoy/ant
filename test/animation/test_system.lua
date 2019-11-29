local ecs = ...
local world = ecs.world

local fs = require 'filesystem'


ecs.import 'ant.math.adapter'
ecs.import 'ant.asset'
ecs.import 'ant.render'
ecs.import 'ant.editor'
ecs.import 'ant.inputmgr'
ecs.import 'ant.serialize'
ecs.import 'ant.scene'
ecs.import 'ant.timer'
ecs.import 'ant.bullet'
ecs.import 'ant.animation'
ecs.import 'ant.event'
ecs.import 'ant.objcontroller'
ecs.import 'ant.sky'


local serialize = import_package 'ant.serialize'

local skypkg = import_package 'ant.sky'
local skyutil = skypkg.util

local renderpkg = import_package 'ant.render'
local computil  = renderpkg.components
local camerautil= renderpkg.camera
local aniutil   = import_package 'ant.animation'.util

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local lu = renderpkg.light

local init_loader = ecs.system 'init_loader'
init_loader.singleton "asyn_load_list"

init_loader.depend 'timesystem'
init_loader.depend "serialize_index_system"
init_loader.depend "procedural_sky_system"

init_loader.dependby 'render_system'
init_loader.dependby 'cull_system'
init_loader.dependby 'shadow_maker'
init_loader.dependby 'primitive_filter_system'
init_loader.dependby 'camera_controller'
init_loader.dependby 'skinning_system'
init_loader.dependby 'viewport_detect_system'
init_loader.dependby 'state_machine'

local function create_animation_test()
    local eid =
        world:create_entity {
        transform = {
            s = {1, 1, 1, 0},
            r = {0, math.pi*.75, 0, 0},
            t = {0, 0, 0, 1}
        },
        can_render = true,
        rendermesh = {},
        material = computil.assign_material(fs.path "/pkg/ant.resources/depiction/materials/bunny.material"),
        animation = {
            pose_state = {
                pose = {
                    anirefs = {
                        {idx = 1, weight = 0.5},
                        {idx = 2, weight = 0.5}
                    },
                    name = "walk",
                }
            },
            anilist = {
                {
                    ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/animations/idle.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'idle'
                },
                {
                    ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/animations/walking.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'walk'
                },
                {
                    ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/animations/running.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'run'
                },
                {
                    ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/animations/running-fast.ozz',
                    scale = 1,
                    looptimes = 0,
                    name = 'run fast'
                }
            },
            blendtype = 'blend'
        },
        state_chain = {
            ref_path = fs.path '/pkg/ant.test.animation/assets/test.sm',
        },
        skeleton = {
            ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/skeleton.ozz'
        },
        skinning_mesh = {
            ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/female.ozz'
        },
        name = 'animation_sample',
        serialize = serialize.create(),
        collider_tag = "capsule_collider",
        capsule_collider = {
            collider = {
                center = {0, 0, 0},
                is_tigger = true,
            },
            shape = {
                radius = 1.0,
                height = 1.0,
                axis   = "Y",
            },
        },
        -- character = {
        --     movespeed = 1.0,
        -- }
    }

    -- local e = world[eid]
    -- local anicomp = e.animation
    -- aniutil.play_animation(e.animation, anicomp.pose_state.pose)
    
    local function save_file(file, data)
        assert(assert(io.open(file, 'w')):write(data)):close()
    end
    local s = serialize.save_entity(world, eid)
    save_file('serialize_entity.txt', s)
end

function init_loader:init()
    lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, mu.to_radian{60, 50, 0})
    lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
    computil.create_grid_entity(world, 'grid', 64, 64, 1, mu.translate_mat {0, 0, 0})
    create_animation_test()
end

function init_loader:post_init()
    local viewcamera = camerautil.get_camera(world, "main_view")
    viewcamera.frustum.f = 300
end
