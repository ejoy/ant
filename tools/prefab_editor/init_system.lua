local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant

local irq           = ecs.import.interface "ant.render|irenderqueue"
local icamera       = ecs.import.interface "ant.camera|icamera"
local iRmlUi        = ecs.import.interface "ant.rmlui|irmlui"
local iani          = ecs.import.interface "ant.animation|ianimation"
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local editor_setting= require "editor_setting"
local imgui         = require "imgui"
local lfs           = require "filesystem.local"
local fs            = require "filesystem"
local gd            = require "common.global_data"

local math3d        = require "math3d"

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

function m:init()
    world.__EDITOR__ = true
    iani.set_edit_mode(true)

    LoadImguiLayout(fs.path "":localpath() .. "/" .. "imgui.layout")

    imgui.SetWindowTitle("PrefabEditor")
    gd.editor_package_path = "/pkg/tools.prefab_editor/"

    if editor_setting.setting.camera == nil then
        editor_setting.update_camera_setting(0.1)
    end
    world:pub{"camera_controller", "move_speed", editor_setting.setting.camera.speed}
end

local function init_camera()
    local mq = w:singleton("main_queue", "camera_ref:in")
    local eye, at = math3d.vector(5, 5, 5, 1), mc.ZERO_PT
    iom.set_position(mq.camera_ref, {5, 5, 5, 1})
    iom.set_direction(mq.camera_ref, math3d.normalize(math3d.sub(at, eye)))
    local f = icamera.get_frustum(mq.camera_ref)
    f.n, f.f = 1, 1000
    icamera.set_frustum(mq.camera_ref, f)
end

function m:init_world()
    irq.set_view_clear_color("main_queue", 0x353535ff)--0xa0a0a0ff
    init_camera()
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