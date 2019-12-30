local editor        = import_package "ant.editor"
local task          = editor.task
local hub          = editor.hub
local vfs           = require "vfs"
local scene         = import_package "ant.scene".util
local localfs = require "filesystem.local"
local inputmgr      = import_package "ant.inputmgr"
local gui_mgr = import_package "ant.imgui".gui_mgr
local rxbus = import_package "ant.rxlua".RxBus
local scene_control = {}
local fs = require "filesystem"

function scene_control.run_test_package(raw_path)
    log("raw_path",raw_path,type(raw_path))
    local path = localfs.path(tostring(raw_path))
    log.info_a(path)
    local mapcfg = localfs.dofile(path) 
    log.info_a(mapcfg)
    local pkgname = mapcfg.name
    local pkgsystems = mapcfg.systems or {}
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

    local pm = require "antpm"
    if not fs.exists(fs.path ("/pkg/"..pkgname)) then
        pkgname = pm.register_package(path:parent_path())
    end
    
    packages[#packages+1] = pkgname
    table.move(pkgsystems, 1, #pkgsystems, #systems+1, systems)
    scene_control.input_queue = inputmgr.queue()
    local world = scene.start_new_world(scene_control.input_queue, 
        600, 400, 
        packages, 
        systems,
        {hub=hub,rxbus = rxbus})
    local world_update = scene.loop(world, {
            update = {"timesystem", "message_system"}
        })
    -- task.safe_loop(scene.loop(world, {
    --         update = {"timesystem", "message_system"}
    --     }))
    gui_mgr.get("GuiScene"):bind_world(world,world_update,scene_control.input_queue)
end


return scene_control