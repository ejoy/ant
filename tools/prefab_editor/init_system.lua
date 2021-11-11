local ecs = ...
local world = ecs.world
local w = world.w
local irq           = ecs.import.interface "ant.render|irenderqueue"
local icamera       = ecs.import.interface "ant.camera|camera"
local entity        = ecs.import.interface "ant.render|entity"
local iRmlUi        = ecs.import.interface "ant.rmlui|rmlui"
local irender       = ecs.import.interface "ant.render|irender"
local iani          = ecs.import.interface "ant.animation|animation"
local iom           = ecs.import.interface "ant.objcontroller|obj_motion"
local default_comp  = import_package "ant.general".default
local camera_mgr    = ecs.require "camera_manager"
local imgui         = require "imgui"
local lfs           = require "filesystem.local"
local fs            = require "filesystem"
local gd            = require "common.global_data"

local bind_billboard_camera_mb = world:sub{"bind_billboard_camera"}
function ecs.method.bind_billboard_camera(e, camera_ref)
    world:pub{"bind_billboard_camera", e, camera_ref}
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
end

local function init_camera()
    local mq = w:singleton("main_queue", "camera_ref:in")
    iom.set_position(mq.camera_ref, {-200, 100, 200, 1})
    iom.set_direction(mq.camera_ref, {2, -1, -2, 0})
    local f = icamera.get_frustum(mq.camera_ref)
    f.n, f.f = 1, 1000
    icamera.set_frustum(mq.camera_ref, f)
end

function m:init_world()
    irq.set_view_clear_color("main_queue", 0x353535ff)--0xa0a0a0ff
    init_camera()
    create_second_view()
end

function m:post_init()
    iRmlUi.preload_dir "/pkg/tools.prefab_editor/res/ui"
end

function m:data_changed()
    for _, e, camera_ref in bind_billboard_camera_mb:unpack() do
        w:sync("render_object?in", e)
        e.render_object.camera_ref = camera_ref or w:singleton("main_queue", "camera_ref:in").camera_ref
    end
end