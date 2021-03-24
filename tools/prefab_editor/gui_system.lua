local ecs = ...
local world     = ecs.world
local math3d    = require "math3d"
local imgui     = require "imgui"
local rhwi      = import_package 'ant.render'.hwi
local asset_mgr = import_package "ant.asset"
local geometry_drawer = import_package "ant.geometry".drawer
local irq       = world:interface "ant.render|irenderqueue"
local ies       = world:interface "ant.scene|ientity_state"
local iom       = world:interface "ant.objcontroller|obj_motion"
local iss       = world:interface "ant.scene|iscenespace"
local icoll     = world:interface "ant.collision|collider"
local drawer    = world:interface "ant.render|iwidget_drawer"
local imaterial   = world:interface "ant.asset|imaterial"
local vfs       = require "vfs"
local access    = require "vfs.repoaccess"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local hierarchy = require "hierarchy"
local resource_browser = require "widget.resource_browser"(world, asset_mgr)
local anim_view = require "widget.animation_view"(world, asset_mgr)
local log_widget = require "widget.log"(asset_mgr)
local console_widget = require "widget.console"(asset_mgr)
local toolbar = require "widget.toolbar"(world, asset_mgr)
local scene_view = require "widget.scene_view"(world, asset_mgr)
local inspector = require "widget.inspector"(world)
local particle_emitter = require "widget.particle_emitter"(world)
local uiconfig = require "widget.config"
local prefab_mgr = require "prefab_manager"(world)
local menu = require "widget.menu"(world, prefab_mgr)
local camera_mgr = require "camera_manager"(world)
local gizmo = require "gizmo.gizmo"(world)
local global_data = require "common.global_data"
local icons = require "common.icons"(asset_mgr)
local logger = require "widget.log"(asset_mgr)
local gizmo_const = require "gizmo.const"
local new_project = require "common.new_project"
local widget_utils = require "widget.utils"
local utils = require "common.utils"
local m = ecs.system 'gui_system'
local drag_file = nil
local last_x = -1
local last_y = -1
local last_width = -1
local last_height = -1
local second_view_width = 384
local second_vew_height = 216

local function on_new_project(path)
    new_project.set_path(path)
    new_project.gen_mount()
    new_project.gen_init_system()
    new_project.gen_main()
    new_project.gen_package_ecs()
    new_project.gen_package()
    new_project.gen_settings()
    new_project.gen_bat()
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
        access.readmount(repo, readmount)
    end
    local merged_repo = vfs.merge_mount(repo)
    local packages = {}
    for _, name in ipairs(merged_repo._mountname) do
        local key
        local skip = false
        if utils.start_with(name, "pkg/ant.") then
            if name == "pkg/ant.resources" or name == "pkg/ant.resources.binary" then
                key = "/"..name
            else
                skip = true
            end
        else
            if utils.start_with(name, "pkg/") then
                key = "/"..name
            else
                key = name
            end
        end
        if not skip then
            packages[#packages + 1] = {name = key, path = merged_repo._mountpoint[name]}
        end
    end
    return packages
end

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
                for path in lpath:list_directory() do
                    not_empty = true
                    break
                end
                if not_empty then
                    logger.error({tag = "Editor", message = "folder not empty!"})
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
                    local cthread = require "thread"
                    cthread.newchannel "log_channel"
                    cthread.newchannel "fileserver_channel"
                    cthread.newchannel "console_channel"
                    local produce = cthread.channel_produce "fileserver_channel"
                    produce:push(arg, path)
                    local lthread = require "editor.thread"
                    fileserver_thread = lthread.create [[
                        package.path = "engine/?.lua;tools/prefab_editor/?.lua"
                        require "bootstrap"
                        local fileserver = require "fileserver_adapter"()
                        fileserver.run()
                    ]]
                    log_widget.init_log_receiver()
                    console_widget.init_console_sender()
                else
                    logger.error({tag = "Editor", message = "not project exist!"})
                end
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button("Quit") then
            local res_root_str = tostring(fs.path "":localpath())
            global_data.project_root = lfs.path(string.sub(res_root_str, 1, #res_root_str - 1))
            global_data.packages = get_package(lfs.absolute(lfs.path(arg[0])):remove_filename(), false)
            imgui.windows.CloseCurrentPopup();
            show_mount_dialog = true
        end
        if global_data.project_root then
            local fw = require "filewatch"
            fw.add(global_data.project_root:string())
            local res_root_str = tostring(fs.path "":localpath())
            global_data.editor_root = fs.path(string.sub(res_root_str, 1, #res_root_str - 1))
        end
        imgui.windows.EndPopup()
    end
end

local fileserver_thread

local function show_dock_space(offset_x, offset_y)
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1] + offset_x, viewport.WorkPos[2] + offset_y)
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1] - offset_x, viewport.WorkSize[2] - offset_y)
    imgui.windows.SetNextWindowViewport(viewport.ID)
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0.0);
	imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowBorderSize, 0.0);
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowPadding, 0.0, 0.0);
    local wndflags = imgui.flags.Window {
        "NoDocking",
        "NoTitleBar",
        "NoCollapse",
        "NoResize",
        "NoMove",
        "NoBringToFrontOnFocus",
        "NoNavFocus",
        "NoBackground",
    }
    local dockflags = imgui.flags.DockNode {
        "NoDockingInCentralNode",
        "PassthruCentralNode",
    }
    if not imgui.windows.Begin("DockSpace Demo", wndflags) then
        imgui.windows.PopStyleVar(3)
        imgui.windows.End()
        return
    end
    imgui.dock.Space("MyDockSpace", dockflags)
    local x,y,w,h = imgui.dock.BuilderGetCentralRect("MyDockSpace")
    imgui.windows.PopStyleVar(3)
    imgui.windows.End()
    return x,y,w,h
