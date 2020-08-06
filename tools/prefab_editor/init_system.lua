local ecs = ...
local world = ecs.world
local irq           = world:interface "ant.render|irenderqueue"
local camera        = world:interface "ant.camera|camera"
local entity        = world:interface "ant.render|entity"
local imgui         = require "imgui"
local lfs           = require "filesystem.local"
local fs            = require "filesystem"
local rhwi          = import_package 'ant.render'.hwi
local window        = require "window"
local global_data   = require "common.global_data"
local prefab_mgr    = require "prefab_manager"
local m             = ecs.system 'init_system'

local function LoadImguiLayout(filename)
    local rf = lfs.open(filename, "rb")
    if rf then
        local setting = rf:read "a"
        rf:close()
        imgui.util.LoadIniSettings(setting)
    end
end

function m:init()
    imgui.setDockEnable(true)
    LoadImguiLayout(fs.path "":localpath() .. "/" .. "imgui.layout")

    prefab_mgr:init(world)
    
    local irender = world:interface "ant.render|irender"
    global_data.second_view = irender.create_view_queue({x = 0, y = 0, w = 1280, h = 720}, "second_view")

    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0xa0a0a0ff)
    local main_camera = camera.create {
        eyepos = {-200, 100, 200, 1},
        viewdir = {2, -1, -2, 0},
        frustum = {f = 1000 }
    }
    camera.bind(main_camera, "main_queue")
    --camera.bind(main_camera, "view_queue")
    
    -- local rc = world[main_camera]._rendercache
    -- local icamera = world:interface "ant.camera|camera"
    -- rc.viewmat = icamera.calc_viewmat(main_camera)
    -- rc.projmat = icamera.calc_projmat(main_camera)
    -- rc.viewprojmat = icamera.calc_viewproj(main_camera)

    camera.bind_queue(main_camera, global_data.second_view)

    entity.create_procedural_sky()
    entity.create_grid_entity("", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
    world:instance "res/light_directional.prefab"

    window.set_title(rhwi.native_window(), "PrefabEditor")
end

function m:post_init()

end

function m:data_changed()

end