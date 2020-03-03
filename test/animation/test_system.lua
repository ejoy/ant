local ecs = ...
local world = ecs.world

local renderpkg  = import_package 'ant.render'
local mathpkg    = import_package "ant.math"
local imgui      = require "imgui"
local imgui_util = require "imgui_util"
local fs         = require 'filesystem'
local ms, mu     = mathpkg.stack, mathpkg.util
local lu         = renderpkg.light

local camera = world:interface "ant.render|camera"

local m = ecs.system 'init_loader'

m.require_system "ant.imguibase|imgui_system"
m.require_system "draw_skeleton"
m.require_interface "ant.render|camera"
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

local function create_camera()
    camera.bind(camera.create {
        eyepos = { 1.6, 1.8,-1.8, 1.0},
        viewdir = {-0.6,-0.4, 0.7, 0.0},
    }, "main_queue")
end

function m:init()
    lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, ms:euler2quat(mu.to_radian{60, 50, 0, 0}, true))
    lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    eid = create_animation_test()
end

function m:post_init()
    create_camera()
    
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
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


local status = {
    current_animation = 'idle'
}

local checkboxSkeletonView = imgui_util.checkbox {
    label = "Skeleton View",
    enable = function ()
        world:disable_tag(eid, "can_render")
    end,
    disable = function ()
        world:enable_tag(eid, "can_render")
    end,
}

local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function m:ui_update()
    local e = world[eid]
    local widget = imgui.widget
    for _ in imgui_util.windows("Test", wndflags) do
        for name in sortpairs(e.animation.anilist) do
            if widget.Selectable(name, status.current_animation == name) then
                status.current_animation = name
                local animation = world:interface "ant.animation|animation"
                if not animation.set_state(e, name) then
                    animation.play(e, name, 0.5)
                end
            end
        end
        imgui.cursor.Separator()
        checkboxSkeletonView:update()
    end
end

local m = ecs.system "draw_skeleton"
local drawer = world:interface "ant.render|iwidget_drawer"
local asset = import_package "ant.asset"
m.require_interface "ant.render|iwidget_drawer"
function m:widget()
    if not checkboxSkeletonView.selected then
        return
    end
    for _, eid in world:each "animation" do
        local e = world[eid]
        local ske = asset.mgr.get_resource(e.skeleton.ref_path)
        drawer.draw_skeleton(ske.handle, e.pose_result.result, e.transform)
    end
end