end
local iRmlUi    = world:interface "ant.rmlui|rmlui"
local irq       = world:interface "ant.render|irenderqueue"
local bgfx      = require "bgfx"
local effect    = require "effect"
local stat_window
function m:ui_update()
    imgui.windows.PushStyleVar(imgui.enum.StyleVar.WindowRounding, 0)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.WindowBg, 0.2, 0.2, 0.2, 1)
    imgui.windows.PushStyleColor(imgui.enum.StyleCol.TitleBg, 0.2, 0.2, 0.2, 1)
    choose_project()
    widget_utils.show_message_box()
    menu.show()
    toolbar.show()
    local x, y, width, height = show_dock_space(0, uiconfig.ToolBarHeight)
    scene_view.show()
    particle_emitter.show()
    inspector.show()
    resource_browser.show()
    anim_view.show()
    console_widget.show()
    log_widget.show()
    imgui.windows.PopStyleColor(2)
    imgui.windows.PopStyleVar()
    local dirty = false
    if last_x ~= x then last_x = x dirty = true end
    if last_y ~= y then last_y = y dirty = true  end
    if last_width ~= width then last_width = width dirty = true  end
    if last_height ~= height then last_height = height dirty = true  end
    if dirty then
        local mvp = imgui.GetMainViewport()
        local viewport = {x = x - mvp.WorkPos[1], y = y - mvp.WorkPos[2] + uiconfig.MenuHeight, w = width, h = height}
        irq.set_view_rect(world:singleton_entity_id "main_queue", viewport)

        iRmlUi.update_viewrect(viewport.x, viewport.y, viewport.w, viewport.h)

        local secondViewport = {x = viewport.x + (width - second_view_width), y = viewport.y + (height - second_vew_height), w = second_view_width, h = second_vew_height}
        irq.set_view_rect(camera_mgr.second_view, secondViewport)
        world:pub {"ViewportDirty", viewport}
    end
    --drag file to view
    if imgui.util.IsMouseDragging(0) then
        local x, y = imgui.util.GetMousePos()
        if (x > last_x and x < (last_x + last_width) and y > last_y and y < (last_y + last_height)) then
            if not drag_file then
                local dropdata = imgui.widget.GetDragDropPayload()
                if dropdata and (string.sub(dropdata, -7) == ".prefab"
                    or string.sub(dropdata, -4) == ".efk") then
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

    if not stat_window then
        local iRmlUi = world:interface "ant.rmlui|rmlui"
        stat_window = iRmlUi.open "bgfx_stat.rml"
    end
    local bgfxstat = bgfx.get_stats("sdcpnmtv")
    if bgfxstat then
        stat_window.postMessage(string.format("DrawCall: %d\nTriangle: %d\nTexture: %d\ncpu(ms): %f\ngpu(ms): %f\nfps: %d", bgfxstat.numDraw, bgfxstat.numTriList, bgfxstat.numTextures, bgfxstat.cpu, bgfxstat.gpu, bgfxstat.fps))
    end
    local particlestat = effect.particle_stat()
    if particlestat then
        stat_window.postMessage(string.format("Particle: " .. math.floor(particlestat.count)))
    end
end

local entity_state_event = world:sub {"EntityState"}
local drop_files_event = world:sub {"OnDropFiles"}
local entity_event = world:sub {"EntityEvent"}
local event_keyboard = world:sub{"keyboard"}
local event_open_prefab = world:sub {"OpenPrefab"}
local event_add_prefab = world:sub {"AddPrefabOrEffect"}
local event_resource_browser = world:sub {"ResourceBrowser"}
local event_window_title = world:sub {"WindowTitle"}
local event_create = world:sub {"Create"}
local event_gizmo = world:sub {"Gizmo"}
local light_gizmo = require "gizmo.light"(world)

local function on_target(old, new)
    if old and world[old] then
        if world[old].camera then
            camera_mgr.show_frustum(old, false)
        elseif world[old].light_type then
            light_gizmo.bind(nil)
        end
    end
    if new then
        local new_entity = world[new]
        if new_entity.camera then
            camera_mgr.set_second_camera(new, true)
        elseif new_entity.light_type then
            light_gizmo.bind(new)
        elseif new_entity.emitter then
            particle_emitter.set_emitter(new)
        end
    end
    prefab_mgr:update_current_aabb(new)
    anim_view.bind(new)
