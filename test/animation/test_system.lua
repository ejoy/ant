local ecs = ...
local world = ecs.world

local renderpkg  = import_package 'ant.render'
local mathpkg    = import_package "ant.math"
local asset      = import_package "ant.asset"
local imgui      = require "imgui"
local imgui_util = require "imgui_util"
local fs         = require 'filesystem'
local ms, mu     = mathpkg.stack, mathpkg.util
local lu         = renderpkg.light

local camera = world:interface "ant.render|camera"
local drawer = world:interface "ant.render|iwidget_drawer"

local m = ecs.system 'init_loader'

m.require_system "ant.imguibase|imgui_system"
m.require_interface "ant.render|camera"
m.require_interface "ant.animation|animation"
m.require_interface "ant.render|iwidget_drawer"

m.require_system "camera_controller2"

local function load_file(file)
    local f = assert(fs.open(fs.path(file), 'r'))
    local data = f:read 'a'
    f:close()
    return data
end

local eid

function m:init()
    lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, ms:euler2quat(mu.to_radian{60, 50, 0, 0}, true))
    lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    eid = world:create_entity(load_file 'entity.txt')
end

function m:post_init()
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
    for _ in imgui_util.windows("Test", wndflags) do
        for name in sortpairs(e.animation.anilist) do
            if imgui.widget.Selectable(name, status.current_animation == name) then
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
