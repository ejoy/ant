local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local imgui     = require "imgui"
local rhwi      = import_package "ant.hwi"
local asset_mgr = import_package "ant.asset"
local mathpkg   = import_package "ant.math"

local mc        = mathpkg.constant
--local effekseer_filename_mgr = ecs.import.interface "ant.effekseer|filename_mgr"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local ipl       = ecs.import.interface "ant.render|ipolyline"
local ivs       = ecs.import.interface "ant.scene|ivisible_state"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local iwd       = ecs.import.interface "ant.render|iwidget_drawer"
local iefk      = ecs.import.interface "ant.efk|iefk"
local resource_browser  = ecs.require "widget.resource_browser"
local anim_view         = ecs.require "widget.animation_view"
local keyframe_view     = ecs.require "widget.keyframe_view"
local toolbar           = ecs.require "widget.toolbar"
local mainview          = ecs.require "widget.main_view"
local scene_view        = ecs.require "widget.scene_view"
local inspector         = ecs.require "widget.inspector"
local gridmesh_view     = ecs.require "widget.gridmesh_view"
local prefab_view       = ecs.require "widget.prefab_view"
local menu              = ecs.require "widget.menu"
local gizmo             = ecs.require "gizmo.gizmo"
local camera_mgr        = ecs.require "camera.camera_manager"

local widget_utils      = require "widget.utils"
local log_widget        = require "widget.log"(asset_mgr)
local console_widget    = require "widget.console"(asset_mgr)
local hierarchy         = require "hierarchy_edit"
local editor_setting    = require "editor_setting"

local global_data       = require "common.global_data"
local new_project       = require "common.new_project"
local gizmo_const       = require "gizmo.const"

local prefab_mgr        = ecs.require "prefab_manager"
prefab_mgr.set_anim_view(anim_view)

local fs                = require "filesystem"
local lfs               = require "filesystem.local"
local bgfx              = require "bgfx"

local m = ecs.system 'gui_system'
local drag_file = nil

local imodifier = ecs.import.interface "ant.modifier|imodifier"
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

local function start_fileserver(path)
    local cthread = require "bee.thread"
    cthread.newchannel "log_channel"
    cthread.newchannel "fileserver_channel"
    cthread.newchannel "console_channel"
    local produce = cthread.channel "fileserver_channel"
    produce:push(arg, path)
    local lthread = require "editor.thread"
    return lthread.create [[
        package.path = "engine/?.lua"
        require "bootstrap"
        local fileserver = dofile "/pkg/tools.prefab_editor/fileserver_adapter.lua"()
        fileserver.run()
    ]]
end

local function open_proj(path)
    local lpath = lfs.path(path)
    if lfs.exists(lpath / ".mount") then
        local topname = global_data:update_root(lpath)

        --file server
        start_fileserver(path)
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

local function OnOpen()
    local path = choose_project_dir()
    if path then
        local projname = open_proj(path)
        if projname == nil then
            projname = lfs.path(path):filename():string() .. "(folder)"
        end
        editor_setting.update_lastproj(projname:gsub("/pkg/", ""), path, false)
        editor_setting.save()
    end
end

local function choose_project()
    if global_data.project_root then return end
    local setting = editor_setting.setting
    local lastproj = setting.lastproj
    if lastproj and lastproj.auto_import then
        open_proj(assert(lastproj.proj_path))
        return
    end

    local title = "Choose project"
    if not imgui.windows.IsPopupOpen(title) then
        imgui.windows.OpenPopup(title)
    end

    local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text("Create new or open existing project.")
        if imgui.widget.Button "Create" then
            local path = choose_project_dir()
            if path then
                local lpath = lfs.path(path)
                local n = fs.pairs(lpath)
                if not n() then
                    log_widget.error({tag = "Editor", message = "folder not empty!"})
                else
                    on_new_project(path)
                    global_data:update_root(lpath)
                    editor_setting.update_lastproj("", path, false)
                end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button "Open" then
            OnOpen()
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button "Quit" then
            global_data:update_root(fs.path "":localpath())
        end

        imgui.cursor.Separator();

        imgui.windows.BeginDisabled(not lastproj)
        local last_name = "Last:" .. (lastproj and lastproj.name or "...")
        if imgui.widget.Button(last_name) then
            open_proj(lastproj.proj_path)
        end
        imgui.cursor.SameLine()
        local c, r = imgui.widget.Checkbox("Auto open last project", lastproj and lastproj.auto_import or false)
        if c then
            assert(lastproj)
            lastproj.auto_import = r
            editor_setting.save()
        end
        imgui.windows.EndDisabled()
        if global_data.project_root then
            local fw = require "bee.filewatch"
            fw.add(global_data.project_root:string())
            log.warn "need handle effect file"
            --effekseer_filename_mgr.add_path("/pkg/tools.prefab_editor/res")
            
            imgui.windows.CloseCurrentPopup()
        end
        imgui.windows.EndPopup()
    end
