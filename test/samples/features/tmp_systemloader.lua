local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

local serialize = import_package 'ant.serialize'

local mathpkg = import_package 'ant.math'
local ms = mathpkg.stack

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
init_loader.require_system 'ant.bullet|character_collider_system'
init_loader.require_system "ant.camera_controller|camera_system"
init_loader.require_system "ant.imguibase|imgui_system"
init_loader.require_system "ant.sky|procedural_sky_system"
init_loader.require_system "ant.test.features|scenespace_test"
init_loader.require_system "ant.render|physic_bounding"
init_loader.require_system "ant.render|render_mesh_bounding"
init_loader.require_system "ant.render|draw_raycast_point"

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
            "ant.render|debug_mesh_bounding",
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
                    center = {0, 1, 0},
                    is_tigger = true,
                },
                shape = {
                    capsule = {
                        radius = 0.5,
                        height = 1,
                        axis = "Y",
                    }
                },
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
            skeleton = {
                ref_path = fs.path "/pkg/ant.resources.binary/meshes/female/skeleton.ozz"
            },
            skinning = {},
            animation = {
                anilist = {
                    ani1 = {
                        ref_path = fs.path "/pkg/ant.resources.binary/meshes/female/animations/idle.ozz",
                        scale = 1,
                        looptimes = 0,
                    },
                },
                blendtype = 'blend',
                pose = {
                    idle = {
                        {name="ani1", weight=1},
                    },
                },
                birth_pose = "idle",
            },
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
    local planes = {
        {
            transform = mu.srt{50, 1, 50, 1},
            color = {0.8, 0.8, 0.8, 1},
            material = fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material",
        },
        {
            transform = mu.srt({5, 1, 5, 1},
                                {math.rad(10), 0, 0, 0},
                                {0, 5, -5, 1}),
            color = {0.5, 0.5, 0, 1},
            material = fs.path "/pkg/ant.resources/depiction/materials/test/singlecolor_tri_strip.material",
        }
    }

    for _, p in ipairs(planes) do
        computil.create_plane_entity(world,
            p.transform,
            p.material,
            p.color,
            "test shadow plane",
            {
                ["ant.bullet|collider.box"] = {
                    box_collider = {
                        collider = {
                            center = {0, 0, 0},
                        },
                        shape = {
                            size = {0.5, 0, 0.5},
                        }
                    },
                    collider_tag = "",
                },
                ["ant.render|debug_mesh_bounding"] = {
                    debug_mesh_bounding = true,
                }
            })
    end
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
        eyepos  = {0, 5, -10, 1},
        viewdir = ms(ms:forward_dir({math.rad(30), 0, 0, 0}), "T"),
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
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid

    local widget = imgui.widget
    imgui.windows.Begin("Test", wndflags)
    if widget.Button "rotate" then
        world:pub {"motion_camera", "rotate", cameraeid, {math.rad(10), 0, 0}}
    end

    if widget.Button "move" then
        world:pub {"motion_camera", "move", cameraeid, {1, 0, 0}}
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
            world:pub {"motion_camera", "target", cameraeid, {type = "move", eid = foundeid, offset = {0, 1, 0}}}
        else
            print "not found animation_sample"
        end
        
    end

    if widget.Button "lock_target_for_rotate" then
        local foundeid = find_entity("animation_sample", "character")
        if foundeid then
            world:pub {"motion_camera", "target", cameraeid, {type = "rotate", eid = foundeid}}
        else
            print "not found gltf entity"
        end
    end

    imgui.windows.End()
end