local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local ImGui     = import_package "ant.imgui"
local rhwi      = import_package "ant.hwi"
local mathpkg   = import_package "ant.math"
local faicons   = require "common.fa_icons"
local mc        = mathpkg.constant
local ivs       = ecs.require "ant.render|visible_state"
local iwd       = ecs.require "ant.widget|widget"
local iefk      = ecs.require "ant.efk|efk"
local iRmlUi    = ecs.require "ant.rmlui|rmlui_system"
local resource_browser  = ecs.require "widget.resource_browser"
local anim_view         = ecs.require "widget.animation_view"
local keyframe_view     = ecs.require "widget.keyframe_view"
local toolbar           = ecs.require "widget.toolbar"
local mainview          = ecs.require "widget.main_view"
local scene_view        = ecs.require "widget.scene_view"
local inspector         = ecs.require "widget.inspector"
local menu              = ecs.require "widget.menu"
local gizmo             = ecs.require "gizmo.gizmo"
local camera_mgr        = ecs.require "camera.camera_manager"

local widget_utils      = require "widget.utils"
local log_widget        = require "widget.log"
local console_widget    = require "widget.console"
local hierarchy         = require "hierarchy_edit"
local editor_setting    = require "editor_setting"

local global_data       = require "common.global_data"
local new_project       = require "common.new_project"
local gizmo_const       = require "gizmo.const"

local prefab_mgr        = ecs.require "prefab_manager"
prefab_mgr.set_anim_view(anim_view)

local fs                = require "filesystem"
local lfs               = require "bee.filesystem"
local bgfx              = require "bgfx"

local m = ecs.system 'gui_system'
local function on_new_project(path)
    new_project.set_path(path)
    new_project.gen_mount()
    new_project.gen_init_system()
    new_project.gen_main()
    new_project.gen_package_ecs()
    new_project.gen_package()
    new_project.gen_settings()
    new_project.gen_bat()
    new_project.gen_prebuild()
end

function m:start_frame()
    global_data.camera_lock = false
end

function m:init_world()
    iRmlUi.open "/pkg/tools.editor/resource/ui/bgfx_stat.html"
end

local event_ui_layout = world:sub {"UILayout"}
function m:ui_update()
    for _, action in event_ui_layout:unpack() do
        if action == "save" then
            widget_utils.save_ui_layout()
        elseif action == "reset" then
            widget_utils.reset_ui_layout()
        end
    end
    ImGui.PushStyleVar(ImGui.Enum.StyleVar.WindowRounding, 0)
    ImGui.PushStyleColor(ImGui.Enum.Col.WindowBg, 0.2, 0.2, 0.2, 1)
    ImGui.PushStyleColor(ImGui.Enum.Col.TitleBg, 0.2, 0.2, 0.2, 1)
    widget_utils.show_message_box()
    menu.show()
    toolbar.show()
    mainview.show()
    inspector.show()
    scene_view.show()
    resource_browser.show()
    anim_view.show()
    keyframe_view.show()
    console_widget.show()
    log_widget.show()
    prefab_mgr:choose_prefab()
    ImGui.PopStyleColor(2)
    ImGui.PopStyleVar()
    local bgfxstat = bgfx.get_stats "sdcpnmtv"
    iRmlUi.sendMessage("stat", string.format("DC: %d\nTri: %d\nTex: %d\ncpu(ms): %.2f\ngpu(ms): %.2f\nfps: %d", 
                            bgfxstat.numDraw, bgfxstat.numTriList, bgfxstat.numTextures, bgfxstat.cpu, bgfxstat.gpu, bgfxstat.fps))
end

local hierarchy_event       = world:sub {"HierarchyEvent"}
local entity_event          = world:sub {"EntityEvent"}
local event_keyboard        = world:sub {"keyboard"}
local event_open_file       = world:sub {"OpenFile"}
local event_add_prefab      = world:sub {"AddPrefabOrEffect"}
local event_resource_browser= world:sub {"ResourceBrowser"}
local event_window_title    = world:sub {"WindowTitle"}
local event_create          = world:sub {"Create"}
local event_light           = world:sub {"UpdateDefaultLight"}
local event_showground      = world:sub {"ShowGround"}
local event_showterrain     = world:sub {"ShowTerrain"}
local event_savehitch       = world:sub {"SaveHitch"}
local event_gizmo           = world:sub {"Gizmo"}
local light_gizmo           = ecs.require "gizmo.light"
local patch_event          = world:sub {"PatchEvent"}

