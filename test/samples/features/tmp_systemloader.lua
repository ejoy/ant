local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

local serialize = import_package 'ant.serialize'

local mathpkg = import_package 'ant.math'
local ms = mathpkg.stack

local skypkg = import_package 'ant.sky'
local skyutil = skypkg.util

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

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
--init_loader.require_system "ant.test.features|scenespace_test"
init_loader.require_system "ant.test.features|character_ik_system"
init_loader.require_system "ant.render|physic_bounding"
init_loader.require_system "ant.render|render_mesh_bounding"
init_loader.require_system "ant.render|draw_raycast_point"

init_loader.require_interface "ant.render|camera_spawn"
init_loader.require_interface "ant.camera_controller|camera_motion"
init_loader.require_interface "ant.render|iwidget_drawer"


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
            "ant.animation|ozz_skinning",
            "ant.serialize|serialize",
            "ant.render|name",
            "ant.render|shadow_cast",
            "ant.bullet|collider.character",
            "ant.test.features|character",
            "ant.render|debug_mesh_bounding",
        },
        data = {
            transform = {
                s = {1, 1, 1, 0},
                r = {0, 0, 0, 0},
                t = {-5, 0, 5, 1}
            },
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
                birth_pose = "walk",
                ik = {jobs={}}
            },
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
            serialize = serialize.create(),
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
                    idle = {
                        ref_path = fs.path "/pkg/ant.resources.binary/meshes/female/animations/idle.ozz",
                        scale = 1,
                        looptimes = 0,
                    },
                },
                birth_pose = "idle",
                ik = {jobs={}}
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
                                {0, 0, -5, 1}),
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
                ["ant.bullet|collider"] = {
                    collider = {
                        box = {
                            origin = {0, 0, 0, 1},
                            size = {0.5, 0, 0.5},
                        }
                    },
                },
                ["ant.render|debug_mesh_bounding"] = {
                    debug_mesh_bounding = true,
                }
            })
    end
end

local ics = world:interface "ant.render|camera_spawn"
local icm = world:interface "ant.camera_controller|camera_motion"
local iwd = world:interface "ant.render|iwidget_drawer"

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

local function simple_box()
    local eid = world:create_entity {
        policy = {
            "ant.render|render",
            "ant.render|name",
        },
        data = {
            transform = mu.srt(),
            rendermesh = {},
            can_render = true,
            material = {
                ref_path = fs.path "/pkg/ant.resources/depiction/materials/simpletri.material",
                properties = {
                    uniforms = {
                        u_color = {
                            type = "color",
                            value = {1, 0, 0, 1},
                            name = "color"
                        }
                    }
                }
            },
            name = "simplebox"
        }
    }

    local e = world[eid]

    local geopkg 	= import_package "ant.geometry"
    local geodrawer	= geopkg.drawer

    local desc = {vb={"fff"}, ib={}}
    geodrawer.draw_box({1, 1, 1}, nil, nil, desc)
    e.rendermesh.reskey = assetmgr.register_resource(fs.path "//res.mesh/simplebox.mesh", computil.create_simple_mesh("p3", desc.vb, 8, desc.ib, #desc.ib))
    return eid
end

function init_loader:init()
    do
        lu.create_directional_light_entity(world, "direction light", 
		{1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
        lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    end

    skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
    iwd.create()

    computil.create_grid_entity(world, 'grid', 64, 64, 1, mu.translate_mat {0, 0, 0, 1})
    --create_plane_test()

    --ozzmesh_animation_test()
    --pbr_test()
    --gltf_animation_test()

    simple_box()

    --pbrscene.create_scene(world)
end

local function create_camera()
    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
    frustum.f = 300
    local cameraeid = ics.spawn("test_main_camera", {
        type    = "",
        eyepos  = {0, 5, -10, 1},
        viewdir = ms(ms:forward_dir({math.rad(30), 0, 0, 0}), "T"),
        updir   = mc.T_YAXIS,
        frustum = frustum,
    })
    ics.bind("main_queue", cameraeid)
    return cameraeid
end

function init_loader:data_changed()
    -- iwd.draw_lines{
    --     {5, 2, 5},
    --     {5, 2, 15},
    -- }
end

function init_loader:post_init()
    create_camera()
end

local imgui      = require "imgui"
local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function init_loader:ui_update()
    local mq = world:singleton_entity "main_queue"
    local cameraeid = mq.camera_eid

    local widget = imgui.widget
    imgui.windows.Begin("Test", wndflags)
    if widget.Button "rotate" then
        icm.rotate(cameraeid, {math.rad(10), 0, 0})
    end

    if widget.Button "move" then
        icm.move(cameraeid, {1, 0, 0})
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
            icm.target(cameraeid, "move", foundeid, {0, 1, 0})
        else
            print "not found animation_sample"
        end
        
    end

    if widget.Button "lock_target_for_rotate" then
        local foundeid = find_entity("animation_sample", "character")
        if foundeid then
            icm.target(cameraeid, "rotate", foundeid)
        else
            print "not found gltf entity"
        end
    end

    imgui.windows.End()
end