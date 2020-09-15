local ecs = ...
local world     = ecs.world
local math3d    = require "math3d"
local imgui     = require "imgui"
local rhwi      = import_package 'ant.render'.hwi
local asset_mgr  = import_package "ant.asset"
local irq = world:interface "ant.render|irenderqueue"
local iss = world:interface "ant.scene|iscenespace"
local iom = world:interface "ant.objcontroller|obj_motion"
local ies = world:interface "ant.scene|ientity_state"
local icamera = world:interface "ant.camera|camera"
local lfs  = require "filesystem.local"
local fs   = require "filesystem"
local vfs = require "vfs"
local hierarchy = require "hierarchy"
local resource_browser = require "ui.resource_browser"(world, asset_mgr)
local log_widget = require "ui.log_widget"(asset_mgr)
local console_widget = require "ui.console_widget"(asset_mgr)
local toolbar = require "ui.toolbar"(world, asset_mgr)
local scene_view = require "ui.scene_view"(world, asset_mgr)
local inspector = require "ui.inspector"(world)
local uiconfig = require "ui.config"
local uiutils = require "ui.utils"
local prefab_mgr = require "prefab_manager"(world)
local menu = require "ui.menu"(world, prefab_mgr)
local camera_mgr = require "camera_manager"(world)
local m = ecs.system 'gui_system'

local eventGizmo = world:sub {"Gizmo"}
local eventScene = world:sub {"Scene"}

local gizmo
local cmd_queue

local SELECT <const> = 0
local MOVE <const> = 1
local ROTATE <const> = 2
local SCALE <const> = 3


local icons = require "common.icons"(asset_mgr)

local viewStartY = uiconfig.WidgetStartY + uiconfig.ToolBarHeight

local dragFile = nil
local lastX = -1
local lastY = -1
local lastWidth = -1
local lastHeight = -1
local secondViewQueue
local secondViewWidth = 384
local secondViewHeight = 216
local secondCameraEID

local function chooseProject()
    if resourceRoot then return end

    if not imgui.windows.IsPopupOpen("Choose project") then
        imgui.windows.OpenPopup("Choose project")
    end

    local change, opened = imgui.windows.BeginPopupModal("Choose project", imgui.flags.Window{"AlwaysAutoResize"})
    if change then
        imgui.widget.Text("Create new or open existing project.")
        if imgui.widget.Button("Create project") then
            print("Create empty project")
            local filedialog = require 'filedialog'
            local dialog_info = {
                Owner = rhwi.native_window(),
                Title = "Choose project folder"
            }
            local ok, path = filedialog.open(dialog_info)
            if ok then
                
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Open project") then
            local filedialog = require 'filedialog'
            local dialog_info = {
                Owner = rhwi.native_window(),
                Title = "Choose project folder"
            }
            local ok, path = filedialog.open(dialog_info)
            if ok then
                resourceRoot = fs.path(path[1])
                --file server
                local cthread = require "thread"
                cthread.newchannel "log_channel"
                cthread.newchannel "fileserver_channel"
                cthread.newchannel "console_channel"
                local produce = cthread.channel_produce "fileserver_channel"
                produce:push(arg, path[1])
                local lthread = require "common.thread"
                fileserver_thread = lthread.create [[
                    package.path = "engine/?.lua;tools/prefab_editor/?.lua"
                    require "bootstrap"
                    local fileserver = require "fileserver_adapter"()
                    fileserver.run()
                ]]
                log_widget.init_log_receiver()
                console_widget.init_console_sender()
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Quit") then
            local res_root_str = tostring(fs.path "":localpath())
            resourceRoot = fs.path(string.sub(res_root_str, 1, #res_root_str - 1))
        end
        if resourceRoot then
            resource_browser.set_root(resourceRoot)
        end
        imgui.windows.EndPopup()
    end
end

local fileserver_thread

local function showDockSpace(offset_x, offset_y)
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(offset_x, offset_y)
    imgui.windows.SetNextWindowSize(sw - offset_x, sh - offset_y)
    --SetNextWindowViewport
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0.0);
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowBorderSize, 0.0);
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowPadding, 0.0, 0.0);
    local wndflags = imgui.flags.Window {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }
    local dockflags = imgui.flags.DockNode {
        "NoDockingInCentralNode",
        "PassthruCentralNode",
    }
    if not imgui.windows.Begin("DockSpace Demo", wndflags) then
        imgui.windows.PopStyleVar(3)
        imgui.windows.End()
        return
    end
    imgui.dock.Space("MyDockSpace", dockflags)
    local x,y,w,h = imgui.dock.BuilderGetCentralRect("MyDockSpace")
    imgui.windows.PopStyleVar(3)
    imgui.windows.End()
    return x,y,w,h
end

