local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local imgui     = require "imgui"
local rhwi      = import_package "ant.hwi"
local mathpkg   = import_package "ant.math"
local faicons   = require "common.fa_icons"
local mc        = mathpkg.constant
local ivs       = ecs.require "ant.render|visible_state"
local iwd       = ecs.import.interface "ant.render|iwidget_drawer"
local iefk      = ecs.require "ant.efk|efk"
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

local function choose_project_dir()
    local filedialog = require 'filedialog'
    local dialog_info = {
        Owner = rhwi.native_window(),
        Title = "Choose project folder"
    }
    local ok, path = filedialog.open(dialog_info)
    if ok then
        return path[1]
    end
end

local function start_fileserver(luaexe, path)
    local cthread = require "bee.thread"
    cthread.newchannel "log_channel"
    cthread.newchannel "fileserver_channel"
    cthread.newchannel "console_channel"
    local produce = cthread.channel "fileserver_channel"
    produce:push(luaexe, path)

    return cthread.thread [[
        package.path = "engine/?.lua"
        package.cpath = ""
        local fileserver = dofile "/pkg/tools.prefab_editor/fileserver_adapter.lua"()
        fileserver.run()
    ]]
end

local function do_open_proj(path)
    local lpath = lfs.path(path)
    if lfs.exists(lpath / ".mount") then
        local topname = global_data:update_root(lpath)
        local bfs = require "bee.filesystem"
        start_fileserver(tostring(bfs.exe_path()), path)
        log_widget.init_log_receiver()
        console_widget.init_console_sender()
        world:pub { "UpdateDefaultLight", true }
        if topname then
            log.warn("need handle effect file")
            return topname
        else
            print("Can not add effekseer resource seacher path.")
        end
    else
        log_widget.error({tag = "Editor", message = "no project exist!"})
    end
end

local function on_open_proj()
    local path = choose_project_dir()
    if path then
        local projname = do_open_proj(path)
        editor_setting.update_lastproj(projname:string():gsub("/pkg/", ""), path)
        editor_setting.save()
        prefab_mgr:reset_prefab()
        world:pub {"ResourceBrowser", "dirty"}
    end
end

local function choose_project()
    local selected_proj
    if global_data.project_root then return end
    local lastprojs = editor_setting.setting.lastprojs
    local title = "Choose project"
    if not imgui.windows.IsPopupOpen(title) then
        imgui.windows.OpenPopup(title)
    end

    local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text("Create new or open existing project.")
        if imgui.widget.Button(faicons.ICON_FA_FOLDER_PLUS.." Create") then
            local path = choose_project_dir()
            if path then
                local lpath = lfs.path(path)
                local n = fs.pairs(lpath)
                if not n() then
                    log_widget.error({tag = "Editor", message = "folder not empty!"})
                else
                    on_new_project(path)
                    global_data:update_root(lpath)
                    editor_setting.update_lastproj("", path)
                end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(faicons.ICON_FA_FOLDER_OPEN.." Open") then
            on_open_proj()
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(faicons.ICON_FA_BAN.." Quit") then
            global_data:update_root(fs.path "":localpath())
        end

        imgui.cursor.Separator()
        if lastprojs then
            for i, proj in ipairs(lastprojs) do
                if imgui.widget.Selectable(proj.name .. " : " .. proj.proj_path, selected_proj and selected_proj.proj_path == proj.proj_path, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                    selected_proj = lastprojs[i]
                    do_open_proj(proj.proj_path)
                end
            end
        end
        if global_data.project_root then
            local bfw = require "bee.filewatch"
            local fw = bfw.create()
            fw:add(global_data.project_root:string())
            global_data.filewatch = fw
            log.warn "need handle effect file"
            imgui.windows.CloseCurrentPopup()
        end
        imgui.windows.EndPopup()
    end
end

function m:start_frame()
    global_data.camera_lock = false
end

local stat_window
function m:init_world()
    local iRmlUi = ecs.require "ant.rmlui|rmlui_system"
    stat_window = iRmlUi.open "bgfx_stat.rml"
end

function m:ui_update()
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.TitleBg, 0.2, 0.2, 0.2, 1)
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
    choose_project()
    imgui.windows.PopStyleColor(2)
    imgui.windows.PopStyleVar()

    local bgfxstat = bgfx.get_stats "sdcpnmtv"
    stat_window.postMessage(string.format("DC: %d\nTri: %d\nTex: %d\ncpu(ms): %.2f\ngpu(ms): %.2f\nfps: %d", 
                            bgfxstat.numDraw, bgfxstat.numTriList, bgfxstat.numTextures, bgfxstat.cpu, bgfxstat.gpu, bgfxstat.fps))
