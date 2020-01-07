local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

local serialize = import_package 'ant.serialize'

local skypkg = import_package 'ant.sky'
local skyutil = skypkg.util

local renderpkg = import_package 'ant.render'
local computil  = renderpkg.components
local defaultcomp=renderpkg.default
local lu        = renderpkg.light

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util
local mc        = mathpkg.constant


local pbrscene = require "pbr_scene"

local init_loader = ecs.system 'init_loader'

init_loader.require_system 'ant.camera_controller|camera_controller2'
init_loader.require_system 'ant.bullet|character_system'
init_loader.require_system "ant.camera_controller|camera_system"
init_loader.require_system "ant.imguibase|imgui_system"
init_loader.require_system "ant.sky|procedural_sky_system"

local char_controller_policy = ecs.policy "character_controller"
char_controller_policy.require_component "character"
char_controller_policy.require_policy "ant.bullet|collider.character"

local function ozzmesh_animation_test()
    local meshdir = fs.path 'meshes'
    local skepath = meshdir / 'skeleton' / 'human_skeleton.ozz'
    local smpath = meshdir / 'mesh.ozz'

    local respath = fs.path '/pkg/ant.resources'

    return
        world:create_entity {
        policy = {
            "ant.render|render",
            "ant.animation|ozzmesh",
            "ant.animation|animation",
            "ant.animation|ozz_skinning",
            "ant.serialize|serialize",
            "ant.render|name",
            "ant.render|shadow_cast",
            "ant.bullet|collider.character",
            "ant.test.features|character_controller",
        },
        data = {
            transform = {
                s = {1, 1, 1, 0},
                r = {0, 0, 0, 0},
                t = {0, 0, -3, 1}
            },
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/skin_model_sample.material"
            },
            animation = {
                anilist = {
                    idle = {
                        ref_path = respath / meshdir / 'animation' / 'animation1.ozz',
                        scale = 1,
                        looptimes = 0,
                    },
                    walk = {
                        ref_path = respath / meshdir / 'animation' / 'animation2.ozz',
                        scale = 1,
                        looptimes = 0,
                    }
                },
                blendtype = 'blend',
                pose = {
                    idle = {
                        {name = "idle", weight=1},
                    },
                    walk = {
                        {name = "walk",weight=1},
                    },
                    -- run = {
                    --     {name = "run", weight=1},
                    -- }
                },
                birth_pose = "idle",
            },
            can_render = true,
            rendermesh = {},
            skinning = {},
            skeleton = {
                ref_path = respath / skepath
            },
            mesh = {
                ref_path = respath / smpath
            },
            name = 'animation_sample',
            serialize = serialize.create(),
            collider_tag = "",
            character_collider = {
                collider = {
                    center = {0, 0, 0},
                    is_tigger = true,
                },
                shape = {
                    capsule = {
                        radius = 1.0,
                        height = 1.0,
                        axis = "Y",
                    }
                },
            },
            can_cast = true,
            character = {
                movespeed = 1.0,
            }
        }
    }
end

local function test_serialize(delfile_aftertest)
	--local eid = world:first_entity_id "main_queue"
	--local watch = import_package "ant.serialize".watch
	--local res1 = watch.query(world, nil, eid.."/camera")
	--local res2 = watch.query(world, res1.__id, "")
	--watch.set(world, res1.__id, "", "type", "test")
	--local res3 = watch.query(world, res1.__id, "")
    
    local function save_file(file, data)
        assert(assert(io.open(file, 'w')):write(data)):close()
    end
    -- test serialize world
    local s = serialize.save_world(world)
    save_file('serialize_world.txt', s)
    for _, eid in world:each 'serialize' do
        world:remove_entity(eid)
    end
    world:update_func "delete"()
    world:clear_removed()
    serialize.load_world(world, s)
    -- DO NOT call update_func "init", if you donot close the world
    -- in this test, just call "post_init" is enougth
    world:update_func "post_init"()

    --test serialize entity
    local eid = world:first_entity_id 'serialize'
    local s = serialize.save_entity(world, eid)
    save_file('serialize_entity.txt', s)
    world:remove_entity(eid)
    serialize.load_entity(world, s)

    if delfile_aftertest then
        local lfs = require "filesystem.local"
        lfs.remove(lfs.path 'serialize_world.txt')
        lfs.remove(lfs.path 'serialize_entity.txt')
    end
