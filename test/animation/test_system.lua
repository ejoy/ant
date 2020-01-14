local ecs = ...
local world = ecs.world

local renderpkg  = import_package 'ant.render'
local mathpkg    = import_package "ant.math"
local imgui      = require "imgui"
local fs         = require 'filesystem'
local defaultcomp= renderpkg.default
local mu         = mathpkg.util
local mc         = mathpkg.constant
local lu         = renderpkg.light

local m = ecs.system 'init_loader'

m.require_system "ant.imguibase|imgui_system"
m.require_system "ant.camera_controller|camera_system"
m.require_interface "ant.animation|animation"

local function load_file(file)
    local f = assert(fs.open(fs.path(file), 'r'))
    local data = f:read 'a'
    f:close()
    return data
end

local function create_animation_test()
    local eid = world:create_entity(load_file 'entity.txt')

    --local serialize  = import_package 'ant.serialize'
    --local function save_file(file, data)
    --    assert(assert(io.open(file, 'w')):write(data)):close()
    --end
    --local s = serialize.v2.save_entity(world, eid, policies)
    --save_file('serialize_entity.txt', s)
    --world:remove_entity(eid)
    --world:create_entity(s)
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
    local e = world[eid]
    local widget = imgui.widget
    for _ in imgui_windows("Test", wndflags) do
        for name in sortpairs(e.animation.pose) do
            if widget.Button(name) then
                local animation = world:interface "ant.animation|animation"
                if not animation.travel(e, name) then
                    animation.play(e, name, 0.5)
                end
            end
        end
    end
end