end

local stat_window
function m:init_world()
    local iRmlUi = ecs.import.interface "ant.rmlui|irmlui"
    stat_window = iRmlUi.open "bgfx_stat.rml"
    -- imodifier.highlight = imodifier.create_mtl_modifier(nil, "u_basecolor_factor", {
    --     {time = 0, value = {1, 1, 1, 1}},
    --     {time = 0.15, value = {1.5, 1.5, 1.5, 1}},
    --     {time = 0.4, value = {2, 2, 2, 1}},
    --     -- {time = 450, value = {2, 2, 2, 1}},
    --     -- {time = 600, value = {1, 1, 1, 1}},
    -- })
end
local mouse_pos_x
local mouse_pos_y
function m:ui_update()
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.TitleBg, 0.2, 0.2, 0.2, 1)
    widget_utils.show_message_box()
    menu.show()
    toolbar.show()
    mainview.show()
    scene_view.show()
    -- gridmesh_view.show()
    prefab_view.show()
    inspector.show()
    resource_browser.show()
    anim_view.show()
    keyframe_view.show()
    console_widget.show()
    log_widget.show()
    choose_project()
    imgui.windows.PopStyleColor(2)
    imgui.windows.PopStyleVar()
    
    --drag file to view
    if imgui.util.IsMouseDragging(0) then
        --local x, y = imgui.util.GetMousePos()
        if mouse_pos_x and mainview.in_view(mouse_pos_x, mouse_pos_y) then
            if not drag_file then
                local dropdata = imgui.widget.GetDragDropPayload()
                if dropdata and (string.sub(dropdata, -7) == ".prefab"
                    or string.sub(dropdata, -4) == ".efk" or string.sub(dropdata, -4) == ".glb") then
                    drag_file = dropdata
                end
            end
        else
            drag_file = nil
        end
    else
        if drag_file then
            world:pub {"AddPrefabOrEffect", drag_file}
            drag_file = nil
        end
    end

    local bgfxstat = bgfx.get_stats "sdcpnmtv"
    stat_window.postMessage(string.format("DC: %d\nTri: %d\nTex: %d\ncpu(ms): %.2f\ngpu(ms): %.2f\nfps: %d", 
                            bgfxstat.numDraw, bgfxstat.numTriList, bgfxstat.numTextures, bgfxstat.cpu, bgfxstat.gpu, bgfxstat.fps))
end

local hierarchy_event       = world:sub {"HierarchyEvent"}
local drop_files_event      = world:sub {"OnDropFiles"}
local entity_event          = world:sub {"EntityEvent"}
local event_keyboard        = world:sub {"keyboard"}
local event_open_prefab     = world:sub {"OpenPrefab"}
local event_open_fbx        = world:sub {"OpenFBX"}
local event_add_prefab      = world:sub {"AddPrefabOrEffect"}
local event_resource_browser= world:sub {"ResourceBrowser"}
local event_window_title    = world:sub {"WindowTitle"}
local event_create          = world:sub {"Create"}
local event_light           = world:sub {"UpdateDefaultLight"}
local event_gizmo           = world:sub {"Gizmo"}
local event_mouse           = world:sub {"mouse"}
local light_gizmo = ecs.require "gizmo.light"

local aabb_color_i <const> = 0x6060ffff
local highlight_aabb = {
    visible = false,
    min = nil,
    max = nil,
}

