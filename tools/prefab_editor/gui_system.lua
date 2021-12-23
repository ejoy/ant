local ecs       = ...
local world     = ecs.world
local w         = world.w

local math3d    = require "math3d"
local imgui     = require "imgui"
local rhwi      = import_package "ant.hwi"
local asset_mgr = import_package "ant.asset"
local mathpkg   = import_package "ant.math"
local defaultcomp= import_package "ant.general".default
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local mc        = mathpkg.constant
local effekseer_filename_mgr = ecs.import.interface "ant.effekseer|filename_mgr"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local ies       = ecs.import.interface "ant.scene|ifilter_state"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local icoll     = ecs.import.interface "ant.collision|icollider"
local drawer    = ecs.import.interface "ant.render|iwidget_drawer"
local isp 		= ecs.import.interface "ant.render|isystem_properties"
local iwd       = ecs.import.interface "ant.render|iwidget_drawer"
local icamera   = ecs.import.interface "ant.camera|icamera"

local resource_browser  = ecs.require "widget.resource_browser"
local anim_view         = ecs.require "widget.animation_view"
local material_view     = ecs.require "widget.material_view"
local toolbar           = ecs.require "widget.toolbar"
local scene_view        = ecs.require "widget.scene_view"
local inspector         = ecs.require "widget.inspector"
local gridmesh_view     = ecs.require "widget.gridmesh_view"
local prefab_view       = ecs.require "widget.prefab_view"
local menu              = ecs.require "widget.menu"
local gizmo             = ecs.require "gizmo.gizmo"
local camera_mgr        = ecs.require "camera_manager"

local uiconfig          = require "widget.config"
local widget_utils      = require "widget.utils"
local log_widget        = require "widget.log"(asset_mgr)
local console_widget    = require "widget.console"(asset_mgr)
local hierarchy         = require "hierarchy_edit"

local global_data       = require "common.global_data"
local new_project       = require "common.new_project"
local utils             = require "common.utils"
local gizmo_const       = require "gizmo.const"

local prefab_mgr        = ecs.require "prefab_manager"
prefab_mgr.set_anim_view(anim_view)


local vfs               = require "vfs"
local access            = require "vfs.repoaccess"
local fs                = require "filesystem"
local lfs               = require "filesystem.local"
local bgfx              = require "bgfx"

local m = ecs.system 'gui_system'
local drag_file = nil

local second_view_width = 384
local second_view_height = 216

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

