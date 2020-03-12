local ecs = ...
local world = ecs.world

local renderpkg  = import_package 'ant.render'
local mathpkg    = import_package "ant.math"
local asset      = import_package "ant.asset"
local imgui      = require "imgui"
local imgui_util = require "imgui_util"
local fs         = require 'filesystem'
local mu         = mathpkg.util
local lu         = renderpkg.light
local rhwi       = renderpkg.hwi

local math3d     = require "math3d"

local drawer = world:interface "ant.render|iwidget_drawer"

local m = ecs.system 'init_loader'

m.require_system "ant.imguibase|imgui_system"
m.require_system "camera_controller"
m.require_interface "ant.render|iwidget_drawer"
m.require_interface "ant.animation|animation"

local RoleEntityId
local eventResize = world:sub {"resize"}
local screensize  = {w=0,h=0}

local function load_file(file)
    local f = assert(fs.open(fs.path(file), 'r'))
    local data = f:read 'a'
    f:close()
    return data
end

function m:init()
    lu.create_directional_light_entity(world, "direction light", {1,1,1,1}, 2, math3d.quaternion(mu.to_radian{60, 50, 0, 0}, true))
    lu.create_ambient_light_entity(world, 'ambient_light', 'gradient', {1, 1, 1, 1})
    RoleEntityId = world:create_entity(load_file 'entity.txt')
end

function m:post_init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end

local status = {
    Pause = false,
    Loop = true,
    SkeletonView = false,
    CameraMode = "rotate",
    AnimationRatio =  {
        0,
        min = 0,
        max = 1,
        format = "",
    }
}

local function playAnimation(e, name)
    local ani = e.animation.anilist[name]
    if status.Loop then
        ani.max_ratio = math.maxinteger
    else
        ani.max_ratio = 1
    end
    e.animation.current = {
        animation = ani,
        ratio = 0,
    }
end

local function imguiBeginToolbar()
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.Button, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonActive, 0, 0, 0, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.ButtonHovered, 0, 0, 0, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.ItemSpacing, 0, 0)
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.FramePadding, 0, 3)
end

local function imguiEndToolbar()
    imgui.windows.PopStyleVar(2)
    imgui.windows.PopStyleColor(3)
end

local function imguiToolbar(text, tooltip, active)
    if active then
        imgui.windows.PushStyleColor(imgui.enum.StyleCol.Text, 0.4, 0.4, 0.4, 1)
    else
        imgui.windows.PushStyleColor(imgui.enum.StyleCol.Text, 0.6, 0.6, 0.6, 1)
    end
    local r = imgui.widget.Button(text)
    imgui.windows.PopStyleColor()
    if tooltip then
        imgui_util.tooltip(tooltip)
    end
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

function m:ui_update()
    local e = world[RoleEntityId]

    if not status.Loop and not status.Pause and e.animation.current.ratio >= 1 then
        world:enable_system("ant.animation|animation_system", false)
        status.Pause = true
        e.animation.current.ratio = 0
    end

    for _ in imgui_util.windows("Animation", imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }) do
        for name in sortpairs(e.animation.anilist) do
            if imgui.widget.Selectable(name, e.animation.current.animation.name == name) then
                playAnimation(e, name)
            end
        end
    end

    imgui.windows.SetNextWindowPos(0, screensize.h - 170)
    for _ in imgui_util.windows("Controll", imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" }) do
        imguiBeginToolbar()
        if imguiToolbar("💀", status.SkeletonView and  "Disable Skeleton View" or "Enable Skeleton View", status.SkeletonView) then
            if status.SkeletonView then
                status.SkeletonView = false
                world:enable_tag(RoleEntityId, "can_render")
            else
                status.SkeletonView = true
                world:disable_tag(RoleEntityId, "can_render")
            end
        end
        if imguiToolbar("🔄", "Rotate", status.CameraMode == "rotate") then
            status.CameraMode = "rotate"
        end
        if imguiToolbar("🤚", "Pan", status.CameraMode == "pan") then
            status.CameraMode = "pan"
        end
        if imguiToolbar("🔍", "Zoom", status.CameraMode == "zoom") then
            status.CameraMode = "zoom"
        end
        if imguiToolbar("🔴", "Reset Camera", true) then
            world:pub {"camera","reset"}
        end
        imguiEndToolbar()
    end

    imgui.windows.SetNextWindowPos(0, screensize.h - 40)
    imgui.windows.SetNextWindowSize(screensize.w, 40)
    for _ in imgui_util.windows("Progress", imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" }) do
        imguiBeginToolbar()
        if imguiToolbar(status.Pause and "▶" or "⏸", nil, true) then
            world:enable_system("ant.animation|animation_system", status.Pause)
            status.Pause = not status.Pause
        end
        imgui.cursor.SameLine()
        if imguiToolbar(status.Loop and "🔁" or "➡", nil, true) then
            if status.Loop then
                status.Loop = false
                e.animation.current.animation.max_ratio = 1
                e.animation.current.ratio = e.animation.current.ratio % 1
            else
                status.Loop = true
                e.animation.current.animation.max_ratio = math.maxinteger
            end
        end
        imguiEndToolbar()
        imgui.cursor.SameLine()
        imgui.cursor.SetNextItemWidth(screensize.w-80)
        local e = world[RoleEntityId]
        status.AnimationRatio[1] = e.animation.current.ratio % 1
        if imgui.widget.SliderFloat("", status.AnimationRatio) then
            e.animation.current.ratio = status.AnimationRatio[1]
            if status.Pause then
                local animation = world:interface "ant.animation|animation"
                animation.update(e)
            end
        end
    end
end

function m:widget()
    if not status.SkeletonView then
        return
    end
    local e = world[RoleEntityId]
    local ske = asset.mgr.get_resource(e.skeleton.ref_path)
    drawer.draw_skeleton(ske.handle, e.pose_result.result, e.transform)
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
    if status.CameraMode == "rotate" then
        if what == "LEFT" then
            mouseRotate(dx, dy)
        else
            mouseZoom(dx, dy)
        end
    elseif status.CameraMode == "pan" then
        if what == "LEFT" then
            mousePan(dx, dy)
        else
            mouseZoom(dx, dy)
        end
    elseif status.CameraMode == "zoom" then
        if what == "LEFT" then
            mouseZoom(dx, dy)
        end
    end
end

function m:data_changed()
	for _,w, h in eventResize:unpack() do
		screensize.w = w
		screensize.h = h
	end
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
