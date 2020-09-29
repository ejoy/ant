local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local hierarchy = require "hierarchy"

local gizmo
local m = {}
local world
local asset_mgr
local source_eid = nil
local target_eid = nil
local iom
local iss

local function is_editable(eid)
    if not iom.srt(eid) or
        not hierarchy:is_visible(eid) or
        hierarchy:is_locked(eid) then
        return false
    end
    return true
end

local menu_name = "entity context menu"
local function node_context_menu(eid)
    if imgui.windows.BeginPopupContextItem(eid) then
        local current_lock = hierarchy:is_locked(eid)
        if imgui.widget.Selectable(current_lock and "Unlock" or "lock", false) then
            world:pub { "EntityState", "lock", eid, not current_lock }
        end
        local current_visible = hierarchy:is_visible(eid)
        if imgui.widget.Selectable(current_visible and "Hide" or "Show", false) then
            world:pub { "EntityState", "visible", eid, not current_visible }
        end
        imgui.cursor.Separator()
        if imgui.widget.Selectable("Delete", false) then
            world:pub { "EntityState", "delete", eid }
        end
        imgui.windows.EndPopup()
    end
end
local function show_scene_node(node)
    local function select_or_move(nd)
        local eid = nd.eid
        if imgui.util.IsItemClicked() then
            if is_editable(eid) then
                gizmo:set_target(eid)
            end
        end
        if not world[eid].camera then
            if imgui.widget.BeginDragDropSource() then
                imgui.widget.SetDragDropPayload("DragNode", eid)
                imgui.widget.EndDragDropSource()
            end
            if imgui.widget.BeginDragDropTarget() then
                local payload = imgui.widget.AcceptDragDropPayload("DragNode")
                if payload then
                    source_eid = tonumber(payload)
                    target_eid = eid
                end
                imgui.widget.EndDragDropTarget()
            end
        end
    end
    local icons = require "common.icons"(asset_mgr)
    local function lock_visible(eid)
        imgui.cursor.NextColumn()
        imgui.util.PushID(eid)
        local current_lock = hierarchy:is_locked(eid)
        local icon = current_lock and icons.ICON_LOCK or icons.ICON_UNLOCK
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            world:pub { "EntityState", "lock", eid, not current_lock }
        end
        imgui.util.PopID()
        imgui.cursor.SameLine()
        imgui.util.PushID(eid)
        local current_visible = hierarchy:is_visible(eid)
        icon = current_visible and icons.ICON_VISIBLE or icons.ICON_UNVISIBLE
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            world:pub { "EntityState", "visible", eid, not current_visible }
        end
        imgui.util.PopID()
        imgui.cursor.NextColumn()
    end
    local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((gizmo.target_eid == node.eid) and imgui.flags.TreeNode{"Selected"} or 0)
    if not node.display_name then
        hierarchy:update_display_name(node.eid, world[node.eid].name)
    end
    if #node.children == 0 then
        imgui.widget.TreeNode(node.display_name, base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
        node_context_menu(node.eid)
        select_or_move(node)
        lock_visible(node.eid)
    else
        local open = imgui.widget.TreeNode(node.display_name, base_flags)
        node_context_menu(node.eid)
        select_or_move(node)
        lock_visible(node.eid)
        if open then
            for _, child in ipairs(node.children) do
                show_scene_node(child)
            end
            imgui.widget.TreePop()
        end
    end
end

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.SceneWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')

    for _ in uiutils.imgui_windows("Hierarchy", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        if imgui.widget.Button("CreateCamera") then
            world:pub { "Create", "camera"}
        end
        imgui.cursor.Separator()
        for i, child in ipairs(hierarchy.root.children) do
            imgui.cursor.Columns(2, "SceneColumns", true)
            imgui.cursor.SetColumnOffset(2, imgui.windows.GetWindowContentRegionWidth() - 60)
            source_eid = nil
            target_eid = nil
            show_scene_node(child)
            imgui.cursor.NextColumn()
            if source_eid and target_eid then
                hierarchy:set_parent(source_eid, target_eid)
                local sourceWorldMat = iom.calc_worldmat(source_eid)
                local targetWorldMat = iom.calc_worldmat(target_eid)
                iom.set_srt(source_eid, math3d.mul(math3d.inverse(targetWorldMat), sourceWorldMat))
                iss.set_parent(source_eid, target_eid)
                world:pub {"EntityEvent", "parent", source_eid}
            end
            imgui.cursor.Columns(1)
        end
    end
end

return function(w, am)
    world = w
    asset_mgr = am
    iom = world:interface "ant.objcontroller|obj_motion"
    iss = world:interface "ant.scene|iscenespace"
    gizmo = require "gizmo.gizmo"(world)
    return m
end