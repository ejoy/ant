local math3d  = require "math3d"
local bgfx = require "bgfx"
local world
local iom
local icamera
local imaterial
local ies
local geo_utils
local irq

local m = {
    FRUSTUM_LEFT    = 1,
    FRUSTUM_TOP     = 2,
    FRUSTUM_RIGHT   = 3,
    FRUSTUM_BOTTOM  = 4,
    camera_list     = {},
    second_view     = "second_view",
}

local normal_color      = {1, 0.3, 0.3, 1}
local normal_color_i    = 0xff5050ff
local highlight_color   = {1, 1, 0, 1}
local default_near_clip = 0.1
local default_far_clip  = 100
local default_fov       = 30
        
function m.set_second_camera(eid, show)
    -- local rc = world[eid]._rendercache
	-- rc.viewmat = icamera.calc_viewmat(eid)
    -- rc.projmat = icamera.calc_projmat(eid)
    -- rc.viewprojmat = icamera.calc_viewproj(eid)
    irq.set_camera(m.second_view, eid)
    m.second_camera = eid
    m.show_frustum(eid, show)
end

function m.reset_frustum_color(eid)
    local boundary = m.camera_list[eid].far_boundary
    imaterial.set_property(boundary[m.FRUSTUM_LEFT].line_eid, "u_color", normal_color)
    imaterial.set_property(boundary[m.FRUSTUM_TOP].line_eid, "u_color", normal_color)
    imaterial.set_property(boundary[m.FRUSTUM_RIGHT].line_eid, "u_color", normal_color)
    imaterial.set_property(boundary[m.FRUSTUM_BOTTOM].line_eid, "u_color", normal_color)
end

function m.highlight_frustum(eid, dir, highlight)
    local boundary = m.camera_list[eid].far_boundary
    boundary[dir].highlight = highlight
    if highlight then
        imaterial.set_property(boundary[dir].line_eid, "u_color", highlight_color)
    else
        imaterial.set_property(boundary[dir].line_eid, "u_color", normal_color)
    end
end

function m.set_frustum_fov(camera_ref, fov)
    icamera.set_frustum_fov(camera_ref, fov)
    m.update_frustrum(camera_ref)
end

function m.update_frustrum(cam_eid)
    --if not cam_eid or not world[cam_eid].camera then return end
    if not cam_eid then return end
    if not m.camera_list[cam_eid] then
        m.camera_list[cam_eid] = { camera_ref = cam_eid, target = -1, dist_to_target = 5 }
    end

    local frustum_points = math3d.frustum_points(icamera.calc_viewproj(cam_eid))
    local frustum_eid = m.camera_list[cam_eid].frustum_eid
    if not frustum_eid then
        local eid = geo_utils.create_dynamic_frustum(frustum_points, "frustum", normal_color_i)
        imaterial.set_property(eid, "u_color", normal_color)
        ies.set_state(eid, "auxgeom", true)
        m.camera_list[cam_eid].frustum_eid = eid
    else
        local rc = world[frustum_eid]._rendercache
        local vbdesc, ibdesc = rc.vb, rc.ib
        bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", geo_utils.get_frustum_vb(frustum_points, normal_color_i)));
    end
    
    -- local rc = world[cam_eid]._rendercache
    -- rc.viewmat = icamera.calc_viewmat(cam_eid)
    -- rc.projmat = icamera.calc_projmat(cam_eid)
    -- rc.viewprojmat = icamera.calc_viewproj(cam_eid)

    local old_boundary = m.camera_list[cam_eid].far_boundary
    local boundary = {}
    local function create_boundary(dir, p1, p2)
        local tp1 = math3d.totable(p1)
        local tp2 = math3d.totable(p2)
        local eid
        local old_highlight = false
        if not old_boundary then
            eid = geo_utils.create_dynamic_line(nil, tp1, tp2, "line")
            ies.set_state(eid, "auxgeom", true)
        else
            old_highlight = old_boundary[dir].highlight or false
            eid = old_boundary[dir].line_eid
            local vb = {
                tp1[1], tp1[2], tp1[3], normal_color_i,
                tp2[1], tp2[2], tp2[3], normal_color_i,
            }
            local rc = world[eid]._rendercache
            local vbdesc = rc.vb
            bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", vb));
        end
        imaterial.set_property(eid, "u_color", old_highlight and highlight_color or normal_color)
        boundary[dir] = {tp1, tp2, line_eid = eid, highlight = old_highlight}
    end
    create_boundary(m.FRUSTUM_LEFT, frustum_points[5], frustum_points[6])
    create_boundary(m.FRUSTUM_TOP, frustum_points[6], frustum_points[8])
    create_boundary(m.FRUSTUM_RIGHT, frustum_points[8], frustum_points[7])
    create_boundary(m.FRUSTUM_BOTTOM, frustum_points[7], frustum_points[5])

    m.camera_list[cam_eid].far_boundary = boundary
end

function m.show_frustum(eid, visible)
    -- if m.second_camera ~= eid then
    --     return
    -- end
    irq.set_visible(m.second_view, visible)
    if m.camera_list[eid] and m.camera_list[eid].frustum_eid then
        local state = "visible"
        ies.set_state(m.camera_list[eid].frustum_eid, state, visible)
        local boundary = m.camera_list[eid].far_boundary
        ies.set_state(boundary[1].line_eid, state, visible)
        ies.set_state(boundary[2].line_eid, state, visible)
        ies.set_state(boundary[3].line_eid, state, visible)
        ies.set_state(boundary[4].line_eid, state, visible)
    end
end

