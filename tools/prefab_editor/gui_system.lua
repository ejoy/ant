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
local lfs  = require "filesystem.local"
local fs   = require "filesystem"
local vfs = require "vfs"
local prefab_view = require "prefab_view"
local resource_browser = require "ui.resource_browser"(world, asset_mgr)
local toolbar = require "ui.toolbar"(world, asset_mgr)
local scene_view = require "ui.scene_view"(world, asset_mgr)
local inspector = require "ui.inspector"(world)
local uiconfig = require "ui.config"
local uiutils = require "ui.utils"
local prefab_mgr = require "prefab_manager"

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

local function showMenu()
    if imgui.widget.BeginMainMenuBar() then
        if imgui.widget.BeginMenu("File") then
            if imgui.widget.MenuItem("New", "Ctrl+N") then

            end
            if imgui.widget.MenuItem("Open", "Ctrl+O") then

            end
            if imgui.widget.MenuItem("Save", "Ctrl+S") then
                prefab_mgr:save_prefab()
            end
            if imgui.widget.MenuItem("Save As..") then
                local filedialog = require 'filedialog'
                local dialog_info = {
                    Owner = rhwi.native_window(),
                    Title = "Save As..",
                    FileTypes = {"Prefab", "*.prefab" }
                }
                local ok, path = filedialog.save(dialog_info)
                if ok then
                    prefab_mgr:save_prefab(path .. ".prefab")
                end
            end
            imgui.widget.EndMenu()
        end
        if imgui.widget.BeginMenu("Edit") then
            if imgui.widget.MenuItem("Undo", "CTRL+Z") then
            end

            if imgui.widget.MenuItem("Redo", "CTRL+Y", false, false) then
            end

            if imgui.widget.MenuItem("SaveUILayout") then
                local setting = imgui.util.SaveIniSettings()
                local current_path = lfs.current_path()
                local wf = assert(lfs.open(fs.path "":localpath() .. "/" .. "imgui.layout", "wb"))
                wf:write(setting)
                wf:close()
            end
            imgui.widget.EndMenu()
        end
        imgui.widget.EndMainMenuBar()
    end
end

local viewStartY = uiconfig.WidgetStartY + uiconfig.ToolBarHeight
local entityStateEvent = world:sub {"EntityState"}
local dropFilesEvent = world:sub {"OnDropFiles"}
local entityEvent = world:sub {"EntityEvent"}
local mouseMove = world:sub {"mousemove"}
local dragFile = false
local lastX = -1
local lastY = -1
local lastWidth = -1
local lastHeight = -1
function m:ui_update()
    if not resourceRoot then
        local res_root_str = tostring(fs.path "":localpath())
        resourceRoot = fs.path(string.sub(res_root_str, 1, #res_root_str - 1))
        resource_browser.set_root(resourceRoot)
    end
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.TitleBg, 0.2, 0.2, 0.2, 1)
    showMenu()
    toolbar.show(rhwi)
    local x, y, width, height = imgui.showDockSpace(0, viewStartY)
    scene_view.show(rhwi)
    inspector.show(rhwi)
    resource_browser.show(rhwi)
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
        world:pub {"ViewportDirty", viewport}
    end
    --drag file to view
    if imgui.util.IsMouseDragging(0) then
        local x, y = imgui.util.GetMousePos()
        if (x > lastX and x < (lastX + lastWidth) and y > lastY and y < (lastY + lastHeight)) then
            if not dragFile then
                dragFile = imgui.widget.GetDragDropPayload()
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

local eventOpenPrefab = world:sub {"OpenPrefab"}
local eventAddPrefab = world:sub {"AddPrefab"}
local eventResourceBrowser = world:sub {"ResourceBrowser"}
local eventWindowTitle = world:sub {"WindowTitle"}

local window = require "window"
function m:data_changed()
    for _, action, value1, value2 in eventGizmo:unpack() do
        if action == "update" or action == "ontarget" then
            inspector.update_ui(action == "update")
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
            local template = prefab_view:get_template(eid)
            template.template.data.name = name
        end
        if dirty then
            inspector.update_template_tranform(eid)
        end
    end
    for _, what, eid, value in entityStateEvent:unpack() do
        if what == "visible" then
            prefab_view:set_visible(eid, value)
            ies.set_state(eid, what, value)
        elseif what == "lock" then
            prefab_view:set_lock(eid, value)
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
    end
end
