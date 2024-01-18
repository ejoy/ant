local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr  = import_package "ant.asset"
local icons = require "common.icons"
local gizmo = ecs.require "gizmo.gizmo"
local ivs       = ecs.require "ant.render|visible_state"
local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local hierarchy = require "hierarchy_edit"
local faicons   = require "common.fa_icons"

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

local function node_context_menu(eid)
    if gizmo.target_eid ~= eid then return end
    if imgui.windows.BeginPopupContextItem(tostring(eid)) then
        local current_lock = hierarchy:is_locked(eid)
        local tpl = hierarchy:get_node_info(eid)
        if not tpl.filename then
            if imgui.widget.MenuItem(faicons.ICON_FA_CLONE.." Clone", "Ctrl+D") then
                world:pub { "HierarchyEvent", "clone", eid }
            end
        end
        if imgui.widget.MenuItem(faicons.ICON_FA_ARROWS_UP_TO_LINE.." MoveTop") then
            world:pub { "HierarchyEvent", "movetop", eid }
        end
        if imgui.widget.MenuItem(faicons.ICON_FA_ARROW_UP.." MoveUp") then
            world:pub { "HierarchyEvent", "moveup", eid }
        end
        imgui.cursor.Separator()
        if imgui.widget.MenuItem(current_lock and faicons.ICON_FA_LOCK.." Unlock" or faicons.ICON_FA_LOCK_OPEN.." lock") then
            world:pub { "HierarchyEvent", "lock", eid, not current_lock }
        end
        local current_visible = hierarchy:is_visible(eid)
        if imgui.widget.MenuItem(current_visible and faicons.ICON_FA_EYE.." Hide" or faicons.ICON_FA_EYE_SLASH.." Show") then
            world:pub { "HierarchyEvent", "visible", hierarchy:get_node(eid), not current_visible }
        end
        imgui.cursor.Separator()
        if imgui.widget.MenuItem(faicons.ICON_FA_TRASH.." Delete", "Delete") then
            local can_delete = true
            if as_main_camera_mode() then
                local e <close> = world:entity(eid, "camera?in")
                if e.camera then
                    can_delete = false
                else
                    local children = hierarchy:get_node(eid).children
                    if #children > 0 then
                        --TODO: for camera
                        local ce <close> = world:entity(children[1].eid, "camera?in")
                        if ce.camera then
                            can_delete = false
                        end
                    end
                end
            end
            if can_delete then
                world:pub { "HierarchyEvent", "delete", eid }
            end
        end
        imgui.cursor.Separator()
        if imgui.widget.MenuItem(faicons.ICON_FA_ARROW_DOWN.." MoveDown") then
            world:pub { "HierarchyEvent", "movedown", eid }
        end
        if imgui.widget.MenuItem(faicons.ICON_FA_ARROWS_DOWN_TO_LINE.." MoveBottom") then
            world:pub { "HierarchyEvent", "movebottom", eid }
        end
        imgui.cursor.Separator()
        if imgui.widget.MenuItem("NoParent") then
            world:pub { "EntityEvent", "parent", eid }
        end
        imgui.cursor.Separator()
        if imgui.widget.MenuItem("SRT Animation") then
            world:pub { "CreateAnimation", "srt", eid }
        end
        if imgui.widget.MenuItem("MTL Animation") then
            world:pub { "CreateAnimation", "mtl", eid }
        end
        imgui.windows.EndPopup()
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
    -- local e <close> = world:entity(node.eid, "animation?in")
    -- if e.animation then
    --     return
    -- end
    imgui.table.NextRow();
    imgui.table.NextColumn();
    local function select_or_move(nd)
        local eid = nd.eid
        if imgui.util.IsItemClicked() then
            -- imgui.util.SetKeyboardFocusHere()
            if is_editable(eid) then
                gizmo:set_target(eid)
            end
            if imodifier.highlight then
                imodifier.set_target(imodifier.highlight, eid)
                imodifier.start(imodifier.highlight, {})
            end
        end

        if imgui.widget.BeginDragDropSource() then
            source_e = eid
            imgui.widget.SetDragDropPayload("DragNode", tostring(eid))
            imgui.widget.EndDragDropSource()
        end
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("DragNode")
            if payload then
                --source_e = tonumber(payload)
                target_e = eid
            end
            imgui.widget.EndDragDropTarget()
        end
    end
    local function lock_visible(nd)
        local eid = nd.eid
        imgui.table.NextColumn();
        imgui.util.PushID(tostring(eid))
        local current_lock = hierarchy:is_locked(eid)
        local icon = current_lock and icons.ICON_LOCK or icons.ICON_UNLOCK
        local imagesize = icon.texinfo.width * icons.scale
        if imgui.widget.ImageButton("lock", assetmgr.textures[icon.id], imagesize, imagesize) then
            world:pub { "HierarchyEvent", "lock", eid, not current_lock }
        end
        imgui.util.PopID()
        imgui.table.NextColumn();
        imgui.util.PushID(tostring(eid))
        local current_visible = hierarchy:is_visible(eid)
        local e <close> = world:entity(eid, "visible_state?in")
        if e.visible_state then
            local rv = ivs.has_state(e, "main_view")
            if current_visible ~= rv then
                hierarchy:set_visible(nd, rv)
                current_visible = rv
            end
        end
        icon = current_visible and icons.ICON_VISIBLE or icons.ICON_UNVISIBLE
        imagesize = icon.texinfo.width * icons.scale
        if imgui.widget.ImageButton("visible", assetmgr.textures[icon.id], imagesize, imagesize) then
            world:pub { "HierarchyEvent", "visible", nd, not current_visible }
        end
        imgui.util.PopID()
    end
    local base_flags = imgui.flags.TreeNode { "OpenOnArrow", "SpanFullWidth" } | ((gizmo.target_eid == node.eid) and imgui.flags.TreeNode{"Selected"} or 0)
    if not node.display_name then
        local name = node.info.template.tag and node.info.template.tag[1] or node.info.name
        hierarchy:update_display_name(node.eid, name or "")
    end

    local flags = base_flags
    local has_child = true
    if #node.children == 0 then
        flags = base_flags | imgui.flags.TreeNode { "Leaf", "NoTreePushOnOpen" }
        has_child = false
    end
    
    local current_icon = get_icon_by_object_type(node)
    local imagesize = current_icon.texinfo.width * icons.scale
    imgui.widget.Image(assetmgr.textures[current_icon.id], imagesize, imagesize)
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

    lock_visible(node)
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
    -- "cube(prefab)",
    -- "cone(prefab)",
    -- "cylinder(prefab)",
    -- "sphere(prefab)",
    -- "torus(prefab)",
    -- "plane(prefab)",
}
local collider_type = {
    "sphere",
    "box",
    --"capsule"
}

