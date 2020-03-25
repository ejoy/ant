local editor        = import_package "ant.editor"
local hub           = editor.hub
local scene         = import_package "ant.scene".util
local localfs = require "filesystem.local"
local gui_mgr = import_package "ant.imgui".gui_mgr
local editor_world = import_package "ant.imgui".editor_world
local rxbus = import_package "ant.rxlua".RxBus
local scene_control = {}

function scene_control.run_test_package(raw_path)
    local path = localfs.path(tostring(raw_path))
    local mapcfg = localfs.dofile(path)

    local vfs = require "vfs"
    vfs.reset(path:parent_path())

    local config = {
        policy      = mapcfg.world.policy,
        system      = mapcfg.world.system,
        hub         = hub,
        rxbus       = rxbus,
        world_class = editor_world(),
        width       = 600,
        height      = 400,
    }

    local world = scene.create_world()
    world.init(config)
    world.size(config.width, config.height)
    gui_mgr.get("GuiScene"):bind_world(world)
end

return scene_control
