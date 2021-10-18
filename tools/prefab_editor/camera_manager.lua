local ecs = ...
local world = ecs.world
local w = world.w

local iom         = ecs.import.interface "ant.objcontroller|obj_motion"
local icamera     = ecs.import.interface "ant.camera|camera"
local imaterial   = ecs.import.interface "ant.asset|imaterial"
local ies         = ecs.import.interface "ant.scene|ientity_state"
local irq         = ecs.import.interface "ant.render|irenderqueue"
local geo_utils   = ecs.require "editor.geometry_utils"
local icamera_recorder = ecs.import.interface "ant.camera|icamera_recorder"
local utils   = require "common.utils"
local math3d  = require "math3d"
local bgfx = require "bgfx"

local camera_mgr = {
    FRUSTUM_LEFT    = 1,
    FRUSTUM_TOP     = 2,
    FRUSTUM_RIGHT   = 3,
    FRUSTUM_BOTTOM  = 4,
    second_view     = "second_view",
}

local normal_color      = {1, 0.3, 0.3, 1}
local normal_color_i    = 0xff5050ff
local highlight_color   = {1, 1, 0, 1}
local default_near_clip = 0.1
local default_far_clip  = 100
local default_fov       = 30
        
function camera_mgr.get_editor_data(e)
    if not e or #e == 0 then return end
    w:sync("camera:in", e)
    if not e.camera._editor then
        e.camera._editor = {target = -1, dist_to_target = 5}
    end
    return e.camera._editor
end

function camera_mgr.set_second_camera(eid, show)
    if not eid then return end
    irq.set_camera(camera_mgr.second_view, eid)
    camera_mgr.second_camera = eid
    camera_mgr.show_frustum(eid, show)
end

function camera_mgr.reset_frustum_color(eid)
    local boundary = camera_mgr.get_editor_data(eid).far_boundary
    imaterial.set_property(boundary[camera_mgr.FRUSTUM_LEFT].line_eid, "u_color", normal_color)
    imaterial.set_property(boundary[camera_mgr.FRUSTUM_TOP].line_eid, "u_color", normal_color)
    imaterial.set_property(boundary[camera_mgr.FRUSTUM_RIGHT].line_eid, "u_color", normal_color)
    imaterial.set_property(boundary[camera_mgr.FRUSTUM_BOTTOM].line_eid, "u_color", normal_color)
end

function camera_mgr.highlight_frustum(eid, dir, highlight)
    local boundary = camera_mgr.get_editor_data(eid).far_boundary
    boundary[dir].highlight = highlight
    if highlight then
        imaterial.set_property(boundary[dir].line_eid, "u_color", highlight_color)
    else
        imaterial.set_property(boundary[dir].line_eid, "u_color", normal_color)
    end
end

function camera_mgr.set_frustum_fov(camera_ref, fov)
    icamera.set_frustum_fov(camera_ref, fov)
    camera_mgr.update_frustrum(camera_ref)
end

