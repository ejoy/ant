local ecs = ...
local world = ecs.world
local w = world.w
local irq           = ecs.import.interface "ant.render|irenderqueue"
local icamera       = ecs.import.interface "ant.camera|camera"
local entity        = ecs.import.interface "ant.render|entity"
local iRmlUi        = ecs.import.interface "ant.rmlui|rmlui"
local irender       = ecs.import.interface "ant.render|irender"
local iani          = ecs.import.interface "ant.animation|animation"
local default_comp  = import_package "ant.general".default
local camera_mgr    = ecs.require "camera_manager"
local imgui         = require "imgui"
local lfs           = require "filesystem.local"
local fs            = require "filesystem"
local gd            = require "common.global_data"
local bb_a = ecs.action "bind_billboard_camera"
function bb_a.init(prefab, idx, value)
    local eid = prefab[idx]
    local camera_ref = prefab[value]
    if camera_ref == nil then
        for e in w:select "main_queue camera_ref:in" do
            camera_ref = e.camera_ref
        end
    end
    world[eid]._rendercache.camera_ref = camera_ref
end

local m = ecs.system 'init_system'

local function LoadImguiLayout(filename)
    local rf = lfs.open(filename, "rb")
    if rf then
        local setting = rf:read "a"
        rf:close()
        imgui.util.LoadIniSettings(setting)
    end
end

local function create_second_view()
    local vr = {x = 0, y = 0, w = 1280, h = 720}
    irender.create_view_queue(
        vr, camera_mgr.second_view,
        icamera.create{
            eyepos  = {0, 0, 0, 1},
            viewdir = {0, 0, 1, 0},
            updir   = {0, 1, 0, 0},
            frustum = default_comp.frustum(vr.w / vr.h),
            name = camera_mgr.second_view,
        }, "visible", "auxgeom")
end

function m:init()
    iani.set_edit_mode(true)

    LoadImguiLayout(fs.path "":localpath() .. "/" .. "imgui.layout")

    entity.create_grid_entity_simple("", nil, nil, nil, {srt={r={0,0.92388,0,0.382683},}})
    imgui.SetWindowTitle("PrefabEditor")
    gd.editor_package_path = "/pkg/tools.prefab_editor/"

    create_second_view()
end

function m:post_init()
    iRmlUi.preload_dir "/pkg/tools.prefab_editor/res/ui"
end

function m:entity_init()
    for _ in w:select "INIT main_queue render_target:in" do
        irq.set_view_clear_color("main_queue", 0x353535ff)--0xa0a0a0ff
        
        local main_camera = icamera.create {
            eyepos = {-200, 100, 200, 1},
            viewdir = {2, -1, -2, 0},
            frustum = {n = 1, f = 1000 },
            updir = {0.0, 1.0, 0.0, 0}
        }
        irq.set_camera("main_queue", main_camera)
        camera_mgr.main_camera = main_camera
    end

    for _ in w:select "INIT second_view" do
        local second_camera = icamera.create {
            eyepos = {2, 2, -2, 1},
            viewdir = {-2, -1, 2, 0},
            frustum = {n = 1, f = 100 },
            updir = {0.0, 1.0, 0.0, 0}
        }
        -- local rc = icamera.find_camera(second_camera)
        -- rc.viewmat = icamera.calc_viewmat(second_camera)
        -- rc.projmat = icamera.calc_projmat(second_camera)
        -- rc.viewprojmat = icamera.calc_viewproj(second_camera)
        camera_mgr.second_view_camera = second_camera
        camera_mgr.set_second_camera(second_camera, false)
    end
end