local function get_package(entry_path, readmount)
    local repo = {_root = entry_path}
    if readmount then
        access.readmount(repo)
    end
    local packages = {}
    for _, name in ipairs(repo._mountname) do
        vfs.mount(name, repo._mountpoint[name]:string())
        local key = name
        local skip = false
        if utils.start_with(name, "/pkg/ant.") then
            if name ~= "/pkg/ant.resources" and name ~= "/pkg/ant.resources.binary" then
                skip = true
            end
        end
        if not skip then
            packages[#packages + 1] = {name = key, path = repo._mountpoint[name]}
        end
    end
    global_data.repo = repo
    return packages
end

local fileserver_thread

local function choose_project()
    if global_data.project_root then return end
    local title = "Choose project"
    if not imgui.windows.IsPopupOpen(title) then
        imgui.windows.OpenPopup(title)
    end
    local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text("Create new or open existing project.")
        if imgui.widget.Button("Create project") then
            local path = choose_project_dir()
            if path then
                local lpath = lfs.path(path)
                local not_empty
                for path in fs.pairs(lpath) do
                    not_empty = true
                    break
                end
                if not_empty then
                    log_widget.error({tag = "Editor", message = "folder not empty!"})
                else
                    global_data.project_root = lpath
                    on_new_project(path)
                    global_data.packages = get_package(lfs.absolute(global_data.project_root), true)
                end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Open project") then
            local path = choose_project_dir()
            if path then
                local lpath = lfs.path(path)
                if lfs.exists(lpath / ".mount") then
                    global_data.project_root = lpath
                    global_data.packages = get_package(lfs.absolute(global_data.project_root), true)
                    --file server
                    local cthread = require "bee.thread"
                    cthread.newchannel "log_channel"
                    cthread.newchannel "fileserver_channel"
                    cthread.newchannel "console_channel"
                    local produce = cthread.channel "fileserver_channel"
                    produce:push(arg, path)
                    local lthread = require "editor.thread"
                    fileserver_thread = lthread.create [[
                        package.path = "engine/?.lua"
                        require "bootstrap"
                        local fileserver = dofile "/pkg/tools.prefab_editor/fileserver_adapter.lua"()
                        fileserver.run()
                    ]]
                    log_widget.init_log_receiver()
                    console_widget.init_console_sender()
                    local topname
                    for _, package in ipairs(global_data.packages) do
                        if package.path == global_data.project_root then
                            topname = package.name
                            break
                        end
                    end
                    if topname then
                        global_data.package_path = topname .. "/"
                        effekseer_filename_mgr.add_path(global_data.package_path .. "res")
                    else
                        print("Can not add effekseer resource seacher path.")
                    end
                else
                    log_widget.error({tag = "Editor", message = "no project exist!"})
                end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Quit") then
            local res_root_str = tostring(fs.path "":localpath())
            global_data.project_root = lfs.path(string.sub(res_root_str, 1, #res_root_str - 1))
            global_data.packages = get_package(global_data.project_root, true)
            imgui.windows.CloseCurrentPopup();
        end
        if global_data.project_root then
            local fw = require "bee.filewatch"
            fw.add(global_data.project_root:string())
            local res_root_str = tostring(fs.path "":localpath())
            global_data.editor_root = fs.path(string.sub(res_root_str, 1, #res_root_str - 1))
            effekseer_filename_mgr.add_path("/pkg/tools.prefab_editor/res")
        end
        imgui.windows.EndPopup()
    end
end

local main_vp = {}
local last_main_vp = {}
local function is_pt_in_rect(x, y, rt)
    return  rt.x < x and x < (rt.x+rt.w) and
            rt.y < y and y < (rt.y+rt.h)
end

local function check_update_vp()
    if  main_vp.x ~= last_main_vp.x or
        main_vp.y ~= last_main_vp.y or
        main_vp.w ~= last_main_vp.w or
        main_vp.h ~= last_main_vp.h then
        last_main_vp.x, last_main_vp.y, last_main_vp.w, last_main_vp.h = 
        main_vp.x, main_vp.y, main_vp.w, main_vp.h
        return true
    end
end

local function show_dock_space()
    local imgui_vp = imgui.GetMainViewport()
    local offset = {0, uiconfig.ToolBarHeight}
    local wp, ws = imgui_vp.WorkPos, imgui_vp.WorkSize

    imgui.windows.SetNextWindowPos(wp[1] + offset[1], wp[2] + offset[2])
    imgui.windows.SetNextWindowSize(ws[1] - offset[1], ws[2] - offset[2])
    imgui.windows.SetNextWindowViewport(imgui_vp.ID)
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0.0);
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowBorderSize, 0.0);
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowPadding, 0.0, 0.0);
    if imgui.windows.Begin("MainView", imgui.flags.Window {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }) then
        imgui.dock.Space("MainViewSpace", imgui.flags.DockNode {
            "NoDockingInCentralNode",
            "PassthruCentralNode",
        })
        main_vp.x, main_vp.y, main_vp.w, main_vp.h = imgui.dock.BuilderGetCentralRect "MainViewSpace"
    end
    imgui.windows.PopStyleVar(3)
    imgui.windows.End()
end


local function calc_second_view_viewport(vr)
    return {
        x = vr.x + math.max(0, vr.w - second_view_width),
        y = vr.y + math.max(0, vr.h - second_view_height),
        w = second_view_width, h = second_view_height
    }
end

local function create_second_view_queue()
    local mq = w:singleton("main_queue", "render_target:in")
    local mqrt = mq.render_target
    local vr = calc_second_view_viewport(mqrt.view_rect)
    w:register{name="second_view"}
    ecs.create_entity{
        policy = {
            "ant.render|render_queue",
            "ant.general|name",
        },
        data = {
            camera_ref = icamera.create{
                eyepos  = mc.ZERO_PT,
                viewdir = mc.ZAXIS,
                updir   = mc.YAXIS,
                frustum = defaultcomp.frustum(vr.w / vr.h),
                name    = "second_view_camera",
            },
            render_target = {
                view_rect = vr,
                viewid = viewidmgr.generate "second_view",
                view_mode = mqrt.view_mode,
                clear_state = mqrt.clear_state,
                fb_idx = mqrt.fb_idx,
            },
            primitive_filter = {
                filter_type = "main_view",
                exclude_type = "auxgeom",
                "foreground", "opacity", "background", "translucent",
            },
            queue_name = "second_view",
            second_view = true,
            name = "second_view",
            visible = true,
        }
    }
end

local stat_window
function m:init_world()
    local iRmlUi = ecs.import.interface "ant.rmlui|irmlui"
    stat_window = iRmlUi.open "bgfx_stat.rml"

    create_second_view_queue()
end

function m:ui_update()
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.TitleBg, 0.2, 0.2, 0.2, 1)
    --choose_project()
    widget_utils.show_message_box()
    menu.show()
    toolbar.show()
    show_dock_space()
    scene_view.show()
    gridmesh_view.show()
    prefab_view.show()
    inspector.show()
    resource_browser.show()
    anim_view.show()
    console_widget.show()
    log_widget.show()
    choose_project()
    imgui.windows.PopStyleColor(2)
    imgui.windows.PopStyleVar()
    
    --drag file to view
    if imgui.util.IsMouseDragging(0) then
        local x, y = imgui.util.GetMousePos()
        if is_pt_in_rect(x, y, last_main_vp) then
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
    stat_window.postMessage(string.format("DrawCall: %d\nTriangle: %d\nTexture: %d\ncpu(ms): %f\ngpu(ms): %f\nfps: %d", 
                            bgfxstat.numDraw, bgfxstat.numTriList, bgfxstat.numTextures, bgfxstat.cpu, bgfxstat.gpu, bgfxstat.fps))
end

local hierarchy_event       = world:sub {"HierarchyEvent"}
local drop_files_event      = world:sub {"OnDropFiles"}
local entity_event          = world:sub {"EntityEvent"}
local event_keyboard        = world:sub {"keyboard"}
local event_open_prefab     = world:sub {"OpenPrefab"}
local event_preopen_prefab  = world:sub {"PreOpenPrefab"}
local event_open_fbx        = world:sub {"OpenFBX"}
local event_add_prefab      = world:sub {"AddPrefabOrEffect"}
local event_resource_browser= world:sub {"ResourceBrowser"}
local event_window_title    = world:sub {"WindowTitle"}
local event_create          = world:sub {"Create"}
local event_gizmo           = world:sub {"Gizmo"}

local light_gizmo = ecs.require "gizmo.light"

local aabb_color_i <const> = 0x6060ffff
local highlight_aabb = {
    visible = false,
    min = nil,
    max = nil,
}
local function update_heightlight_aabb(e)
    if e then
        w:sync("render_object?in", e)
        local ro = e.render_object
        if ro and ro.aabb then
            local minv, maxv = math3d.index(ro.aabb, 1, 2)
            highlight_aabb.min = math3d.tovalue(minv)
            highlight_aabb.max = math3d.tovalue(maxv)
            highlight_aabb.visible = true
            return
        end
    end
    highlight_aabb.visible = false
end

local function on_target(old, new)
    if old and old.scene and not old.scene.REMOVED then
        w:sync("camera?in", old)
        w:sync("light?in", old)
        if old.camera then
            camera_mgr.show_frustum(old, false)
        elseif old.light then
            light_gizmo.bind(nil)
        end
    end
    if new then
        local new_entity = new--type(new) == "table" and icamera.find_camera(new) or world[new]
        w:sync("camera?in", new_entity)
        w:sync("light?in", new_entity)
        if new_entity.camera then
            camera_mgr.set_second_camera(new, true)
        elseif new_entity.light then
            light_gizmo.bind(new)
        end
    end
    world:pub {"UpdateAABB", new}
    anim_view.bind(new)
end

local function on_update(e)
    update_heightlight_aabb(e)
    if not e then return end
    w:sync("camera?in", e)
    w:sync("light?in", e)
    if e.camera then
        camera_mgr.update_frustrum(e)
    elseif e.light then
        light_gizmo.update()
    end
    inspector.update_template_tranform(e)
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
    ies.set_state(node.eid, "main_view", visible)
    for _, n in ipairs(node.children) do
        update_visible(n, visible)
    end
    local adaptee = hierarchy:get_select_adaptee(node.eid)
    for _, e in ipairs(adaptee) do
        ies.set_state(e, "main_view", visible)
    end
end
function m:handle_event()
    for _, e in event_update_aabb:unpack() do
        update_heightlight_aabb(e)
    end
    for _, action, value1, value2 in event_gizmo:unpack() do
        if action == "update" or action == "ontarget" then
            inspector.update_ui(action == "update")
            if action == "ontarget" then
                on_target(value1, value2)
            elseif action == "update" then
                on_update(gizmo.target_eid)
            end
        end
    end
    for _, what, target, v1, v2 in entity_event:unpack() do
        local transform_dirty = true
        local template = hierarchy:get_template(target)
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
                hierarchy:update_display_name(target, v1)
                w:sync("collider?in", target)
                if target.collider then
                    hierarchy:update_collider_list(world)
                end
            else
                w:sync("slot?in", target)
                if target.slot then
                    hierarchy:update_slot_list(world)
                end
            end
        elseif what == "parent" then
            hierarchy:set_parent(target, v1)
            local sourceWorldMat = iom.worldmat(target)
            local targetWorldMat = v1 and iom.worldmat(v1) or mc.IDENTITY_MAT
            iom.set_srt_matrix(target, math3d.mul(math3d.inverse(targetWorldMat), sourceWorldMat))
            ecs.method.set_parent(target, v1)
            local isslot
            if v1 then
                w:sync("slot?in", v1)
                isslot = v1.slot
            end
            -- if isslot then
            --     for e in w:select "scene:in slot_name:out" do
            --         if e.scene == target.scene then
            --             e.slot_name = "None"
            --         end
            --     end
            -- end
        end
        if transform_dirty then
            on_update(target)
        end
    end
    for _, what, target, value in hierarchy_event:unpack() do
        local e = target
        if what == "visible" then
            e = target.eid
            hierarchy:set_visible(target, value, true)
            w:sync("effect_instance?in", e)
            w:sync("light?in", e)
            if e.effect_instance then
                local effekseer     = require "effekseer"
                effekseer.set_visible(e.effect_instance.handle, e.effect_instance.playid, value)
            elseif e.light then
                world:pub{"component_changed", "light", e, "visible", value}
            else
                update_visible(target, value)
            end
            for ie in w:select "scene:in ibl:in" do
                if ie.scene.parent == e then
                    isp.enable_ibl(value)
                    break
                end
            end
        elseif what == "lock" then
            hierarchy:set_lock(e, value)
        elseif what == "delete" then
            w:sync("collider?in", gizmo.target_eid)
            if gizmo.target_eid.collider then
                anim_view.on_remove_entity(gizmo.target_eid)
            end
            prefab_mgr:remove_entity(e)
            update_heightlight_aabb()
        elseif what == "movetop" then
            hierarchy:move_top(e)
        elseif what == "moveup" then
            hierarchy:move_up(e)
        elseif what == "movedown" then
            hierarchy:move_down(e)
        elseif what == "movebottom" then
            hierarchy:move_bottom(e)
        end
    end
    
    for _, filename in event_preopen_prefab:unpack() do
        anim_view:clear()
    end
    for _, filename in event_open_prefab:unpack() do
        prefab_mgr:open(filename)
        update_heightlight_aabb()
    end
    for _, filename in event_open_fbx:unpack() do
        prefab_mgr:open_fbx(filename)
        update_heightlight_aabb()
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
        elseif state.CTRL and key == "S" and press == 1 then
            prefab_mgr:save_prefab()
        elseif state.CTRL and key == "R" and press == 1 then
            anim_view:clear()
            prefab_mgr:reload()
        end
    end

    for _, what, type in event_create:unpack() do
        prefab_mgr:create(what, type)
    end
end

function m:start_frame()
    local viewport = imgui.GetMainViewport()
    local io = imgui.IO
    local current_mx = io.MousePos[1] - viewport.MainPos[1]
    local current_my = io.MousePos[2] - viewport.MainPos[2]
    if global_data.mouse_pos_x ~= current_mx or global_data.mouse_pos_y ~= current_my then
        global_data.mouse_pos_x = current_mx
        global_data.mouse_pos_y = current_my
        global_data.mouse_move = true
    end
end

function m:end_frame()
    if check_update_vp() then
        local mvp = imgui.GetMainViewport()
        local viewport = {
            x = main_vp.x - mvp.WorkPos[1],
            y = main_vp.y - mvp.WorkPos[2] + uiconfig.MenuHeight,
            w = main_vp.w, h = main_vp.h
        }
        irq.set_view_rect("tonemapping_queue", viewport)
        world:pub{"view_resize", main_vp.w, main_vp.h}
    end
    global_data.mouse_move = false
end

local mq_vr_mb = world:sub{"view_rect_changed", "main_queue"}

function m:data_changed()
    if highlight_aabb.visible and highlight_aabb.min and highlight_aabb.max then
        iwd.draw_aabb_box(highlight_aabb, nil, aabb_color_i)
    end

    for msg in mq_vr_mb:each() do
        local vr = msg[3]
        local sv_vr = calc_second_view_viewport(vr)
        irq.set_view_rect("second_view", sv_vr)
    end
end

local igui = ecs.interface "igui"
function igui.scene_viewport()
    return irq.view_rect "tonemapping_queue"
end

function igui.cvt2scenept(x, y)
    local vr = igui.scene_viewport()
    return x-vr.x, y-vr.y
end