function camera_mgr.update_frustrum(cam_eid)
    --if not cam_eid or not world[cam_eid].camera then return end
    if not cam_eid then return end
    local editor_data = camera_mgr.get_editor_data(cam_eid)
    local frustum_points = math3d.frustum_points(icamera.calc_viewproj(cam_eid))
    local frustum_eid = editor_data.frustum_eid
    if not frustum_eid then
        editor_data.frustum_eid = geo_utils.create_dynamic_frustum(frustum_points, "frustum", normal_color, true)
        frustum_eid = editor_data.frustum_eid
    else
        w:sync("render_object:in", frustum_eid)
        local rc = frustum_eid.render_object
        local vbdesc, ibdesc = rc.vb, rc.ib
        bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", geo_utils.get_frustum_vb(frustum_points, normal_color_i)));
    end

    local old_boundary = editor_data.far_boundary
    local boundary = {}
    local function create_boundary(dir, p1, p2)
        local tp1 = math3d.totable(p1)
        local tp2 = math3d.totable(p2)
        local eid
        local old_highlight = false
        if not old_boundary then
            eid = geo_utils.create_dynamic_line(nil, tp1, tp2, "line", old_highlight and highlight_color or normal_color, true)
        else
            old_highlight = old_boundary[dir].highlight or false
            eid = old_boundary[dir].line_eid
            local vb = {
                tp1[1], tp1[2], tp1[3], normal_color_i,
                tp2[1], tp2[2], tp2[3], normal_color_i,
            }
            w:sync("render_object:in", eid)
            local rc = eid.render_object
            local vbdesc = rc.vb
            bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", vb));
            imaterial.set_property(eid, "u_color", old_highlight and highlight_color or normal_color)
        end
        boundary[dir] = {tp1, tp2, line_eid = eid, highlight = old_highlight}
    end
    create_boundary(camera_mgr.FRUSTUM_LEFT, frustum_points[5], frustum_points[6])
    create_boundary(camera_mgr.FRUSTUM_TOP, frustum_points[6], frustum_points[8])
    create_boundary(camera_mgr.FRUSTUM_RIGHT, frustum_points[8], frustum_points[7])
    create_boundary(camera_mgr.FRUSTUM_BOTTOM, frustum_points[7], frustum_points[5])

    editor_data.far_boundary = boundary
end

function camera_mgr.show_frustum(eid, visible)
    -- if camera_mgr.second_camera ~= eid then
    --     return
    -- end
    local editor_data = camera_mgr.get_editor_data(eid)
    irq.set_visible(camera_mgr.second_view, visible)
    if editor_data and editor_data.frustum_eid and #editor_data.frustum_eid > 0 then
        local state = "visible"
        ies.set_state(editor_data.frustum_eid, state, visible)
        local boundary = editor_data.far_boundary
        ies.set_state(boundary[1].line_eid, state, visible)
        ies.set_state(boundary[2].line_eid, state, visible)
        ies.set_state(boundary[3].line_eid, state, visible)
        ies.set_state(boundary[4].line_eid, state, visible)
    end
end

local function update_direction(eid)
    if camera_mgr.get_editor_data(eid).target < 0 or not world[camera_mgr.get_editor_data(eid).target] then return end
    local target_pos = iom.get_position(camera_mgr.get_editor_data(eid).target)
    local eyepos = iom.get_position(eid)
    local viewdir = math3d.normalize(math3d.sub(target_pos, eyepos))
    iom.lookto(eid, eyepos, viewdir, {0, 1, 0})
    iom.set_position(eid, math3d.add(target_pos, math3d.mul(viewdir, -camera_mgr.get_editor_data(eid).dist_to_target)))
    camera_mgr.update_frustrum(eid)
end

function camera_mgr.set_target(eid, target)
    camera_mgr.get_editor_data(eid).target = target
    update_direction(eid)
end

function camera_mgr.set_dist_to_target(eid, dist)
    camera_mgr.get_editor_data(eid).dist_to_target = dist
    update_direction(eid)
end

local cameraidx = 0
local function gen_camera_name() cameraidx = cameraidx + 1 return "camera" .. cameraidx end

local recorderidx = 0
local function gen_camera_recorder_name() recorderidx = recorderidx + 1 return "recorder" .. recorderidx end

function camera_mgr.on_camera_ready(e)
    camera_mgr.update_frustrum(e)
    camera_mgr.show_frustum(e, false)
    camera_mgr.bind_recorder(e, icamera_recorder.start(gen_camera_recorder_name()))
end

