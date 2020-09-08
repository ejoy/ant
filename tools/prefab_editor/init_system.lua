local ecs = ...
local world = ecs.world
local irq           = world:interface "ant.render|irenderqueue"
local icamera       = world:interface "ant.camera|camera"
local entity        = world:interface "ant.render|entity"
local camera_mgr    = require "camera_manager"(world)
local rhwi          = import_package 'ant.render'.hwi
local imgui         = require "imgui"
local lfs           = require "filesystem.local"
local fs            = require "filesystem"
local window        = require "window"

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

    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0xa0a0a0ff)
    
    local main_camera = icamera.create {
        eyepos = {-200, 100, 200, 1},
        viewdir = {2, -1, -2, 0},
        frustum = {n = 1, f = 1000 }
    }
    icamera.bind(main_camera, "main_queue")
    camera_mgr.main_camera = main_camera

    local irender = world:interface "ant.render|irender"
    camera_mgr.second_view = irender.create_view_queue({x = 0, y = 0, w = 1280, h = 720}, "second_view", "auxgeom")
    local second_camera = icamera.create {
        eyepos = {2, 2, -2, 1},
        viewdir = {-2, -1, 2, 0},
        frustum = {f = 1000 }
    }
    local rc = world[second_camera]._rendercache
    rc.viewmat = icamera.calc_viewmat(second_camera)
    rc.projmat = icamera.calc_projmat(second_camera)
    rc.viewprojmat = icamera.calc_viewproj(second_camera)
    camera_mgr.second_view_camera = second_camera
    camera_mgr.set_second_camera(second_camera, false)
    
    entity.create_procedural_sky()
    --world:instance "res/skybox.prefab"
    entity.create_grid_entity("", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
    world:instance "res/light_directional.prefab"

    window.set_title(rhwi.native_window(), "PrefabEditor")
end

function m:post_init()

end

function m:data_changed()

end