local aabb_color_i <const> = 0x6060ffff
local highlight_aabb = {
    visible = false,
    min = nil,
    max = nil,
}

local function update_highlight_aabb(eid)
    local visible = false
    if eid then
        local e <close> = world:entity(eid, "bounding?in scene?in")
        local bounding = e.bounding
        if bounding and bounding.scene_aabb and bounding.scene_aabb ~= mc.NULL then
            -- local wm = e.scene and iom.worldmat(e) or mc.IDENTITY_MAT
            highlight_aabb.min = math3d.tovalue(math3d.array_index(bounding.scene_aabb, 1))--math3d.tovalue(math3d.transform(wm, math3d.array_index(bounding.scene_aabb, 1), 1))
            highlight_aabb.max = math3d.tovalue(math3d.array_index(bounding.scene_aabb, 2))--math3d.tovalue(math3d.transform(wm, math3d.array_index(bounding.scene_aabb, 2), 1))
            visible = true
        else
            local waabb = prefab_mgr:get_world_aabb(eid)
            if waabb then
                highlight_aabb.min = math3d.tovalue(math3d.array_index(waabb, 1))
                highlight_aabb.max = math3d.tovalue(math3d.array_index(waabb, 2))
                visible = true
            end
        end
    end
    highlight_aabb.visible = visible
end

local function on_target(old, new)
    if old then
        local oe <close> = world:entity(old, "light?in")
        if oe and oe.light then
            light_gizmo.on_target()
        end
    end
    light_gizmo.on_target(new)
    camera_mgr.on_target(new, true)
    keyframe_view.on_target(new)
    anim_view.on_target(new)
    world:pub {"UpdateAABB", new}
end

local function on_update(eid)
    world:pub {"UpdateAABB", eid}
    if not eid then return end
    local e <close> = world:entity(eid, "light?in")
    if e and e.light then
        light_gizmo.update()
    end
end

local cmd_queue = ecs.require "gizmo.command_queue"
local event_update_aabb = world:sub {"UpdateAABB"}

function hierarchy:set_adaptee_visible(nd, b, recursion)
    local adaptee = self:get_select_adaptee(nd.eid)
    for _, e in ipairs(adaptee) do
        hierarchy:set_visible(self:get_node(e), b, recursion)
    end
end
local function set_visible(e, visible)
    ivs.set_state(e, "main_view", visible)
    ivs.set_state(e, "cast_shadow", visible)
end
local function combine_state(states, st)
    return (states == "") and st or (states .."|"..st)
end
local function update_visible(node, visible)
    for _, nd in ipairs(node.children) do
        update_visible(nd, visible)
    end
    local rv
    local adaptee = hierarchy:get_select_adaptee(node.eid)
    for _, eid in ipairs(adaptee) do
        local e <close> = world:entity(eid, "visible_state?in")
        if e.visible_state then
            set_visible(e, visible)
            if not rv then
                rv = ivs.has_state(e, "main_view")
            end
        end
    end
    local ne <close> = world:entity(node.eid, "visible_state?in")
    if ne.visible_state then
        set_visible(ne, visible)
        local info = hierarchy:get_node_info(node.eid)
        local visible_state = ""
        local shadow = false
        for key, value in pairs(ne.visible_state) do
            if value then
                if key == "pickup_queue" then
                    visible_state = combine_state(visible_state, "selectable")
                elseif key == "main_queue" then
                    visible_state = combine_state(visible_state, "main_view")
                elseif key == "csm1_queue" or key == "csm2_queue" or key == "csm3_queue" or key == "csm4_queue" then
                    shadow = true
                end
            end
        end
        if shadow then
            visible_state = combine_state(visible_state, "cast_shadow")
        end
        info.template.data.visible_state = visible_state
    elseif rv and rv ~= visible then
        hierarchy:set_visible(node, rv)
    end
    return rv
end

