local ecs = ...
local world = ecs.world
local w = world.w

local iom = ecs.import.interface "ant.objcontroller|obj_motion"
local icamera = ecs.import.interface "ant.camera|camera"
local assetmgr  = import_package "ant.asset"
local icons = require "common.icons"(assetmgr)
local gizmo = ecs.require "gizmo.gizmo"

local imgui     = require "imgui"
local math3d    = require "math3d"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local hierarchy = require "hierarchy_edit"

local m = {}

local source_eid = nil
local target_eid = nil
local function is_editable(eid)
    --if not world[eid].scene_entity or
    if not hierarchy:is_visible(eid) or
        hierarchy:is_locked(eid) then
        return false
    end
    return true
end

local menu_name = "entity context menu"
local function node_context_menu(eid)
    if gizmo.target_eid ~= eid then return end
    if imgui.windows.BeginPopupContextItem(tostring(eid)) then
        local current_lock = hierarchy:is_locked(eid)
        if imgui.widget.Selectable("MoveTop", false) then
            world:pub { "EntityState", "movetop", eid }
        end
        if imgui.widget.Selectable("MoveUp", false) then
            world:pub { "EntityState", "moveup", eid }
        end
        imgui.cursor.Separator()
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
        imgui.cursor.Separator()
        if imgui.widget.Selectable("MoveDown", false) then
            world:pub { "EntityState", "movedown", eid }
        end
        if imgui.widget.Selectable("MoveBottom", false) then
            world:pub { "EntityState", "movebottom", eid }
        end
        imgui.cursor.Separator()
        if imgui.widget.Selectable("NoParent", false) then
            world:pub { "EntityEvent", "parent", eid }
        end
        imgui.windows.EndPopup()
    end
end

local function get_icon_by_object_type(node)
    local template = hierarchy:get_template(node.eid)
    if template and template.filename then
        return icons.ICON_WORLD3D
    else
        local e = node.eid
        w:sync("camera?in", e)
        if e.camera then
            return icons.ICON_CAMERA3D
        end
        w:sync("light_type?in", e)
        if e.light_type then
            if e.light_type == "directional" then
                return icons.ICON_DIRECTIONALLIGHT
            elseif e.light_type == "point" then
                return icons.ICON_POINTLIGHT
            elseif e.light_type == "spot" then
                return icons.ICON_SPOTLIGHT
            end
        end
        w:sync("mesh?in", e)
        if e.mesh then
            w:sync("collider?in", e)
            if e.collider then
                return icons.ICON_COLLISIONSHAPE3D
            else
                return icons.ICON_MESH
            end
        end
        w:sync("slot?in", e)
        if e.slot then
            return icons.ICON_SLOT
        end
        w:sync("effekseer?in", e)
        if e.effekseer then
            return icons.ICON_PARTICLES3D
        else
            return icons.ICON_OBJECT
        end
    end
end