end

local hierarchy_event       = world:sub {"HierarchyEvent"}
local entity_event          = world:sub {"EntityEvent"}
local event_keyboard        = world:sub {"keyboard"}
local event_open_file       = world:sub {"OpenFile"}
local event_open_proj       = world:sub {"OpenProject"}
local event_add_prefab      = world:sub {"AddPrefabOrEffect"}
local event_resource_browser= world:sub {"ResourceBrowser"}
local event_window_title    = world:sub {"WindowTitle"}
local event_create          = world:sub {"Create"}
local event_light           = world:sub {"UpdateDefaultLight"}
local event_showground      = world:sub {"ShowGround"}
local event_showterrain     = world:sub {"ShowTerrain"}
local event_gizmo           = world:sub {"Gizmo"}
local create_animation_event = world:sub {"CreateAnimation"}
local light_gizmo           = ecs.require "gizmo.light"

local aabb_color_i <const> = 0x6060ffff
local highlight_aabb = {
    visible = false,
    min = nil,
    max = nil,
}

local function update_highlight_aabb(eid)
    local visible = false
    if eid then
        local e <close> = w:entity(eid, "bounding?in scene?in")
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
        local oe <close> = w:entity(old, "light?in")
        if oe and oe.light then
            light_gizmo.bind()
        end
    end
    if new then
        local ne <close> = w:entity(new, "camera?in light?in scene?in render_object?in")
        if ne.camera then
            camera_mgr.set_second_camera(new, true)
        end

        if ne.light then
            light_gizmo.bind(new)
        end
        if ne.render_object or ne.scene then
            keyframe_view.set_current_target(new)
        end
    end
    world:pub {"UpdateAABB", new}
end

local function on_update(eid)
    world:pub {"UpdateAABB", eid}
    if not eid then return end
    local e <close> = w:entity(eid, "camera?in light?in")
    if e.camera then
        camera_mgr.update_frustrum(eid)
    elseif e.light then
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
        local e <close> = w:entity(eid, "visible_state?in")
        if e.visible_state then
            set_visible(e, visible)
            if not rv then
                rv = ivs.has_state(e, "main_view")
            end
        end
    end
    local ne <close> = w:entity(node.eid, "visible_state?in")
    if ne.visible_state then
        set_visible(ne, visible)
        local template = hierarchy:get_template(node.eid)
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
        template.template.data.visible_state = visible_state
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
            gizmo:set_rotation(math3d.quaternion{math.rad(v2[1]), math.rad(v2[2]), math.rad(v2[3])})
            cmd_queue:record {action = gizmo_const.ROTATE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "scale" then
            gizmo:set_scale(v2)
            cmd_queue:record {action = gizmo_const.SCALE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "name" or what == "tag" then
            transform_dirty = false
            if what == "name" then
                local e <close> = w:entity(target, "collider?in slot?in")
                hierarchy:update_display_name(target, v1)
                if e.collider then
                    hierarchy:update_collider_list(world)
                elseif e.slot then
                    hierarchy:update_slot_list(world)
                end
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
            local e <close> = w:entity(target.eid, "efk?in light?in")
            hierarchy:set_visible(target, value, true)
            if e.efk then
                iefk.set_visible(target.eid, value)
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
            local e <close> = w:entity(gizmo.target_eid, "collider?in slot?in")
            if e.collider or e.slot then
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

    for _ in event_open_proj:unpack() do
        on_open_proj()
    end

    for _, tn, filename in event_open_file:unpack() do
        if tn == "FBX" then
            prefab_mgr:open_fbx(filename)
        elseif tn == "Prefab" then
            prefab_mgr:open(filename)
        end
    end

    for _, filename in event_add_prefab:unpack() do
        if string.sub(filename, -4) == ".efk" then
            prefab_mgr:add_effect(filename)
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
        local title = "PrefabEditor - " .. what
        imgui.SetWindowTitle(title)
        gizmo:set_target(nil)
    end

    for _, key, press, state in event_keyboard:unpack() do
        if key == "Delete" and press == 1 then
            if gizmo.target_eid then
                world:pub { "HierarchyEvent", "delete", gizmo.target_eid }
            end
        elseif state.CTRL and key == "O" and press == 1 then
            on_open_proj()
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
    for _, at, target in create_animation_event:unpack() do
        keyframe_view.create_target_animation(at, target)
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
end