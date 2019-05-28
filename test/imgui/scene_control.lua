local editor        = import_package "ant.editor"
local mapiup        = editor.mapiup
local task          = editor.task
local vfs           = require "vfs"
local scene         = import_package "ant.scene".util
local localfs = require "filesystem.local"
local inputmgr      = import_package "ant.inputmgr"
local gui_mgr = import_package "ant.imgui".gui_mgr
local scene_control = {}

function scene_control.test_new_world(raw_path)
    print("raw_path",raw_path,type(raw_path))
    local path = localfs.path(tostring(raw_path))
    print_a(path)
    local mapcfg = localfs.dofile(path) 
    print_a(mapcfg)
    local pkgname = mapcfg.name
    local pkgsystems = mapcfg.systems
    local packages = {
        -- "ant.EditorLauncher",
        -- "ant.objcontroller",
        "ant.testimgui",
        "ant.hierarchy.offline",
    }
    local systems = {
        --"pickup_material_system",
        --"pickup_system",
        "obj_transform_system",
        "build_hierarchy_system",
        "editor_camera_controller",
        -- "editor_watcher_system",
        -- "editor_system"
    }

    vfs.remove_mount("currentmap")
    vfs.add_mount("currentmap", path:parent_path())
    local pm = require "antpm"
    if not pm.find(pkg_name) then
        pkg_name = pm.register("currentmap")
    end
    
    packages[#packages+1] = pkgname
    table.move(pkgsystems, 1, #pkgsystems, #systems+1, systems)
    scene_control.input_queue = inputmgr.queue()
    local world = scene.start_new_world(scene_control.input_queue, 600, 400, packages, systems)
    task.safe_loop(scene.loop(world, {
            update = {"timesystem", "message_system"}
        }))
    gui_mgr.get("GuiScene"):bind_world(world,scene_control.input_queue)
end


return scene_control