local function show_scene_node(node)
    imgui.table.NextRow();
    imgui.table.NextColumn();
    local function select_or_move(nd)
        local eid = nd.eid
        if imgui.util.IsItemClicked() then
            if is_editable(eid) then
                gizmo:set_target(eid)
            end
        end
        --if world[eid].camera 
        if type(eid) == "table" or world[eid].light_type then
            return
        end

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
    local function lock_visible(eid)
        imgui.table.NextColumn();
        imgui.util.PushID(tostring(eid))
        local current_lock = hierarchy:is_locked(eid)
        local icon = current_lock and icons.ICON_LOCK or icons.ICON_UNLOCK
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            world:pub { "EntityState", "lock", eid, not current_lock }
        end
        imgui.util.PopID()
        imgui.table.NextColumn();
        imgui.util.PushID(tostring(eid))
        local current_visible = hierarchy:is_visible(eid)
        icon = current_visible and icons.ICON_VISIBLE or icons.ICON_UNVISIBLE
        if imgui.widget.ImageButton(icon.handle, icon.texinfo.width, icon.texinfo.height) then
            world:pub { "EntityState", "visible", eid, not current_visible }
        end
        imgui.util.PopID()
    end
    local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((gizmo.target_eid == node.eid) and imgui.flags.TreeNode{"Selected"} or 0)
    if not node.display_name then
        if type(node.eid) == "table" then
            local w = world.w
            w:sync("name:in", node.eid)
            hierarchy:update_display_name(node.eid, node.eid.name)
        else
            hierarchy:update_display_name(node.eid, world[node.eid].name)
        end
    end

    local flags = base_flags
    local has_child = true
    if #node.children == 0 then
        flags = base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" }
        has_child = false
    end
    
    local current_icon = get_icon_by_object_type(node)
    imgui.widget.Image(current_icon.handle, current_icon.texinfo.width, current_icon.texinfo.height)
    imgui.cursor.SameLine()
    if not has_child then
        imgui.cursor.Indent(-2)
    end
    local open = imgui.widget.TreeNode(node.display_name, flags)
    if not has_child then
        imgui.cursor.Indent(2)
    end
    node_context_menu(node.eid)
    select_or_move(node)

    lock_visible(node.eid)
    if open and has_child then
        for _, child in ipairs(node.children) do
            show_scene_node(child)
        end
        imgui.widget.TreePop()
    end
    --key == "DELETE"
    -- if imgui.util.IsKeyPressed('a') or imgui.util.IsKeyPressed('A') then
    --     print("press a/A")
    -- end
    -- if imgui.util.IsKeyPressed(10) then
    --     print("press delete")
    --     world:pub { "EntityState", "delete", eid }
    -- end
end

local light_type = {
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
    "cube(prefab)",
    "cone(prefab)",
    "cylinder(prefab)",
    "sphere(prefab)",
    "torus(prefab)"
}
local collider_type = {
    "sphere",
    "box",
    --"capsule"
}

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.SceneWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')

    for _ in uiutils.imgui_windows("Hierarchy", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        if imgui.widget.Button("Create") then
            imgui.windows.OpenPopup("CreateEntity")
        end
        if imgui.windows.BeginPopup("CreateEntity") then
            if imgui.widget.MenuItem("EmptyNode") then
                world:pub {"Create", "empty"}
            end
            if imgui.widget.BeginMenu("Collider") then
                for i, type in ipairs(collider_type) do
                    if imgui.widget.MenuItem(type) then
                        world:pub { "Create", "collider", {type = type, add_to_hierarchy = true}}
                    end
                end
                imgui.widget.EndMenu()
            end
            if imgui.widget.BeginMenu("Geometry") then
                for i, type in ipairs(geom_type) do
                    if imgui.widget.MenuItem(type) then
                        world:pub { "Create", "geometry", {type = type}}
                    end
                end
                imgui.widget.EndMenu()
            end
            if imgui.widget.BeginMenu("Light") then
                for i, type in ipairs(light_type) do
                    if imgui.widget.MenuItem(type) then
                        world:pub { "Create", "light", {type = type}}
                    end
                end
                imgui.widget.EndMenu()
            end
            if imgui.widget.MenuItem("Camera") then
                world:pub { "Create", "camera"}
            end
            if imgui.widget.MenuItem("Slot") then
                world:pub { "Create", "slot"}
            end
            if imgui.widget.MenuItem("Particle") then
                world:pub { "Create", "particle"}
            end
            imgui.windows.EndPopup()
        end
        imgui.cursor.Separator()
        if imgui.table.Begin("InspectorTable", 3, imgui.flags.Table {'ScrollY'}) then
            local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.table.SetupColumn("Entity", imgui.flags.TableColumn {'NoHide', 'WidthStretch'}, 1.0)
            imgui.table.SetupColumn("Lock", imgui.flags.TableColumn {'WidthFixed'}, 24.0)
            imgui.table.SetupColumn("Visible", imgui.flags.TableColumn {'WidthFixed'}, 24.0)
            imgui.table.HeadersRow()
            for i, child in ipairs(hierarchy.root.children) do
                source_eid = nil
                target_eid = nil
                show_scene_node(child)
                if source_eid and target_eid then
                    world:pub {"EntityEvent", "parent", source_eid, target_eid}
                end
            end
            imgui.table.End() 
        end
    end
end

return m