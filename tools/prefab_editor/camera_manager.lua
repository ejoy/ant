local math3d  = require "math3d"
local bgfx = require "bgfx"
local world
local iom
local icamera
local imaterial
local computil
local ies
local m = {
    FRUSTUM_LEFT = 1,
    FRUSTUM_TOP = 2,
    FRUSTUM_RIGHT = 3,
    FRUSTUM_BOTTOM = 4,
    camera_list = {}
}

local normal_color = {1, 0.3, 0.3, 1}
local normal_color_i = 0xff5050ff
local highlight_color = {1, 1, 0, 1}
local DefaultNearClip = 0.1
local DefaultFarClip  = 100
local DefaultFOV      = 30
        
function m.set_second_camera(eid)
    local rc = world[eid]._rendercache
	rc.viewmat = icamera.calc_viewmat(eid)
    rc.projmat = icamera.calc_projmat(eid)
    rc.viewprojmat = icamera.calc_viewproj(eid)
    icamera.bind_queue(eid, m.second_view)
    m.second_camera = eid
    m.show_frustum(eid, true)
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

function m.set_frustum_fov(camera_eid, fov)
    icamera.set_frustum_fov(camera_eid, fov)
    m.update_frustrum(camera_eid)
end

local function create_dynamic_mesh(layout, vb, ib)
	local declmgr = import_package "ant.render".declmgr
	local decl = declmgr.get(layout)
	return {
		vb = {
			start = 0,
			num_vertices = #vb / decl.stride,
			{handle=bgfx.create_dynamic_vertex_buffer(bgfx.memory_buffer("fffd", vb), declmgr.get(layout).handle, "a")}
		},
		ib = {
			start = 0,
			num_indices = #ib,
			handle = bgfx.create_dynamic_index_buffer(bgfx.memory_buffer("w", ib), "a")
		}
	}
end

local function create_simple_render_entity(srt, material, name, mesh, state)
	return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform	= srt or {},
			material	= material,
			mesh		= mesh,
			state		= state or ies.create_state "visible",
			name		= name,-- or gen_test_name(),
			scene_entity= true,
		}
	}
end
local function get_frustum_vb(points, color)
    local vb = {}
    for i=1, #points do
        local p = math3d.totable(points[i])
        table.move(p, 1, 3, #vb+1, vb)
        vb[#vb+1] = color or 0xffffffff
    end
    return vb
end

local function create_dynamic_frustum(frustum_points, name, color)
    local vb = get_frustum_vb(frustum_points, color)
    local ib = {
        -- front
        0, 1, 2, 3,
        0, 2, 1, 3,
        -- back
        4, 5, 6, 7,
        4, 6, 5, 7,
        -- left
        0, 4, 1, 5,
        -- right
        2, 6, 3, 7,
    }
    local mesh = create_dynamic_mesh("p3|c40niu", vb, ib)
	return create_simple_render_entity(nil, "/pkg/ant.resources/materials/line.material", name, mesh)
end
local function create_dynamic_line(srt, p0, p1, name, color)
	local vb = {
		p0[1], p0[2], p0[3], color or 0xffffffff,
		p1[1], p1[2], p1[3], color or 0xffffffff,
	}
    local mesh = create_dynamic_mesh("p3|c40niu", vb, {0, 1} )
	return create_simple_render_entity(srt, "/pkg/ant.resources/materials/line_singlecolor.material", name, mesh)
end

function m.update_frustrum(cam_eid)
    if not cam_eid or not world[cam_eid].camera then return end

    if not m.camera_list[cam_eid] then
        m.camera_list[cam_eid] = { camera_eid = cam_eid, target = -1, dist_to_target = 5 }
    end

    local frustum_points = math3d.frustum_points(icamera.calc_viewproj(cam_eid))
    local frustum_eid = m.camera_list[cam_eid].frustum_eid
    if not frustum_eid then
        m.camera_list[cam_eid].frustum_eid = create_dynamic_frustum(frustum_points, "frustum", normal_color_i)
    else
        local rc = world[frustum_eid]._rendercache
        local vbdesc, ibdesc = rc.vb, rc.ib
        bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", get_frustum_vb(frustum_points, normal_color_i)));
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
            eid = create_dynamic_line(nil, tp1, tp2, "line")
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
    if not eid or not world[eid].camera then
        return
    end
    
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
    local new_camera, camera_template = icamera.create {
        eyepos = {2, 2, -2, 1},
        viewdir = {-2, -1, 2, 0},
        frustum = {n = DefaultNearClip, f = DefaultFarClip, aspect = main_frustum.aspect, fov = main_frustum.fov },
        updir = {0, 1, 0},
        name = gen_camera_name()
    }
    iom.set_position(new_camera, iom.get_position(m.main_camera))
    iom.set_rotation(new_camera, iom.get_rotation(m.main_camera))
    m.update_frustrum(new_camera)
    m.set_second_camera(new_camera)
    m.show_frustum(new_camera, false)
    return new_camera, camera_template.__class[1]
end

function m.bind_recorder(eid, recorder)
    m.camera_list[eid].recorder = recorder
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
    world[recorder].frames[idx].nearclip = DefaultNearClip
    world[recorder].frames[idx].farclip = DefaultFarClip
end

function m.delete_recorder_frame(eid, idx)
    if not m.camera_list[eid].recorder then return end
    icamera_recorder.remove(m.camera_list[eid].recorder, idx)
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
    local recorder_eid = m.camera_list[eid].recorder
    if not recorder_eid then return {} end
    return world[recorder_eid].frames
end

local function do_remove_camera(cam)
    world:remove_entity(cam.recorder)
    world:remove_entity(cam.frustum_eid)
    world:remove_entity(cam.far_boundary[1].line_eid)
    world:remove_entity(cam.far_boundary[2].line_eid)
    world:remove_entity(cam.far_boundary[3].line_eid)
    world:remove_entity(cam.far_boundary[4].line_eid)
end

function m.remove_camera(eid)
    m.set_second_camera(m.second_view_camera)
    local cam = m.camera_list[eid]
    do_remove_camera(cam)
    m.camera_list[eid] = nil
end

function m.clear()
    m.set_second_camera(m.second_view_camera)
    for k, v in pairs(m.camera_list) do
        do_remove_camera(v)
    end
    m.camera_list = {}
end

return function(w)
    world       = w
    iom         = world:interface "ant.objcontroller|obj_motion"
    icamera     = world:interface "ant.camera|camera"
    imaterial   = world:interface "ant.asset|imaterial"
    computil    = world:interface "ant.render|entity"
    ies         = world:interface "ant.scene|ientity_state"
    icamera_recorder = world:interface "ant.camera|icamera_recorder"
    return m
end
