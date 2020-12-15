local ecs = ...
local world = ecs.world

local imgui      = require "imgui"
local imgui_util = require "imgui_util"
local ientity = world:interface "ant.render|entity"

local drawer = world:interface "ant.render|iwidget_drawer"
local irq = world:interface "ant.render|irenderqueue"
local init_loader_sys = ecs.system 'init_loader_system'

local RoleEntityId
local eventResize = world:sub {"resize"}
local screensize  = {w=0,h=0}

local function create_prefab(prefab, srt)
    local eid = world:create_entity {
        policy = {
            "ant.scene|transform_policy",
        },
        data = {
            transform = srt,
            scene_entity = true,
        }
    }
    return world:instance(prefab, {
        action = {root = eid},
    })
end

function init_loader_sys:init()
    ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)
    world:instance "res/light_directional.prefab"

    create_prefab("res/gltf_animation.prefab", {
        t = {0,0,2}
    })

    create_prefab("res/gltf_animation.prefab", {
        t = {2,0,0}
    })

    local res = create_prefab("res/gltf_animation.prefab", {
        t = {0,0,0}
    })
    RoleEntityId = res[2]
    world:enable_tag(RoleEntityId, "show_operate_gizmo")
end

function init_loader_sys:post_init()
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0xa0a0a0ff)
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
    local ani = e.animation[name]
    if status.Loop then
        ani._max_ratio = math.maxinteger
    else
        ani._max_ratio = 1
    end
    e._animation._current = {
        animation = ani,
        event_state = {
            next_index = 1,
            keyframe_events = e.keyframe_events[name]
        },
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

function init_loader_sys:ui_update()
    local e = world[RoleEntityId]

    if not status.Loop and not status.Pause and e._animation._current.ratio >= 1 then
        world:enable_system("ant.animation|animation_system", false)
        status.Pause = true
        e._animation._current.ratio = 0
    end

    for _ in imgui_util.windows("Animation", imgui.flags.Window { "NoTitleBar", "NoResize", "NoScrollbar" }) do
        for name in sortpairs(e.animation) do
            if imgui.widget.Selectable(name, e._animation._current.animation.name == name) then
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
                e._animation._current.animation.max_ratio = 1
                e._animation._current.ratio = e._animation._current.ratio % 1
            else
                status.Loop = true
                e._animation._current.animation.max_ratio = math.maxinteger
            end
        end
        imguiEndToolbar()
        imgui.cursor.SameLine()
        imgui.cursor.SetNextItemWidth(screensize.w-80)
        local e = world[RoleEntityId]
        status.AnimationRatio[1] = e._animation._current.ratio % 1
        if imgui.widget.SliderFloat("", status.AnimationRatio) then
            e._animation._current.ratio = status.AnimationRatio[1]
            if status.Pause then
                local animation = world:interface "ant.animation|animation"
                animation.update(e)
            end
        end
    end
end

function init_loader_sys:widget()
    if not status.SkeletonView then
        return
    end
    local e = world[RoleEntityId]
    local ske = e.skeleton
    drawer.draw_skeleton(ske._handle, e.pose_result, e.transform)
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

function init_loader_sys:data_changed()
	for _,w, h in eventResize:unpack() do
		screensize.w = w
		screensize.h = h
	end
    --for _,what,state,x,y in eventMouse:unpack() do
    --    if state == "DOWN" then
    --        lastX, lastY = x, y
    --        lastMouse = what
    --    elseif state == "MOVE" and lastMouse == what then
    --        local dpiX, dpiY = rhwi.dpi()
    --        mouseEvent(what, (x - lastX) / dpiX, (y - lastY) / dpiY)
    --        lastX, lastY = x, y
    --    end
    --end
    for _,delta in eventMouseWheel:unpack() do
        world:pub { "camera", "zoom", -delta*kWheelSpeed }
    end
end