local function update_highlight_aabb(eid)
    if eid then
        local e <close> = w:entity(eid, "bounding?in scene?in")
        local bounding = e.bounding
        if bounding and bounding.aabb and bounding.aabb ~= mc.NULL then
            local wm = e.scene and iom.worldmat(e) or mc.IDENTITY_MAT
            highlight_aabb.min = math3d.tovalue(math3d.transform(wm, math3d.array_index(bounding.aabb, 1), 1))
            highlight_aabb.max = math3d.tovalue(math3d.transform(wm, math3d.array_index(bounding.aabb, 2), 1))
            highlight_aabb.visible = true
            return
        end
    end
    highlight_aabb.visible = false
end

local function on_target(old, new)
    if old then
        local oe <close> = w:entity(old, "light?in")
        if oe and oe.light then
            light_gizmo.bind(nil)
        end
    end
    if new then
        local ne <close> = w:entity(new, "camera?in light?in render_object?in")
        if ne.camera then
            camera_mgr.set_second_camera(new, true)
        end

        if ne.light then
            light_gizmo.bind(new)
        end
        if ne.render_object then
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

local function update_visible(node, visible)
    for _, nd in ipairs(node.children) do
        update_visible(nd, visible)
    end
    local rv
    local adaptee = hierarchy:get_select_adaptee(node.eid)
    for _, eid in ipairs(adaptee) do
        local e <close> = w:entity(eid, "visible_state?in")
        ivs.set_state(e, "main_view", visible)
        if e.visible_state and not rv then
            rv = ivs.has_state(e, "main_view")
        end
    end
    local ne <close> = w:entity(node.eid, "visible_state?in")
    ivs.set_state(ne, "main_view", visible)
    if ne.visible_state then
        local template = hierarchy:get_template(node.eid)
        template.template.data.visible_state = ivs.state_names(ne.visible_state)
    elseif rv and rv ~= visible then
        hierarchy:set_visible(node, rv)
    end
    return rv
end
local reset_editor = world:sub {"ResetEditor"}
local test_m
local test_m1
local test1
local test2
local ipl = ecs.import.interface "ant.render|ipolyline"
function m:handle_event()
    for _, _, _, x, y in event_mouse:unpack() do
        mouse_pos_x = x
        mouse_pos_y = y
    end
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
            local te <close> = w:entity(target, "scene?in")
            v1 = v1 or prefab_mgr.root
            local se <close> = w:entity(v1, "scene?in")
            if te.scene and se.scene then
                hierarchy:set_parent(target, v1)
                local targetWorldMat = v1 and iom.worldmat(se) or mc.IDENTITY_MAT
                iom.set_srt_matrix(te, math3d.mul(math3d.inverse(targetWorldMat), iom.worldmat(te)))
                te.scene.parent = v1
                w:extend(te, "scene_needchange:out")
                te.scene_needchange = true
            end
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
            local e <close> = w:entity(gizmo.target_eid, "collider?in slot?in")
            if e.collider or e.slot then
                anim_view.on_remove_entity(gizmo.target_eid)
            end
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
    
    for _, filename in event_open_prefab:unpack() do
        prefab_mgr:open(filename)
    end
    for _, filename in event_open_fbx:unpack() do
        prefab_mgr:open_fbx(filename)
    end
    for _, filename in event_add_prefab:unpack() do
        if string.sub(filename, -4) == ".efk" then
            prefab_mgr:add_effect(filename)
        else
            prefab_mgr:add_prefab(filename)
        end
    end
    for _, files in drop_files_event:unpack() do
        on_drop_files(files)
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
        if key == "DELETE" and press == 1 then
            world:pub { "HierarchyEvent", "delete", gizmo.target_eid }
        elseif state.CTRL and key == "O" and press == 1 then
            OnOpen()
            -- local g1 = ecs.group(1)
            -- g1:enable "scene_update"
            -- g1:enable "view_visible"
            -- local prefab = g1:create_instance("/pkg/tools.prefab_editor/res/cube.prefab")
            -- function prefab:on_init() end
            -- prefab.on_ready = function(instance)
            --     test1 = instance.tag["*"][1]
            -- end
            -- function prefab:on_message(msg) end
            -- function prefab:on_update() end
            -- world:create_object(prefab)
            -- prefab = ecs.create_instance("/pkg/tools.prefab_editor/res/cube.prefab")
            -- function prefab:on_init() end
            -- prefab.on_ready = function(instance)
            --     test2 = instance.tag["*"][1]
            -- end
            -- function prefab:on_message(msg) end
            -- function prefab:on_update() end
            -- world:create_object(prefab)
        elseif state.CTRL and key == "S" and press == 1 then
            prefab_mgr:save_prefab()
        elseif state.CTRL and key == "R" and press == 1 then
            anim_view:clear()
            prefab_mgr:reload()
            -- imodifier.start(test_m, {name="confirm"})
            -- imodifier.start(test_m1, {name="confirm"})
        elseif state.CTRL and key == "T" and press == 1 then
            -- test_m = imodifier.create_bone_modifier(test1, 1, "/pkg/tools.prefab_editor/res/Interact_build.glb|animation.prefab", "Bone")
            -- local te <close> = w:entity(test2, "scene?in")
            -- iom.set_position(te, math3d.vector{0, 0, -5})
            -- test_m1 = imodifier.create_bone_modifier(test2, 1, "/pkg/tools.prefab_editor/res/Interact_build.glb|animation.prefab", "Bone")

            -- test_m = ipl.add_linelist({{0.0, 0.0, 0.0}, {5.0, 5.0, 100.0}, {5.0, 5.0, 100.0}, {5.0, 0.0, 0.0}}, 80, {1.0, 0.0, 0.0, 0.7})
        end
    end

    for _, what, type in event_create:unpack() do
        prefab_mgr:create(what, type)
    end
    for _, enable in event_light:unpack() do
        prefab_mgr:update_default_light(enable)
    end
    for _, what in reset_editor:unpack() do
        imodifier.stop(imodifier.highlight)
    end
