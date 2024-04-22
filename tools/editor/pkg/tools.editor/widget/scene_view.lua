local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr  = import_package "ant.asset"
local gizmo     = ecs.require "gizmo.gizmo"
local hierarchy = ecs.require "hierarchy_edit"
local icons     = require "common.icons"
local faicons   = require "common.fa_icons"
local ImGui     = require "imgui"
local uiconfig  = require "widget.config"

local m = {}

local source_e = nil
local target_e = nil

local function is_editable(eid)
    return not hierarchy:is_locked(eid)
end

local function as_main_camera_mode()
    local mq = w:first("main_queue camera_ref:in")
    local sv = w:first("second_view camera_ref:in")
    return mq.camera_ref == sv.camera_ref
end

local function is_scene_node(eid)
    local info = hierarchy:get_node_info(eid)
    return (info.template.tag and info.template.tag[1] == "Scene")
end

local function can_delete(eid)
    -- TODO: cant't remove root node : Scene
    if is_scene_node(eid) then
        return false
    end
    local can = true
    if as_main_camera_mode() then
        local e <close> = world:entity(eid, "camera?in animation?in")
        if e.camera or e.animation then
            can = false
        else
            local children = hierarchy:get_node(eid).children
            if #children > 0 then
                --TODO: for camera
                local ce <close> = world:entity(children[1].eid, "camera?in")
                if ce.camera then
                    can = false
                end
            end
        end
    end
    return can
end

local function node_context_menu(eid)
    if gizmo.target_eid ~= eid then
        return
    end
    if ImGui.BeginPopupContextItemEx(tostring(eid)) then
        local current_lock = hierarchy:is_locked(eid)
        local tpl = hierarchy:get_node_info(eid)
        if not is_scene_node(eid) then
            if not tpl.filename then
                if ImGui.MenuItemEx(faicons.ICON_FA_CLONE.." Clone", "Ctrl+D") then
                    world:pub { "HierarchyEvent", "clone", eid }
                end
            end
            if ImGui.MenuItem(faicons.ICON_FA_ARROWS_UP_TO_LINE.." MoveTop") then
                world:pub { "HierarchyEvent", "movetop", eid }
            end
            if ImGui.MenuItem(faicons.ICON_FA_ARROW_UP.." MoveUp") then
                world:pub { "HierarchyEvent", "moveup", eid }
            end
        end
        ImGui.Separator()
        if ImGui.MenuItem(current_lock and faicons.ICON_FA_LOCK.." Unlock" or faicons.ICON_FA_LOCK_OPEN.." lock") then
            world:pub { "HierarchyEvent", "lock", eid, not current_lock }
        end
        local current_visible = hierarchy:is_visible(eid)
        if ImGui.MenuItem(current_visible and faicons.ICON_FA_EYE.." Hide" or faicons.ICON_FA_EYE_SLASH.." Show") then
            world:pub { "HierarchyEvent", "visible", hierarchy:get_node(eid), not current_visible }
        end
        if can_delete(eid) then
            ImGui.Separator()
            if ImGui.MenuItemEx(faicons.ICON_FA_TRASH.." Delete", "Delete") then
                world:pub { "HierarchyEvent", "delete", eid }
            end
        end
        if not is_scene_node(eid) then
            ImGui.Separator()
            if ImGui.MenuItem(faicons.ICON_FA_ARROW_DOWN.." MoveDown") then
                world:pub { "HierarchyEvent", "movedown", eid }
            end
            if ImGui.MenuItem(faicons.ICON_FA_ARROWS_DOWN_TO_LINE.." MoveBottom") then
                world:pub { "HierarchyEvent", "movebottom", eid }
            end
            ImGui.Separator()
            if ImGui.MenuItem("NoParent") then
                world:pub { "EntityEvent", "parent", eid }
            end
        end
        ImGui.EndPopup()
    end
end

local function get_icon_by_object_type(node)
    local template = hierarchy:get_node_info(node.eid)
    if template and template.filename then
        return icons.ICON_WORLD3D
    else
        local e <close> = world:entity(node.eid, "camera?in light?in mesh?in slot?in efk?in")
        if e.camera then
            return icons.ICON_CAMERA3D
        end
        if e.light then
            if e.light.type == "directional" then
                return icons.ICON_DIRECTIONALLIGHT
            elseif e.light.type == "point" then
                return icons.ICON_POINTLIGHT
            elseif e.light.type == "spot" then
                return icons.ICON_SPOTLIGHT
            end
        end
        if e.mesh then
            if e.collider then
                return icons.ICON_COLLISIONSHAPE3D
            else
                return icons.ICON_MESH
            end
        end
        if e.slot then
            return icons.ICON_SLOT
        end
        if e.efk then
            return icons.ICON_PARTICLES3D
        end

        return icons.ICON_OBJECT
    end
