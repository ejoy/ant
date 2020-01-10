local ecs = ...
local world = ecs.world

local serialize  = import_package 'ant.serialize'
local renderpkg  = import_package 'ant.render'
local mathpkg    = import_package "ant.math"
local imgui      = require "imgui"
local fs         = require 'filesystem'
local computil   = renderpkg.components
local defaultcomp= renderpkg.default
local mu         = mathpkg.util
local mc         = mathpkg.constant
local lu         = renderpkg.light

local m = ecs.system 'init_loader'

m.require_system "ant.imguibase|imgui_system"
m.require_system "ant.camera_controller|camera_system"

local function create_animation_test()
    local eid = world:create_entity {
        policy = {
            "ant.animation|animation",
            "ant.animation|state_chain",
            "ant.animation|ozzmesh",
            "ant.animation|ozz_skinning",
            "ant.bullet|collider.capsule",
            "ant.render|render",
            "ant.serialize|serialize",
            "ant.render|name",
        },
        data = {
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
            mesh = {
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

function m:init()
    local fbsize = world.args.fb_size
    local frustum = defaultcomp.frustum(fbsize.w, fbsize.h)
    frustum.f = 300
    world:pub {"spawn_camera", "main_camera",{
        type = "",
        eyepos = { 1.6, 1.8,-1.8, 1.0},
        updir = mc.T_YAXIS,
        viewdir = {-0.6,-0.4, 0.7, 0.0},
        frustum = frustum,
    }}
    lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, mu.to_radian{60, 50, 0, 0})
    lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    --skyutil.create_procedural_sky(world, {follow_by_directional_light=false})
    --computil.create_grid_entity(world, 'grid', 64, 64, 1, mu.translate_mat {0, 0, 0})
    eid = create_animation_test()
end

function m:post_init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end


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

function m:ui_update()
    local widget = imgui.widget
    for _ in imgui_windows("Test", wndflags) do
        for name in sortpairs(world[eid].animation.pose) do
            if widget.Button(name) then
                world[eid].state_chain.target = name
            end
        end
    end
end
