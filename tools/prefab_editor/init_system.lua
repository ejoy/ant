local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local irq = world:interface "ant.render|irenderqueue"
local camera = world:interface "ant.camera|camera"
local entity = world:interface "ant.render|entity"
local m = ecs.system 'init_system'
local imgui      = require "imgui"
local prefab_mgr = require "prefab_manager"
local iom = world:interface "ant.objcontroller|obj_motion"
local lfs  = require "filesystem.local"
local fs   = require "filesystem"
local vfs = require "vfs"
local prefab_view = require "prefab_view"

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
    
    entity.create_procedural_sky()
    local e = world:singleton_entity "main_queue"
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0xa0a0a0ff)
    camera.bind(camera.create {
        eyepos = {-200, 100,200, 1},
        viewdir = {2,-1,-2,0},
        frustum = {f = 1000}
    }, "main_queue")
    entity.create_grid_entity("", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
    world:instance "res/light_directional.prefab"
end

function m:data_changed()

end