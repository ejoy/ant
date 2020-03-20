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
    local path = fs.path(tostring(raw_path))
    local mapcfg = localfs.dofile(path)
    if not fs.exists(fs.path ("/pkg/"..mapcfg.name)) then
        local lpath = localfs.path(path:string())
        gui_util.remount_package(lpath:parent_path())
    end

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