end
local imodifier 		= ecs.require "ant.modifier|modifier"
local function show_scene_node(node)
    ImGui.TableNextRow();
    ImGui.TableNextColumn();
    local function select_or_move(nd)
        local eid = nd.eid
        if ImGui.IsItemClicked() then
            -- ImGui.SetKeyboardFocusHere()
            if is_editable(eid) then
                gizmo:set_target({eid})
            end
            if imodifier.highlight then
                imodifier.set_target(imodifier.highlight, eid)
                imodifier.start(imodifier.highlight, {})
            end
        end

        if ImGui.BeginDragDropSource() then
            source_e = eid
            ImGui.SetDragDropPayload("DragNode", tostring(eid))
            ImGui.EndDragDropSource()
        end
        if ImGui.BeginDragDropTarget() then
            local payload = ImGui.AcceptDragDropPayload("DragNode")
            if payload then
                --source_e = tonumber(payload)
                target_e = eid
            end
            ImGui.EndDragDropTarget()
        end
    end
    local function lock_visible(nd)
        local eid = nd.eid
        ImGui.TableNextColumn()
        ImGui.PushID(tostring(eid))
        local current_lock = hierarchy:is_locked(eid)
        local icon = current_lock and icons.ICON_LOCK or icons.ICON_UNLOCK
        local imagesize = icon.texinfo.width * icons.scale
        if ImGui.ImageButton("lock", assetmgr.textures[icon.id], imagesize, imagesize) then
            world:pub { "HierarchyEvent", "lock", eid, not current_lock }
        end
        ImGui.PopID()
        ImGui.TableNextColumn()
        ImGui.PushID(tostring(eid))
        local current_visible = hierarchy:is_visible(eid)
        icon = current_visible and icons.ICON_VISIBLE or icons.ICON_UNVISIBLE
        imagesize = icon.texinfo.width * icons.scale
        if ImGui.ImageButton("visible", assetmgr.textures[icon.id], imagesize, imagesize) then
            world:pub { "HierarchyEvent", "visible", nd, not current_visible }
        end
        ImGui.PopID()
    end
    local base_flags = ImGui.TreeNodeFlags { "OpenOnArrow", "SpanFullWidth" } | ((gizmo.target_eid == node.eid) and ImGui.TreeNodeFlags {"Selected"} or 0)
    if not node.display_name then
        local name = node.info.template.tag and node.info.template.tag[1] or node.info.name
        hierarchy:update_display_name(node.eid, name or "")
    end

    local flags = base_flags
    local has_child = true
    if #node.children == 0 then
        flags = base_flags | ImGui.TreeNodeFlags { "Leaf", "NoTreePushOnOpen" }
        has_child = false
    end
    
    local current_icon = get_icon_by_object_type(node)
    local imagesize = current_icon.texinfo.width * icons.scale
    ImGui.Image(assetmgr.textures[current_icon.id], imagesize, imagesize)
    ImGui.SameLine()
    if not has_child then
        ImGui.IndentEx(-2)
    end
    local open = ImGui.TreeNodeEx(node.display_name, flags)
    if not has_child then
        ImGui.IndentEx(2)
    end
    node_context_menu(node.eid)
    select_or_move(node)

    lock_visible(node)
    if open and has_child then
        for _, child in ipairs(node.children) do
            show_scene_node(child)
        end
        ImGui.TreePop()
    end
end

local light_types = {
    "directional",
    "point",
    "spot"
}

local geom_type = {
    "cube",
    "cone",
    "cylinder",
    "sphere",
    "torus",
    "plane",
}

function m.get_title()
    return "Hierarchy"
end

local prefab_mgr  = ecs.require "prefab_manager"
function m.handle_input(key, press, state)
    if key == "Delete" and press == 1 then
        if gizmo.target_eid and can_delete(gizmo.target_eid) then
            world:pub { "HierarchyEvent", "delete", gizmo.target_eid }
        end
    end
end

function m.show()
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(viewport.WorkPos.x, viewport.WorkPos.y + uiconfig.ToolBarHeight, ImGui.Cond.FirstUseEver)
    ImGui.SetNextWindowSize(uiconfig.SceneWidgetWidth, viewport.WorkSize.y - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, ImGui.Cond.FirstUseEver)
    if ImGui.Begin("Hierarchy", nil, ImGui.WindowFlags { "NoCollapse" }) then
        if ImGui.Button(faicons.ICON_FA_SQUARE_PLUS.." Create") then
            ImGui.OpenPopup("CreateEntity")
        end
        if ImGui.BeginPopup("CreateEntity") then
            if prefab_mgr:can_create_empty() then
                -- only for xxx.glb(gltf)/mesh.prefab
                if ImGui.MenuItem("EmptyNode") then
                    world:pub {"Create", "empty"}
                end
            end
            if ImGui.BeginMenu("Geometry") then
                for _, type in ipairs(geom_type) do
                    if ImGui.MenuItem(type) then
                        world:pub { "Create", "geometry", {type = type}}
                    end
                end
                ImGui.EndMenu()
            end
            if ImGui.BeginMenu("Light") then
                for _, type in ipairs(light_types) do
                    if ImGui.MenuItem(type) then
                        world:pub { "Create", "light", {type = type}}
                    end
                end
                ImGui.EndMenu()
            end
            if ImGui.MenuItem("Camera") then
                world:pub { "Create", "camera"}
            end
            if ImGui.MenuItem("Timeline") then
                world:pub { "Create", "timeline"}
            end
            ImGui.Separator()
            if ImGui.BeginMenu "Terrain" then
                if ImGui.MenuItem "shape" then
                    world:pub {"Create", "terrain", {type="shape"}}
                end
                ImGui.EndMenu()
            end
            ImGui.EndPopup()
        end
        ImGui.Separator()
        if ImGui.BeginTable("InspectorTable", 3, ImGui.TableFlags {'ScrollY'}) then
            ImGui.TableSetupColumnEx("Entity", ImGui.TableColumnFlags {'NoHide', 'WidthStretch'}, 1.0)
            local fw = 24.0 * icons.scale
            ImGui.TableSetupColumnEx("Lock", ImGui.TableColumnFlags {'WidthFixed'}, fw)
            ImGui.TableSetupColumnEx("Visible", ImGui.TableColumnFlags {'WidthFixed'}, fw)
            ImGui.TableHeadersRow()
            for _, child in ipairs(hierarchy.root.children) do
                target_e = nil
                show_scene_node(child)
                if source_e and target_e then
                    world:pub {"EntityEvent", "parent", source_e, target_e}
                end
            end
            ImGui.EndTable()
        end
    end
    ImGui.End()
end

return m