end

local function gltf_animation_test()
    world:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|mesh",
            --"ant.animation|animation",
            --"ant.animation|skinning",
            "ant.render|shadow_cast",
            "ant.render|name",
        },
        data = {
            transform = mu.srt(nil, nil, {-5, 0, 0, 1}),
            rendermesh = {},
            mesh = {
                ref_path = fs.path "/pkg/ant.resources/depiction/meshes/female.mesh",
            },
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/skin_model_sample.material",
            },
            -- skeleton = {
            --     ref_path = fs.path "/pkg/ant.resources.binary/meshes/female/skeleton.ozz"
            -- },
            -- skinning = {},
            -- animation = {
            --     anilist = {
            --         ani1 = {
            --             ref_path = fs.path "/pkg/ant.resources.binary/meshes/female/animations/idle.ozz",
            --             scale = 1,
            --             looptimes = 0,
            --         },
            --     },
            --     blendtype = 'blend',
            --     pose = {
            --         idle = {
            --             {name="ani1", weight=1},
            --         },
            --     },
            --     birth_pose = "idle",
            -- },
            can_render = true,
            can_cast = true,
            name = "gltf animation test",
            character = {
                movespeed = 1.0,
            }
        }
    }
end

local function pbr_test()
    world:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|mesh",
            "ant.render|shadow_cast",
            "ant.render|name",
        },
        data = {
            transform = mu.srt(nil, nil, {3, 2, 0, 1}),
            rendermesh = {},
            mesh = {
                ref_path = fs.path "/pkg/ant.test.features/assets/DamagedHelmet.mesh",
            },
            material = {
                ref_path = fs.path "/pkg/ant.test.features/assets/DamagedHelmet.pbrm",
            },
            can_render = true,
            can_cast = true,
            name = "Damaged Helmet"
        }

    }
end

local function create_plane_test()
    return 
    computil.create_plane_entity(world,
            {50, 1, 50, 0}, nil,
            fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material",
            {0.8, 0.8, 0.8, 1},
            "test shadow plane",
            true)
end

function init_loader:init()
    do
        lu.create_directional_light_entity(world, "direction light", 
		{1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
    frustum.f = 300
    world:pub {"spawn_camera", "test_main_camera", {
        type    = "",
        eyepos  = {0, 0, -5, 1},
        viewdir = mc.T_ZAXIS,
        updir   = mc.T_YAXIS,
        frustum = frustum,
    }}

    skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
    computil.create_bounding_drawer(world)

    --computil.create_grid_entity(world, 'grid', 64, 64, 1, mu.translate_mat {0, 0, 0})
    create_plane_test()

    ozzmesh_animation_test()
    pbr_test()
    gltf_animation_test()
    pbrscene.create_scene(world)
end

local imgui      = require "imgui"
local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function init_loader:ui_update()
    local mq = world:first_entity "main_queue"
    local cameraname = mq.camera_tag

    local widget = imgui.widget
    imgui.windows.Begin("Test", wndflags)
    if widget.Button "rotate" then
        world:pub {"motion_camera", "rotate", cameraname, {math.rad(10), 0, 0}}
    end

    if widget.Button "move" then
        world:pub {"motion_camera", "move", cameraname, {1, 0, 0}}
    end

    local function find_entity(name, whichtype)
        for _, eid in world:each(whichtype) do
            if world[eid].name:match(name) then
                return eid
            end
        end
    end

    if widget.Button "lock_target_for_move" then
        local foundeid = find_entity("animation_sample", "character")
        if foundeid then
            world:pub {"motion_camera", "target", cameraname, {type = "move", eid = foundeid, offset = {0, 1, 0}}}
        else
            print "not found animation_sample"
        end
        
    end

    if widget.Button "lock_target_for_rotate" then
        local foundeid = find_entity("animation_sample", "character")
        if foundeid then
            world:pub {"motion_camera", "target", cameraname, {type = "rotate", eid = foundeid}}
        else
            print "not found gltf entity"
        end
    end

    imgui.windows.End()
end