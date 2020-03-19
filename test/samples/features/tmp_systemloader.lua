local ecs = ...
local world = ecs.world

local fs = require 'filesystem'

local serialize = import_package 'ant.serialize'

local math3d = require "math3d"

local skypkg = import_package 'ant.sky'
local skyutil = skypkg.util

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local renderpkg = import_package 'ant.render'
local computil  = renderpkg.components

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local init_loader = ecs.system 'init_loader'

init_loader.require_system 'ant.camera_controller|camera_controller2'
init_loader.require_system "ant.camera_controller|camera_system"
init_loader.require_system "ant.imguibase|imgui_system"
init_loader.require_system "ant.sky|procedural_sky_system"
init_loader.require_system "ant.test.features|scenespace_test"
init_loader.require_system "ant.test.features|character_ik_test"
init_loader.require_system "ant.test.features|terrain_test"
init_loader.require_system "ant.test.features|pbr_test"
init_loader.require_system "ant.test.features|animation_test"
init_loader.require_system "ant.render|physic_bounding"
init_loader.require_system "ant.render|render_mesh_bounding"

init_loader.require_interface "ant.render|camera"
init_loader.require_interface "ant.camera_controller|camera_motion"
init_loader.require_interface "ant.render|iwidget_drawer"
init_loader.require_interface "ant.render|light"

local function create_plane_test()
    local planes = {
        {
            transform = {srt={s={50, 1, 50}}},
            color = {0.8, 0.8, 0.8, 1},
            material = fs.path "/pkg/ant.resources/depiction/materials/test/mesh_shadow.material",
        },
    }

    for _, p in ipairs(planes) do
        computil.create_plane_entity(world,
            p.transform,
            p.material,
            p.color,
            "test shadow plane",
            {
                ["ant.collision|collider"] = {
                    collider = {
                        box = {
                            {
                                origin = {0, 0, 0, 1},
                                size = {50, 0.001, 50},
                            }
                        }
                    },
                },
                ["ant.render|debug_mesh_bounding"] = {
                    debug_mesh_bounding = true,
                }
            })
    end
end

local camera = world:interface "ant.render|camera"
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
            transform = {srt={}},
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

local ilight = world:interface "ant.render|light"

function init_loader:init()
    do
        local dlightdir = math3d.totable(
            math3d.normalize(math3d.inverse(math3d.todirection(
                math3d.quaternion(mu.to_radian{60, 50, 0, 0}))
        )))
        ilight.create_directional_light_entity("direction light", 
		{1,1,1,1}, 2, dlightdir)
        ilight.create_ambient_light_entity('ambient_light', 'gradient', {1, 1, 1, 1})
    end

    skyutil.create_procedural_sky(world)
end

local function create_camera()
    local rotation = math3d.quaternion{math.rad(30), math.rad(150), 0}
    local id = camera.create {
        eyepos  = {-4.5, 2, -1.5, 1},
        viewdir = math3d.totable(math3d.todirection(rotation)),
    }
    camera.bind(id, "main_queue")
    return id
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