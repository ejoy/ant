local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local uiconfig  = require "widget.config"
local icons     = require "common.icons"
local imgui = require "imgui"
local irq   = ecs.require "ant.render|render_system.renderqueue"

local drag_file

local m = {}

local function cvt2scenept(x, y)
    return x - world.args.scene.viewrect.x, y - world.args.scene.viewrect.y
end

local function in_view(x, y)
    return mu.pt2d_in_rect(x, y, irq.view_rect "main_queue")
end

function m.show()
    local imgui_vp = imgui.GetMainViewport()
    if not icons.scale then
        icons.scale = imgui_vp.DpiScale
    end
    --drag file to view
    if imgui.util.IsMouseDragging(0) then
        local x, y = imgui.util.GetMousePos()
        x, y = x - imgui_vp.MainPos[1], y - imgui_vp.MainPos[2]
        if in_view(cvt2scenept(x, y)) then
            if not drag_file then
                local dropdata = imgui.widget.GetDragDropPayload()
                if dropdata and (string.sub(dropdata, -7) == ".prefab"
                    or string.sub(dropdata, -4) == ".efk" or string.sub(dropdata, -4) == ".glb") then
                    drag_file = dropdata
                end
            end
        else
            drag_file = nil
        end
    else
        if drag_file then
            world:pub {"AddPrefabOrEffect", drag_file}
            drag_file = nil
        end
    end

    local wp, ws = imgui_vp.WorkPos, imgui_vp.WorkSize
    local posx, posy = wp[1], wp[2]+uiconfig.ToolBarHeight
    local sizew, sizeh = ws[1], ws[2]-uiconfig.ToolBarHeight
    imgui.windows.SetNextWindowPos(posx, posy)
    imgui.windows.SetNextWindowSize(sizew, sizeh)
    imgui.windows.SetNextWindowViewport(imgui_vp.ID)
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0.0);
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowBorderSize, 0.0);
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowPadding, 0.0, 0.0);
    if imgui.windows.Begin("MainView", imgui.flags.Window {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }) then
        imgui.dock.Space("MainViewSpace", imgui.flags.DockNode {
            "NoDockingOverCentralNode",
            "PassthruCentralNode",
        })
        --NOTE: the coordinate reture from BuilderGetCentralRect function is relative to full viewport
        local x, y, ww, hh = imgui.dock.BuilderGetCentralRect "MainViewSpace"
        local mp = imgui_vp.MainPos
        x, y = x - mp[1], y - mp[2]
        local vp = world.args.device_size
        local resolution = world.args.scene.resolution
        local aspect_ratio = resolution.w/resolution.h
        local vr = mu.get_fix_ratio_scene_viewrect(vp, aspect_ratio, world.args.scene.scene_ratio)
        if x ~= vp.x or y ~= vp.y or ww ~= vp.w or hh ~= vp.h then
            vp.x, vp.y, vp.w, vp.h = x, y, ww, hh
            world:dispatch_message {
                type = "set_viewport",
                viewport = vp,
            }
            world:pub{"resize", ww, hh}
            world:pub{"scene_viewrect_changed", vr}
        end
    end
    imgui.windows.PopStyleVar(3)
    imgui.windows.End()
end

return m