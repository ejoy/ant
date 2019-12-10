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
ecs.import 'ant.imguibase'

local serialize  = import_package 'ant.serialize'
local skypkg     = import_package 'ant.sky'
local renderpkg  = import_package 'ant.render'
local mathpkg    = import_package "ant.math"
local skyutil    = skypkg.util
local computil   = renderpkg.components
local camerautil = renderpkg.camera
local ms         = mathpkg.stack
local mu         = mathpkg.util
local lu         = renderpkg.light

local init_loader = ecs.system 'init_loader'
init_loader.singleton "asyn_load_list"

init_loader.depend 'timesystem'
init_loader.depend "serialize_index_system"
init_loader.depend "procedural_sky_system"
init_loader.depend "imgui_runtime_system"

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
        material = computil.assign_material(fs.path "/pkg/ant.resources/depiction/materials/skin_model_sample.material"),
        animation = {
            anilist = {
                walk = {
                    --ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/animations/walking.ozz',
                    ref_path = fs.path '/pkg/ant.resources/meshes/animation/animation1.ozz',
                    scale = 1,
                    looptimes = 0,
                },
                run = {
                    --ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/animations/running.ozz',
                    ref_path = fs.path '/pkg/ant.resources/meshes/animation/animation2.ozz',
                    scale = 1,
                    looptimes = 0,
                },
                runfast = {
                    --ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/animations/running-fast.ozz',
                    ref_path = fs.path '/pkg/ant.resources/meshes/animation/animation3.ozz',
                    scale = 1,
                    looptimes = 0,
                }
            },
            pose = {
                walk = {
                    {name="walk", weight=1},
                },
                run = {
                    {name="run", weight=1},
                },
                runfast = {
                    {name="runfast", weight=1},
                }
            },
            blendtype = 'blend',
            birth_pose = "walk"
        },
        state_chain = {
            ref_path = fs.path '/pkg/ant.test.animation/assets/test.sm',
        },
        skeleton = {
            --ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/skeleton.ozz'
            ref_path = fs.path '/pkg/ant.resources/meshes/skeleton/human_skeleton.ozz'
        },
        skinning_mesh = {
            --ref_path = fs.path '/pkg/ant.resources.binary/meshes/female/female.ozz'
            ref_path = fs.path '/pkg/ant.resources/meshes/mesh.ozz'
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
    }

    --local function save_file(file, data)
    --    assert(assert(io.open(file, 'w')):write(data)):close()
    --end
    --local function load_file(file)
    --    local f = assert(io.open(file, 'r'))
    --    local data = f:read 'a'
    --    f:close()
    --    return data
    --end
    --local s = serialize.v2.save_entity(world, eid)
    --save_file('serialize_entity.txt', s)
    --world:remove_entity(eid)
    --serialize.v2.load_entity(world, s)
    return eid
end

local eid

function init_loader:init()
    lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, mu.to_radian{60, 50, 0})
    lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    --skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
    --computil.create_grid_entity(world, 'grid', 64, 64, 1, mu.translate_mat {0, 0, 0})
    eid = create_animation_test()
end

function init_loader:post_init()
    local viewcamera = camerautil.get_camera(world, "main_view")
    viewcamera.frustum.f = 300
    ms(viewcamera.eyepos,  { 1.6, 0.8,-1.8, 0.0}, "=")
    ms(viewcamera.updir,   { 0.0, 1.0, 0.0, 0.0}, "=")
    ms(viewcamera.viewdir, {-0.6,-0.4, 0.7, 0.0}, "=")
    local e = world:first_entity "render_target"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end

local imgui = require "imgui"

local function defer(f)
    local toclose = setmetatable({}, { __close = f })
    return function (_, w)
        if not w then
            return toclose
        end
    end, nil, nil, toclose
end

local function imgui_windows(...)
	imgui.windows.Begin(...)
	return defer(function()
		imgui.windows.End()
	end)
end

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function init_loader:on_gui()
	local widget = imgui.widget
    for _ in imgui_windows("Test", wndflags) do
        for name in sortpairs(world[eid].animation.pose) do
            if widget.Button(name) then
                world[eid].state_chain.target = name
            end
        end
	end
end