function m.get_title()
    return "Hierarchy"
end

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.SceneWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    if imgui.windows.Begin("Hierarchy", imgui.flags.Window { "NoCollapse", "NoClosed" }) then
        if imgui.widget.Button(faicons.ICON_FA_SQUARE_PLUS.." Create") then
            imgui.windows.OpenPopup("CreateEntity")
        end
        if imgui.windows.BeginPopup("CreateEntity") then
            if imgui.widget.MenuItem("EmptyNode") then
                world:pub {"Create", "empty"}
            end
            if imgui.widget.BeginMenu("Geometry") then
                for _, type in ipairs(geom_type) do
                    if imgui.widget.MenuItem(type) then
                        world:pub { "Create", "geometry", {type = type}}
                    end
                end
                imgui.widget.EndMenu()
            end
            if imgui.widget.BeginMenu("Light") then
                for _, type in ipairs(light_types) do
                    if imgui.widget.MenuItem(type) then
                        world:pub { "Create", "light", {type = type}}
                    end
                end
                imgui.widget.EndMenu()
            end
            if imgui.widget.MenuItem("Camera") then
                world:pub { "Create", "camera"}
            end
            -- if imgui.widget.MenuItem("Slot") then
            --     world:pub { "Create", "slot"}
            -- end
            if imgui.widget.MenuItem("Timeline") then
                world:pub { "Create", "timeline"}
            end
            imgui.cursor.Separator()
            if imgui.widget.BeginMenu "Terrain" then
                if imgui.widget.MenuItem "shape" then
                    world:pub {"Create", "terrain", {type="shape"}}
                end
                imgui.widget.EndMenu()
            end
            imgui.windows.EndPopup()
        end
        imgui.cursor.Separator()
        if imgui.table.Begin("InspectorTable", 3, imgui.flags.Table {'ScrollY'}) then
            -- local child_width, child_height = imgui.windows.GetContentRegionAvail()
            imgui.table.SetupColumn("Entity", imgui.flags.TableColumn {'NoHide', 'WidthStretch'}, 1.0)
            local fw = 24.0 * icons.scale
            imgui.table.SetupColumn("Lock", imgui.flags.TableColumn {'WidthFixed'}, fw)
            imgui.table.SetupColumn("Visible", imgui.flags.TableColumn {'WidthFixed'}, fw)
            imgui.table.HeadersRow()
            for _, child in ipairs(hierarchy.root.children) do
                target_e = nil
                show_scene_node(child)
                if source_e and target_e then
                    world:pub {"EntityEvent", "parent", source_e, target_e}
                end
            end
            imgui.table.End()
        end
    end
    imgui.windows.End()
end

return m