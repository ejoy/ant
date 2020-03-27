local editor        = import_package "ant.editor"
local hub           = editor.hub
local scene         = import_package "ant.scene".util
local localfs = require "filesystem.local"
local gui_mgr = import_package "ant.imgui".gui_mgr
local gui_util = import_package "ant.imgui".editor.gui_util
local editor_world = import_package "ant.imgui".editor_world
local rxbus = import_package "ant.rxlua".RxBus
local scene_control = {}
local fs = require "filesystem"

function scene_control.run_test_package(raw_path)
    local path = localfs.path(tostring(raw_path))
    local mapcfg = localfs.dofile(path)

    local vfs = require "vfs"
    vfs.reset(path:parent_path())

    local ori_policy = assert( mapcfg.world.policy )
    local ori_system = assert( mapcfg.world.system )
    local config = {
        policy      = mapcfg.world.policy,
        system      = mapcfg.world.system,
        hub         = hub,
        rxbus       = rxbus,
        world_class = editor_world(),
        width       = 600,
        height      = 400,
    }

    local editor_policy = {
        "ant.imgui|gizmo_object",
        "ant.imgui|outline",
        "ant.imgui|test_add_policy",
        "ant.imgui|base_entity",
    }
    local editor_system ={
        "ant.imgui|editor_watcher_system",
        "ant.imgui|editor_operate_gizmo_system",
        "ant.imgui|editor_tool_system",
        "ant.imgui|world_profile_system",
        "ant.imgui|editor_msg_watch_system",
    }

    for i,item in ipairs(editor_policy) do
        table.insert(ori_policy,item)
    end

    for i,item in ipairs(editor_system) do
        table.insert(ori_system,item)
    end

    local world = scene.create_world()
    world.init(config)
    world.size(config.width, config.height)
    gui_mgr.get("GuiScene"):bind_world(world)
end

return scene_control
