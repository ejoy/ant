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
local rhwi       = renderpkg.hwi

local drawer = world:interface "ant.render|iwidget_drawer"

local m = ecs.system 'init_loader'

m.require_system "ant.imguibase|imgui_system"
m.require_interface "ant.animation|animation"
m.require_interface "ant.render|iwidget_drawer"

m.require_system "camera_controller"

local function load_file(file)
    local f = assert(fs.open(fs.path(file), 'r'))
    local data = f:read 'a'
    f:close()
    return data
end

local RoleEntityId

function m:init()
    lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, ms:euler2quat(mu.to_radian{60, 50, 0, 0}, true))
    lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    RoleEntityId = world:create_entity(load_file 'entity.txt')
end

function m:post_init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end

local function sort(t)
    local r = {}
    for k in pairs(t) do
        r[#r+1] = k
    end
    table.sort(r)
    return r
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

local checkboxSkeletonView = imgui_util.checkbox {
    label = "Skeleton View",
    enable = function ()
        world:disable_tag(RoleEntityId, "can_render")
    end,
    disable = function ()
        world:enable_tag(RoleEntityId, "can_render")
    end,
}

local listAnimation = imgui_util.list {
    selected = 'idle',
    select = function (_, value)
        local animation = world:interface "ant.animation|animation"
        local e = world[RoleEntityId]
        if not animation.set_state(e, value) then
            animation.play(e, value, 0.5)
        end
    end,
}

local listCamera = imgui_util.list {
    selected = "Camera Rotate",
    lst = {"Camera Rotate","Camera Pan","Camera Zoom"},
    select = function() end,
}

local wndflags = imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }

function m:ui_update()
    local e = world[RoleEntityId]
    for _ in imgui_util.windows("Test", wndflags) do
        listAnimation.lst = sort(e.animation.anilist)
        listAnimation:update()
        imgui.cursor.Separator()
        checkboxSkeletonView:update()
        imgui.cursor.Separator()
        listCamera:update()
        if imgui.widget.Selectable("Camera Reset", true) then
            world:pub {"camera","reset"}
        end
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

local eventMouse = world:sub {"mouse"}
local eventMouseWheel = world:sub {"mouse_wheel"}
local kRotationSpeed <const> = 1
local kZoomSpeed <const> = 1
local kPanSpeed <const> = 1
local kWheelSpeed <const> = 0.5
local lastMouse
local lastX, lastY

local function mouseRotate(dx, dy)
    world:pub { "camera", "rotate", dx*kRotationSpeed, dy*kRotationSpeed }
end

local function mouseZoom(_, dy)
    world:pub { "camera", "zoom", -dy*kZoomSpeed }
end

local function mousePan(dx, dy)
    world:pub { "camera", "pan", dx*kPanSpeed, dy*kPanSpeed }
end

local function mouseEvent(what, dx, dy)
    if listCamera.selected == "Camera Rotate" then
        if what == "LEFT" then
            mouseRotate(dx, dy)
        else
            mouseZoom(dx, dy)
        end
    elseif listCamera.selected == "Camera Pan" then
        if what == "LEFT" then
            mousePan(dx, dy)
        else
            mouseZoom(dx, dy)
        end
    elseif listCamera.selected == "Camera Zoom" then
        if what == "LEFT" then
            mouseZoom(dx, dy)
        end
    end
end

function m:data_changed()
    for _,what,state,x,y in eventMouse:unpack() do
        if state == "DOWN" then
            lastX, lastY = x, y
            lastMouse = what
        elseif state == "MOVE" and lastMouse == what then
            local dpiX, dpiY = rhwi.dpi()
            mouseEvent(what, (x - lastX) / dpiX, (y - lastY) / dpiY)
            lastX, lastY = x, y
        end
    end
    for _,delta in eventMouseWheel:unpack() do
        world:pub { "camera", "zoom", -delta*kWheelSpeed }
    end
end