end

local function on_update(eid)
    if not eid then return end
    if world[eid].collider then
        anim_view.on_collider_update(eid)
        return
    end
    if world[eid].camera then
        camera_mgr.update_frustrum(eid)
    elseif world[eid].light_type then
        light_gizmo.update()
    end
    prefab_mgr:update_current_aabb(eid)
end

local cmd_queue = require "gizmo.command_queue"(world)

function m:data_changed()
    -- if prefab_mgr.collider and icoll.test(world[prefab_mgr.collider["sphere"]]) then
    --     print("sphere collision")
    -- end
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
            --template.template.data.transform.position = v2
            cmd_queue:record {action = gizmo_const.MOVE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "rotate" then
            gizmo:set_rotation(math3d.quaternion{math.rad(v2[1]), math.rad(v2[2]), math.rad(v2[3])})
            --template.template.data.transform.rotate = v2
            cmd_queue:record {action = gizmo_const.ROTATE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "scale" then
            gizmo:set_scale(v2)
            --template.template.data.transform.scale = v2
            cmd_queue:record {action = gizmo_const.SCALE, eid = target, oldvalue = v1, newvalue = v2}
        elseif what == "name" then
            transform_dirty = false
            template.template.data.name = v1
            hierarchy:update_display_name(target, v1)
            if world[target].slot then
                hierarchy:update_slot_list()
            end
        elseif what == "parent" then
            hierarchy:set_parent(target, v1)
            local sourceWorldMat = iom.calc_worldmat(target)
            local targetWorldMat = iom.calc_worldmat(v1)
            iom.set_srt(target, math3d.mul(math3d.inverse(targetWorldMat), sourceWorldMat))
            iss.set_parent(target, v1)
            if not world[v1].slot and world[target].collider then
                world[target].slot_name = "None"
            end
            inspector.update_template_tranform(target)
        end
        if transform_dirty then
            on_update(target)
        end
    end
    for _, what, eid, value in entity_state_event:unpack() do
        if what == "visible" then
            hierarchy:set_visible(eid, value)
            ies.set_state(eid, what, value)
            local template = hierarchy:get_template(eid)
            if template and template.children then
                for _, e in ipairs(template.children) do
                    ies.set_state(e, what, value)
                end
            end
        elseif what == "lock" then
            hierarchy:set_lock(eid, value)
            
            local animation = world:interface "ant.animation|animation"
            animation.set_time(eid, 0)
            animation.play(eid, "running", 0)
            animation.set_speed(eid, 0.5)
            animation.set_loop(eid, false)
        elseif what == "delete" then
            prefab_mgr:remove_entity(eid)
        end
    end
    for _, filename in event_open_prefab:unpack() do
        prefab_mgr:open(filename)
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
            prefab_mgr:remove_entity(gizmo.target_eid)
            gizmo:set_target(nil)
        elseif state.CTRL and key == "S" and press == 1 then
            prefab_mgr:save_prefab()
        end
    end

    for _, what, type in event_create:unpack() do
        prefab_mgr:create(what, type)
    end
end

local DEFAULT_COLOR <const> = 0xffffff00
local geo_utils = require "editor.geometry_utils"(world)
local anim_entity
local anim_transform = math3d.ref()
local current_skeleton
local skeleton_eid
function m:widget()
    if skeleton_eid then
        ies.set_state(skeleton_eid, "visible", false)
    end
    local eid = gizmo.target_eid
    if not eid then return end
    local e = world[eid]
    if not e.skeleton then return end
    if current_skeleton ~= e.skeleton then
        current_skeleton = e.skeleton
        if skeleton_eid then
            world:remove_entity(skeleton_eid)
        end
        local desc={vb={}, ib={}}
        geometry_drawer.draw_skeleton(e.skeleton._handle, e.pose_result, DEFAULT_COLOR, iom.calc_worldmat(eid), desc)
        skeleton_eid = geo_utils.create_dynamic_lines(e.transform, desc.vb, desc.ib, "skeleton", DEFAULT_COLOR)
        ies.set_state(skeleton_eid, "auxgeom", true)
        anim_transform.m = iom.calc_worldmat(eid)
        anim_entity = e
    end
    if skeleton_eid then
        ies.set_state(skeleton_eid, "visible", true)
        local desc={vb={}, ib={}}
        geometry_drawer.draw_skeleton(anim_entity.skeleton._handle, anim_entity.pose_result, DEFAULT_COLOR, anim_transform, desc, anim_view.get_current_joint())
        local rc = world[skeleton_eid]._rendercache
        local vbdesc, ibdesc = rc.vb, rc.ib
        bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", desc.vb))
        bgfx.update(ibdesc.handle, 0, bgfx.memory_buffer("w", desc.ib))
    end
end