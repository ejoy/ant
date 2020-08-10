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
local prefab_view = require "prefab_view"
local resource_browser = require "ui.resource_browser"(world, asset_mgr)
local toolbar = require "ui.toolbar"(world, asset_mgr)
local scene_view = require "ui.scene_view"(world, asset_mgr)
local inspector = require "ui.inspector"(world)
local uiconfig = require "ui.config"
local uiutils = require "ui.utils"
local prefab_mgr = require "prefab_manager"
local menu = require "ui.menu"(world, prefab_mgr)
local global_data = require "common.global_data"
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

local dragFile = false
local lastX = -1
local lastY = -1
local lastWidth = -1
local lastHeight = -1
local secondViewQueue
local secondViewWidth = 384
local secondViewHeight = 216
local secondCameraEID
function m:ui_update()
    if not resourceRoot then
        local res_root_str = tostring(fs.path "":localpath())
        resourceRoot = fs.path(string.sub(res_root_str, 1, #res_root_str - 1))
        resource_browser.set_root(resourceRoot)
    end
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.TitleBg, 0.2, 0.2, 0.2, 1)
    menu.show()
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
        local secondViewport = {x = viewport.x + (width - secondViewWidth), y = viewport.y + (height - secondViewHeight), w = secondViewWidth, h = secondViewHeight}
        irq.set_view_rect(global_data.second_view, secondViewport)
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

function update_second_view_camera()
    if not secondCameraEID then return end
    local rc = world[secondCameraEID]._rendercache
    -- local worldmat = rc.worldmat
    -- rc.viewmat = math3d.lookto(math3d.index(worldmat, 4), math3d.index(worldmat, 3), rc.updir)
    -- rc.projmat = math3d.projmat(rc.frustum)
    -- rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)
    rc.viewmat = icamera.calc_viewmat(secondCameraEID)
    rc.projmat = icamera.calc_projmat(secondCameraEID)
    rc.viewprojmat = icamera.calc_viewproj(secondCameraEID)
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
function m:data_changed()
    
    update_second_view_camera()

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
            local template = prefab_view:get_template(target)
            template.template.data.name = v1
        end
        if dirty then
            inspector.update_template_tranform(eid)
        end
    end
    for _, what, eid, value in entityStateEvent:unpack() do
        if what == "visible" then
            prefab_view:set_visible(eid, value)
            ies.set_state(eid, what, value)
            local template = prefab_view:get_template(eid)
            if template.children then
                for _, e in ipairs(template.children) do
                    ies.set_state(e, what, value)
                end
            end
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