function m:handle_event()
    for _, e in event_update_aabb:unpack() do
        update_highlight_aabb(e)
    end
    for _, action, value1, value2 in event_gizmo:unpack() do
        if action == "update" or action == "ontarget" then
            inspector.update_ui()
            if action == "ontarget" then
                on_target(value1, value2)
            elseif action == "update" then
                on_update(gizmo.target_eid)
            end
        end
    end
    for _, what, target, v1, v2 in entity_event:unpack() do
        local transform_dirty = true
        if what == "move" then
            gizmo:set_position(v2)
            cmd_queue:record {action = gizmo_const.MOVE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "rotate" then
            local rot = math3d.quaternion{math.rad(v2[1]), math.rad(v2[2]), math.rad(v2[3])}
            gizmo:set_rotation(rot)
            cmd_queue:record {action = gizmo_const.ROTATE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "scale" then
            gizmo:set_scale(v2)
            cmd_queue:record {action = gizmo_const.SCALE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "tag" then
            transform_dirty = false
            if what == "tag" then
                local e <close> = world:entity(target, "slot?in")
                hierarchy:update_display_name(target, v2[1])
                if e.slot then
                    hierarchy:update_slot_list(world)
                end
                prefab_mgr:on_patch_tag(target, v1, v2)
            end
        elseif what == "parent" then
            target = prefab_mgr:set_parent(target, v1)
            gizmo:set_target(target)
        end
        if transform_dirty then
            on_update(target)
        end
    end
    for _, what, target, value in hierarchy_event:unpack() do
        if what == "visible" then
            local e <close> = world:entity(target.eid, "efk?in light?in")
            hierarchy:set_visible(target, value, true)
            if e.efk then
                iefk.set_visible(e, value)
            elseif e.light then
                world:pub{"component_changed", "light", target.eid, "visible", value}
            else
                update_visible(target, value)
            end
            for ie in w:select "scene:in ibl:in" do
                if ie.scene.parent == target.eid then
                    isp.enable_ibl(value)
                    break
                end
            end
        elseif what == "lock" then
            hierarchy:set_lock(target, value)
        elseif what == "delete" then
            local e <close> = world:entity(gizmo.target_eid, "slot?in")
            if e.slot then
                anim_view.on_remove_entity(gizmo.target_eid)
            end
            keyframe_view.on_eid_delete(target)
            prefab_mgr:remove_entity(target)
        elseif what == "clone" then
            prefab_mgr:clone(target)
        elseif what == "movetop" then
            hierarchy:move_top(target)
        elseif what == "moveup" then
            hierarchy:move_up(target)
        elseif what == "movedown" then
            hierarchy:move_down(target)
        elseif what == "movebottom" then
            hierarchy:move_bottom(target)
        end
    end

    for _, filename, isprefab in event_open_file:unpack() do
        if isprefab then
            prefab_mgr:open(filename)
        else
            global_data.glb_filename = filename
            global_data.is_opening = true
        end
    end

    for _, filename in event_add_prefab:unpack() do
        local ext = string.sub(filename, -4)
        if ext == ".efk" then
            prefab_mgr:add_effect(filename)
        elseif ext == ".glb" then
            global_data.glb_filename = filename
        else
            prefab_mgr:add_prefab(filename)
        end
    end

    for _, what in event_resource_browser:unpack() do
        if what == "dirty" then
            resource_browser.dirty = true
        end
    end

    for _, what in event_window_title:unpack() do
        local title = "Editor - " .. what
        ImGui.SetWindowTitle(title)
        gizmo:set_target(nil)
    end

    for _, key, press, state in event_keyboard:unpack() do
        if key == "Delete" and press == 1 then
            if gizmo.target_eid then
                world:pub { "HierarchyEvent", "delete", gizmo.target_eid }
            end
        elseif state.CTRL and key == "S" and press == 1 then
            prefab_mgr:save()
        end
    end
    for _, what, type in event_create:unpack() do
        prefab_mgr:create(what, type)
    end
    for _, enable in event_light:unpack() do
        prefab_mgr:update_default_light(enable)
    end
    for _, enable in event_showground:unpack() do
        prefab_mgr:show_ground(enable)
    end
    for _, enable in event_showterrain:unpack() do
        prefab_mgr:show_terrain(enable)
    end
    for _, enable in event_savehitch:unpack() do
        prefab_mgr.save_hitch = enable
    end
    for _, eid, path, value in patch_event:unpack() do
        prefab_mgr:do_patch(eid, path, value)
    end
end

function m:data_changed()
    if highlight_aabb.visible and highlight_aabb.min and highlight_aabb.max then
        iwd.draw_aabb_box(highlight_aabb, nil, aabb_color_i)
        -- iwd.draw_lines({0.0,0.0,0.0,0.0,10.0,0.0}, nil, aabb_color_i)
    end
end

function m:widget()
end

local joint_utils = require "widget.joint_utils"
function m.end_animation()
    joint_utils:update_pose(prefab_mgr:get_root_mat() or math3d.matrix{})
    keyframe_view.end_animation()
end