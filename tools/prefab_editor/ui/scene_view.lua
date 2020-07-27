local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "ui.config"
local uiutils   = require "ui.utils"
local prefab_view = require "prefab_view"

local m = {}
local world
local asset_mgr
local entity_mgr
local sourceEid = nil
local targetEid = nil
local gizmo

function m.set_gizmo(obj)
    gizmo = obj
end

local function is_editable(eid)
    local iom = world:interface "ant.objcontroller|obj_motion"
    if not iom.srt(eid) or
        not entity_mgr:is_visible(eid) or
        entity_mgr:is_locked(eid) then
        return false
    end
    return true
end

local function show_scene_node(node)
    local icons = require "common.icons"(asset_mgr)
    local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((gizmo.target_eid == node.eid) and imgui.flags.TreeNode{"Selected"} or 0)
    local name = world[node.eid].name
    local function select_or_move(eid)
        if imgui.util.IsItemClicked() then
            if is_editable(eid) then
                gizmo:set_target(eid)
            end
        end
        if imgui.widget.BeginDragDropSource() then
            imgui.widget.SetDragDropPayload("Drag", eid)
            imgui.widget.EndDragDropSource()
        end
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("Drag")
            if payload then
                sourceEid = tonumber(payload)
                targetEid = eid
            end
            imgui.widget.EndDragDropTarget()
        end
    end
    local function lock_visible(eid)
        imgui.cursor.NextColumn()
        local icon
        if entity_mgr:is_locked(eid) then
            icon = icons.ICON_LOCK
        else
            icon = icons.ICON_UNLOCK
        end
        imgui.util.PushID(eid)
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            world:pub { "EntityState", "lock", eid, not entity_mgr:is_locked(eid) }
        end
        imgui.util.PopID()
        imgui.cursor.SameLine()
        if entity_mgr:is_visible(eid) then
            icon = icons.ICON_VISIBLE
        else
            icon = icons.ICON_UNVISIBLE
        end
        imgui.util.PushID(eid)
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            world:pub { "EntityState", "visible", eid, not entity_mgr:is_visible(eid) }
        end
        imgui.util.PopID()
        imgui.cursor.NextColumn()
    end
    if #node.children == 0 then
        imgui.widget.TreeNode(name, base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" })
        select_or_move(node.eid)
        lock_visible(node.eid)
    else
        local open = imgui.widget.TreeNode(name, base_flags)
        select_or_move(node.eid)
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

    for _ in uiutils.imgui_windows("Hierarchy", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) do
        if prefab_view.root.eid > 0 then
            imgui.cursor.Columns(2, "SceneColumns", true)
            imgui.cursor.SetColumnOffset(2, imgui.windows.GetWindowContentRegionWidth() - 60)
            sourceEid = nil
            targetEid = nil
            show_scene_node(prefab_view.root)
            imgui.cursor.NextColumn()
            if sourceEid and targetEid then
                prefab_view:set_parent(sourceEid, targetEid)
                local sourceWorldMat = iom.calc_worldmat(sourceEid)
                local targetWorldMat = iom.calc_worldmat(targetEid)
                iom.set_srt(sourceEid, math3d.mul(math3d.inverse(targetWorldMat), sourceWorldMat))
                iss.set_parent(sourceEid, targetEid)
            end
            imgui.cursor.Columns(1)
        end
    end
end

return function(w, am, em)
    world = w
    asset_mgr = am
    entity_mgr = em
    return m
end