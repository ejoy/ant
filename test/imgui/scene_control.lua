local editor        = import_package "ant.editor"
local task          = editor.task
local hub           = editor.hub
local vfs           = require "vfs"
local scene         = import_package "ant.scene".util
local localfs = require "filesystem.local"
local gui_mgr = import_package "ant.imgui".gui_mgr
local gui_util = import_package "ant.imgui".editor.gui_util
local editor_world = import_package "ant.imgui".editor_world
local rxbus = import_package "ant.rxlua".RxBus
local scene_control = {}
local fs = require "filesystem"

function scene_control.run_test_package(raw_path)
    log("raw_path",raw_path,type(raw_path))
    local path = fs.path(tostring(raw_path))
    log.info_a(path)
    local mapcfg = localfs.dofile(path) 
    log.info_a(mapcfg)
    local pkgname = mapcfg.name or "ant.test.features"
    local pkgsystems = mapcfg.systems or {"init_loader",}
    local packages = {
        -- "ant.EditorLauncher",
        -- "ant.objcontroller",
        pkgname,
        "ant.imgui",
        "ant.testimgui",
        "ant.hierarchy.offline",
    }
    local systems = {
        --"pickup_material_system", 
        "init_loader", -- test only
        "pickup_system",
        -- "obj_transform_system",
        "build_hierarchy_system",
        "editor_watcher_system",
        "editor_operate_gizmo_system",
        "editor_tool_system",
        "visible_system",
        "world_profile_system"
        -- "editor_system"
    }

    local config = require "scene_start_cfg".editor
    config.hub=hub
    config.rxbus=rxbus

    local pm = require "antpm"
    if not fs.exists(fs.path ("/pkg/"..pkgname)) then
        local lpath = localfs.path(path:string())
        gui_util.remount_package(lpath:parent_path())
        -- gui_util.mount_package(lpath:parent_path())
        -- pm.load_package(lpath:parent_path())
        -- pkgname = pm.editor_register_package(path:parent_path())
    end
    
    -- packages[#packages+1] = pkgname
    -- table.move(pkgsystems, 1, #pkgsystems, #systems+1, systems)
    -- local world = scene.start_new_world(
    --     600, 400,
    --     packages,
    --     systems,
    --     {hub=hub,rxbus = rxbus})
    local world = scene.start_new_world(
        600, 400,
        config,editor_world())
    local world_update = scene.loop(world)
    -- task.safe_loop(scene.loop(world))
    gui_mgr.get("GuiScene"):bind_world(world,world_update,scene_control.input_queue)
end


return scene_control