end

function m:data_changed()
    if highlight_aabb.visible and highlight_aabb.min and highlight_aabb.max then
        iwd.draw_aabb_box(highlight_aabb, nil, aabb_color_i)
        -- iwd.draw_lines({0.0,0.0,0.0,0.0,10.0,0.0}, nil, aabb_color_i)
    end
end

local igui = ecs.interface "igui"
function igui.cvt2scenept(x, y)
    local vr = irq.view_rect "tonemapping_queue"
    return x-vr.x, y-vr.y
end

local joint_utils = require "widget.joint_utils"

function m:widget()
    -- local ske = joint_utils:get_current_skeleton()
    -- if not ske then
    --     return
    -- end
    -- if not skeleton_eid then
    --     local desc={vb={}, ib={}}
    --     geometry_drawer.draw_skeleton(ske._handle, nil, DEFAULT_COLOR, {s = 15}, desc)
    --     skeleton_eid = geo_utils.create_dynamic_lines(nil, desc.vb, desc.ib, "skeleton", DEFAULT_COLOR_F)
    -- end
    -- if skeleton_eid then
    --     if firsttime then
    --         firsttime = false
    --     else
    --         w:extend(skeleton_eid, "simplemesh?in")
    --         if skeleton_eid.simplemesh then
    --             --ivs.set_state(skeleton_eid, "visible", true)
    --             local desc={vb={}, ib={}}
    --             local pose_result
    --             for e in w:select "skeleton:in pose_result:in" do
    --                 if ske == e.skeleton then
    --                     pose_result = e.pose_result
    --                     break
    --                 end
    --             end
    --             geometry_drawer.draw_skeleton(ske._handle, pose_result, DEFAULT_COLOR, nil, desc, joint_utils.current_joint and joint_utils.current_joint.index or 1)
    --             local rc = skeleton_eid.simplemesh
    --             local vbdesc, ibdesc = rc.vb, rc.ib
    --             bgfx.update(vbdesc[1].handle, 0, bgfx.memory_buffer("fffd", desc.vb))
    --             bgfx.update(ibdesc.handle, 0, bgfx.memory_buffer("w", desc.ib))
    --         end
    --     end
    -- end
end

function m.end_animation()
    -- if gizmo.target_eid and world:entity(gizmo.target_eid).skeleton then
    -- end
    joint_utils:update_pose(prefab_mgr:get_root_mat() or math3d.matrix{})
end