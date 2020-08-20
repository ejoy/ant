local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local hierarchy = require "hierarchy"

local m = {}
local world
local asset_mgr
local sourceEid = nil
local targetEid = nil
local gizmo
local iom
local iss
function m.set_gizmo(obj)
    gizmo = obj
end

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
        if imgui.widget.BeginDragDropSource() then
            imgui.widget.SetDragDropPayload("DragNode", eid)
            imgui.widget.EndDragDropSource()
        end
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("DragNode")
            if payload then
                sourceEid = tonumber(payload)
                targetEid = eid
            end
            imgui.widget.EndDragDropTarget()
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

local viewStartY = uiconfig.WidgetStartY + uiconfig.ToolBarHeight

function m.show(rhwi)
    local sw, sh = rhwi.screen_size()
    imgui.windows.SetNextWindowPos(0, viewStartY, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.SceneWidgetWidth, sh - uiconfig.ResourceBrowserHeight - viewStartY, 'F')

    for _ in uiutils.imgui_windows("Hierarchy", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        if hierarchy.root.eid > 0 then
            if imgui.widget.Button("CreateCamera") then
                world:pub { "Create", "camera"}
            end
            imgui.cursor.Separator()
            imgui.cursor.Columns(2, "SceneColumns", true)
            imgui.cursor.SetColumnOffset(2, imgui.windows.GetWindowContentRegionWidth() - 60)
            sourceEid = nil
            targetEid = nil
            show_scene_node(hierarchy.root)
            imgui.cursor.NextColumn()
            if sourceEid and targetEid then
                hierarchy:set_parent(sourceEid, targetEid)
                local sourceWorldMat = iom.calc_worldmat(sourceEid)
                local targetWorldMat = iom.calc_worldmat(targetEid)
                iom.set_srt(sourceEid, math3d.mul(math3d.inverse(targetWorldMat), sourceWorldMat))
                iss.set_parent(sourceEid, targetEid)
                world:pub {"EntityEvent", "parent", sourceEid}
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
    return m
end