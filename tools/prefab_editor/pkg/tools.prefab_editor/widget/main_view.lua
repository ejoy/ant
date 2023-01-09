local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util

local uiconfig  = require "widget.config"

local imgui = require "imgui"
local irq   = ecs.import.interface "ant.render|irenderqueue"
local igui  = ecs.import.interface "tools.prefab_editor|igui"
local event_mouse   = world:sub {"mouse"}

local mouse_pos_x
local mouse_pos_y
local drag_file

local m = {}

function igui.cvt2scenept(x, y)
    return x - world.args.viewport.x, y - world.args.viewport.y
end

local function in_view(x, y)
    return mu.pt2d_in_rect(x, y, irq.view_rect "tonemapping_queue")
end

function m.show()
    for _, _, _, x, y in event_mouse:unpack() do
        mouse_pos_x = x
        mouse_pos_y = y
    end
    --drag file to view
    if imgui.util.IsMouseDragging(0) then
        --local x, y = imgui.util.GetMousePos()
        if mouse_pos_x and in_view(igui.cvt2scenept(mouse_pos_x, mouse_pos_y)) then
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

    local imgui_vp = imgui.GetMainViewport()
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
            "NoDockingInCentralNode",
            "PassthruCentralNode",
        })
        --NOTE: the coordinate reture from BuilderGetCentralRect function is relative to full viewport
        local x, y, ww, hh = imgui.dock.BuilderGetCentralRect "MainViewSpace"
        local mp = imgui_vp.MainPos
        x, y = x - mp[1], y - mp[2]
        local vp = world.args.viewport
        if x ~= vp.x or y ~= vp.y or ww ~= vp.w or hh ~= vp.h then
            vp.x, vp.y, vp.w, vp.h = x, y, ww, hh
            world:pub{"world_viewport_changed", vp}
            world:pub{"resize", ww, hh}
            -- TODO: remove this
            local mq = w:first("main_queue camera_ref:in render_target:in")
            local camera <close> = w:entity(mq.camera_ref)
            w:extend(camera, "scene_needchange:out")
            camera.scene_needchange = true
        end
    end
    imgui.windows.PopStyleVar(3)
    imgui.windows.End()
end

return m