function camera_mgr.create_camera()
    local main_frustum = icamera.get_frustum(camera_mgr.main_camera)
    local info = {
        eyepos = iom.get_position(camera_mgr.main_camera),
        viewdir = iom.get_direction(camera_mgr.main_camera),
        frustum = {n = default_near_clip, f = default_far_clip, aspect = main_frustum.aspect, fov = main_frustum.fov },
        updir = {0, 1, 0},
        name = gen_camera_name()
    }

    local viewmat = math3d.lookto(info.eyepos, info.viewdir, info.updir)
    local srt = math3d.ref(math3d.matrix(math3d.inverse(viewmat)))
    local template = {
        policy = {
            "ant.general|name",
            "ant.general|tag",
            "ant.camera|camera",
        },
        data = {
            reference = true,
            camera = {
                frustum = info.frustum,
                clip_range = info.clip_range,
                dof = info.dof,
                eyepos = info.eyepos,
                viewdir = info.viewdir,
                updir = info.updir,
            },
            name = info.name or "DEFAULT_CAMERA",
            scene = {
                srt = srt
            },
            tag = {"camera"},
        }
    }
    local runtime_tpl = utils.deep_copy(template)
    runtime_tpl.data.on_ready = camera_mgr.on_camera_ready
    local cam = ecs.create_entity(runtime_tpl)
    return cam, template
end

function camera_mgr.bind_recorder(eid, recorder)
    local editor_data = camera_mgr.get_editor_data(eid)
    editor_data.recorder = recorder
end

function camera_mgr.bind_main_camera()
    irq.set_camera("main_queue", camera_mgr.main_camera)
end

local function get_camera_recorder(cam_eid)
    local recorder = camera_mgr.get_editor_data(cam_eid).recorder
    if not recorder.camera_recorder then
        w:sync("camera_recorder:in", recorder)
    end
    return recorder.camera_recorder
end

function camera_mgr.set_frame(cam_eid, idx)
    local recorder = get_camera_recorder(cam_eid)
    local pos = recorder.frames[idx].position
    local rot = recorder.frames[idx].rotation
    iom.set_position(cam_eid, pos)
    iom.set_rotation(cam_eid, rot)
    camera_mgr.update_frustrum(cam_eid)
end

function camera_mgr.add_recorder_frame(eid, idx)
    local recorder = get_camera_recorder(eid)
    if #recorder.frames == 0 then
        icamera_recorder.add(camera_mgr.get_editor_data(eid).recorder, eid, 1)
    end
    icamera_recorder.add(camera_mgr.get_editor_data(eid).recorder, camera_mgr.main_camera, idx)
    local idx = #recorder.frames
    camera_mgr.set_frame(eid, idx)
end

function camera_mgr.delete_recorder_frame(eid, idx)
    icamera_recorder.remove(camera_mgr.get_editor_data(eid).recorder, idx)
    local frames = camera_mgr.get_recorder_frames(eid)
    if idx > #frames then
        idx = #frames
    end
    camera_mgr.set_frame(eid, idx)
end

function camera_mgr.clear_recorder_frame(eid, idx)
    icamera_recorder.clear(camera_mgr.get_editor_data(eid).recorder)
end

function camera_mgr.play_recorder(eid)
    icamera_recorder.play(camera_mgr.get_editor_data(eid).recorder, eid)
end

function camera_mgr.get_recorder_frames(eid)
    local recorder = get_camera_recorder(eid)
    return recorder.frames
end

local function do_remove_camera(cam)
    if not cam then return end
    if cam.recorder then
        w:remove(cam.recorder)
    end
    w:remove(cam.frustum_eid)
    w:remove(cam.far_boundary[1].line_eid)
    w:remove(cam.far_boundary[2].line_eid)
    w:remove(cam.far_boundary[3].line_eid)
    w:remove(cam.far_boundary[4].line_eid)
end

function camera_mgr.remove_camera(eid)
    if camera_mgr.second_camera == eid then
        camera_mgr.second_camera = nil
    end
    irq.set_visible(camera_mgr.second_view, false)
    local cam = camera_mgr.get_editor_data(eid)
    do_remove_camera(cam)
end

function camera_mgr.clear()
    if camera_mgr.second_camera then
        camera_mgr.second_camera = nil
    end
    irq.set_visible(camera_mgr.second_view, false)
    for e in w:select "camera:in" do
        if e.camera._editor then
            do_remove_camera(e)
        end
    end
end

return camera_mgr