local function update_direction(eid)
    if m.camera_list[eid].target < 0 or not world[m.camera_list[eid].target] then return end
    local target_pos = iom.get_position(m.camera_list[eid].target)
    local eyepos = iom.get_position(eid)
    local viewdir = math3d.normalize(math3d.sub(target_pos, eyepos))
    iom.lookto(eid, eyepos, viewdir, {0, 1, 0})
    iom.set_position(eid, math3d.add(target_pos, math3d.mul(viewdir, -m.camera_list[eid].dist_to_target)))
    m.update_frustrum(eid)
end

function m.set_target(eid, target)
    m.camera_list[eid].target = target
    update_direction(eid)
end

function m.set_dist_to_target(eid, dist)
    m.camera_list[eid].dist_to_target = dist
    update_direction(eid)
end

local cameraidx = 0
local function gen_camera_name() cameraidx = cameraidx + 1 return "camera" .. cameraidx end


function m.ceate_camera()
    local main_frustum = icamera.get_frustum(m.main_camera)
    local info = {
        eyepos = {2, 2, -2, 1},
        viewdir = {-2, -1, 2, 0},
        frustum = {n = default_near_clip, f = default_far_clip, aspect = main_frustum.aspect, fov = main_frustum.fov },
        updir = {0, 1, 0},
        name = gen_camera_name()
    }

    local viewmat = math3d.lookto(info.eyepos, info.viewdir, info.updir)
    local srt = math3d.ref(math3d.matrix(math3d.inverse(viewmat)))
    local temp = {
        policy = {
            "ant.general|name",
            "ant.general|tag",
            "ant.camera|camera",
            "ant.scene|scene_object"
        },
        data = {
            reference = true,
            eid = world:register_entity(),
            camera = {
                frustum = info.frustum,
                clip_range = info.clip_range,
                dof = info.dof,
                srt = srt,
            },
            name = info.name or "DEFAULT_CAMERA",
            scene = {
                srt = srt,
                updir = info.updir and math3d.ref(math3d.vector(info.updir)) or nil,
            },
            tag = {"camera"}
        }
    }
    local new_camera = world:luaecs_create_entity(temp)
    
    new_camera.template = temp
    return new_camera

    -- world[new_camera].camera = true
    -- iom.set_position(new_camera, iom.get_position(m.main_camera))
    -- iom.set_rotation(new_camera, iom.get_rotation(m.main_camera))
    -- m.update_frustrum(new_camera)
    -- m.set_second_camera(new_camera, false)
    -- return new_camera--, camera_template.__class[1]
end

function m.bind_recorder(eid, recorder)
    m.camera_list[eid].recorder = recorder
end

function m.bind_main_camera()
    icamera.bind(m.main_camera, "main_queue")
end

function m.set_frame(cam_eid, idx)
    local pos = world[m.camera_list[cam_eid].recorder].frames[idx].position
    local rot = world[m.camera_list[cam_eid].recorder].frames[idx].rotation
    iom.set_position(cam_eid, pos)
    iom.set_rotation(cam_eid, rot)
    m.update_frustrum(cam_eid)
end

function m.add_recorder_frame(eid, idx)
    local recorder = m.camera_list[eid].recorder
    if not recorder then return end
    icamera_recorder.add(recorder, m.main_camera, idx)
    local idx = #world[recorder].frames
    world[recorder].frames[idx].nearclip = default_near_clip
    world[recorder].frames[idx].farclip = default_far_clip
    m.set_frame(eid, idx)
end

function m.delete_recorder_frame(eid, idx)
    if not m.camera_list[eid].recorder then return end
    icamera_recorder.remove(m.camera_list[eid].recorder, idx)
    local frames = m.get_recorder_frames(eid)
    if idx > #frames then
        idx = #frames
    end
    m.set_frame(eid, idx)
end

function m.clear_recorder_frame(eid, idx)
    if not m.camera_list[eid].recorder then return end
    icamera_recorder.clear(m.camera_list[eid].recorder)
end

function m.play_recorder(eid)
    if not m.camera_list[eid].recorder then return end
    icamera_recorder.play(m.camera_list[eid].recorder, eid)
end

function m.get_recorder_frames(eid)
    return {}
    -- local recorder_eid = m.camera_list[eid].recorder
    -- if not recorder_eid then return {} end
    -- return world[recorder_eid].frames
end

local function do_remove_camera(cam)
    if not cam then return end
    if cam.recorder then
        world:remove_entity(cam.recorder)
    end
    world:remove_entity(cam.frustum_eid)
    world:remove_entity(cam.far_boundary[1].line_eid)
    world:remove_entity(cam.far_boundary[2].line_eid)
    world:remove_entity(cam.far_boundary[3].line_eid)
    world:remove_entity(cam.far_boundary[4].line_eid)
end

function m.remove_camera(eid)
    m.set_second_camera(m.second_view_camera, false)
    local cam = m.camera_list[eid]
    do_remove_camera(cam)
    m.camera_list[eid] = nil
end

function m.clear()
    m.set_second_camera(m.second_view_camera, false)
    for k, v in pairs(m.camera_list) do
        do_remove_camera(v)
    end
    m.camera_list = {}
end

return function(ecs, w)
    world       = w
    iom         = ecs.import.interface "ant.objcontroller|obj_motion"
    icamera     = ecs.import.interface "ant.camera|camera"
    imaterial   = ecs.import.interface "ant.asset|imaterial"
    ies         = ecs.import.interface "ant.scene|ientity_state"
    icamera_recorder = ecs.import.interface "ant.camera|icamera_recorder"
    irq         = ecs.import.interface "ant.render|irenderqueue"
    geo_utils   = require "editor.geometry_utils"(world)
    return m
end