function m:ui_update()
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.TitleBg, 0.2, 0.2, 0.2, 1)
    chooseProject()
    menu.show()
    toolbar.show(rhwi)
    local x, y, width, height = showDockSpace(0, viewStartY)
    scene_view.show(rhwi)
    inspector.show(rhwi)
    resource_browser.show(rhwi)
    log_widget.show(rhwi)
    console_widget.show(rhwi)
    imgui.windows.PopStyleColor(2)
    imgui.windows.PopStyleVar()
    local dirty = false
    if lastX ~= x then lastX = x dirty = true end
    if lastY ~= y then lastY = y dirty = true  end
    if lastWidth ~= width then lastWidth = width dirty = true  end
    if lastHeight ~= height then lastHeight = height dirty = true  end
    if dirty then
        local viewport = {x = x, y = y, w = width, h = height}
        irq.set_view_rect(world:singleton_entity_id "main_queue", viewport)
        local secondViewport = {x = viewport.x + (width - secondViewWidth), y = viewport.y + (height - secondViewHeight), w = secondViewWidth, h = secondViewHeight}
        irq.set_view_rect(camera_mgr.second_view, secondViewport)
        world:pub {"ViewportDirty", viewport}
    end
    --drag file to view
    if imgui.util.IsMouseDragging(0) then
        local x, y = imgui.util.GetMousePos()
        if (x > lastX and x < (lastX + lastWidth) and y > lastY and y < (lastY + lastHeight)) then
            if not dragFile then
                local dropdata = imgui.widget.GetDragDropPayload()
                if dropdata and string.sub(dropdata, -7) == ".prefab" then
                    dragFile = dropdata
                end
            end
        else
            dragFile = nil
        end
    else
        if dragFile then
            world:pub {"AddPrefab", dragFile}
            dragFile = nil
        end
    end
end

local entityStateEvent = world:sub {"EntityState"}
local dropFilesEvent = world:sub {"OnDropFiles"}
local entityEvent = world:sub {"EntityEvent"}
local eventKeyboard = world:sub{"keyboard"}
local eventOpenPrefab = world:sub {"OpenPrefab"}
local eventAddPrefab = world:sub {"AddPrefab"}
local eventResourceBrowser = world:sub {"ResourceBrowser"}
local eventWindowTitle = world:sub {"WindowTitle"}
local eventCreate = world:sub {"Create"}
local window = require "window"
local light_gizmo = require "gizmo.directional_light"(world)

local function onTarget(old, new)
    if old then
        if world[old].camera then
            camera_mgr.show_frustum(old, false)
        elseif world[old].light_type == "directional" then
            light_gizmo.show(false)
        end
    end
    if new then
        if world[new].camera then
            camera_mgr.set_second_camera(new, true)
        elseif world[new].light_type == "directional" then
            light_gizmo.show(true)
        end
    end
end

local function onUpdate(eid)
    if not eid then return end

    if world[eid].camera then
        camera_mgr.update_frustrum(eid)
    elseif world[eid].light_type == "directional" then
        light_gizmo.update()
    end
end

function m:data_changed()
    for _, action, value1, value2 in eventGizmo:unpack() do
        if action == "update" or action == "ontarget" then
            inspector.update_ui(action == "update")
            if action == "ontarget" then
                onTarget(value1, value2)
            elseif action == "update" then
                onUpdate(gizmo.target_eid)
            end
        elseif action == "create" then
            gizmo = value1
            cmd_queue = value2
            inspector.set_gizmo(gizmo)
            scene_view.set_gizmo(gizmo)
        end
    end
    for _, what, target, v1, v2 in entityEvent:unpack() do
        local dirty = false
        if what == "move" then
            cmd_queue:record {action = MOVE, eid = target, oldvalue = v1, newvalue = v2}
            dirty = true
        elseif what == "rotate" then
            cmd_queue:record {action = ROTATE, eid = target, oldvalue = v1, newvalue = v2}
            dirty = true
        elseif what == "scale" then
            cmd_queue:record {action = SCALE, eid = target, oldvalue = v1, newvalue = v2}
            dirty = true
        elseif what == "name" then
            local template = hierarchy:get_template(target)
            template.template.data.name = v1
            hierarchy:update_display_name(target, v1)
        elseif what == "parent" then
            dirty = true
        end
        if dirty then
            inspector.update_template_tranform(target)
        end
    end
    for _, what, eid, value in entityStateEvent:unpack() do
        if what == "visible" then
            hierarchy:set_visible(eid, value)
            ies.set_state(eid, what, value)
            local template = hierarchy:get_template(eid)
            if template and template.children then
                for _, e in ipairs(template.children) do
                    ies.set_state(e, what, value)
                end
            end
        elseif what == "lock" then
            hierarchy:set_lock(eid, value)
        elseif what == "delete" then
            prefab_mgr:remove_entity(eid)
        end
    end
    for _, filename in eventOpenPrefab:unpack() do
        prefab_mgr:open_prefab(filename)
    end
    for _, filename in eventAddPrefab:unpack() do
        prefab_mgr:add_prefab(filename)
    end
    for _, files in dropFilesEvent:unpack() do
        on_drop_files(files)
    end

    for _, what in eventResourceBrowser:unpack() do
        if what == "dirty" then
            resource_browser.dirty = true
        end
    end

    for _, what in eventWindowTitle:unpack() do
        local title = "PrefabEditor - " .. what
        window.set_title(rhwi.native_window(), title)
        gizmo.target_eid = nil
    end

    for _, key, press, state in eventKeyboard:unpack() do
        if key == "DELETE" and press == 1 then
            prefab_mgr:remove_entity(gizmo.target_eid)
            gizmo.target_eid = nil
        elseif state.CTRL and key == "S" and press == 1 then
            prefab_mgr:save_prefab()
        end
    end

    for _, what in eventCreate:unpack() do
        prefab_mgr:create(what)
    end
end
