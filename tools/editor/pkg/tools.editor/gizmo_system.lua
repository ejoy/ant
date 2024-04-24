local ecs = ...
local world = ecs.world
local w     = world.w
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util

local icamera	= ecs.require "ant.camera|camera"
local iom 		= ecs.require "ant.objcontroller|obj_motion"
local ientity 	= ecs.require "ant.entity|entity"
local ilight 	= ecs.require "ant.render|light.light"
local irq		= ecs.require "ant.render|renderqueue"
local imaterial = ecs.require "ant.render|material"
local imodifier = ecs.require "ant.modifier|modifier"
local iviewport = ecs.require "ant.render|viewport.state"
local irender	= ecs.require "ant.render|render"

local cmd_queue = ecs.require "gizmo.command_queue"
local utils 	= ecs.require "mathutils"
local camera_mgr= ecs.require "camera.camera_manager"
local gizmo 	= ecs.require "gizmo.gizmo"
local light_gizmo = ecs.require "gizmo.light"
local navigizmo = ecs.require "gizmo.navi_gizmo"
local rectselect = ecs.require "gizmo.rect_select"
local hierarchy = ecs.require "hierarchy_edit"
local gizmo_const= require "gizmo.const"

local math3d = require "math3d"

local gizmo_sys = ecs.system "gizmo_system"

local move_axis
local rotate_axis
local uniform_scale = false
local local_space = false

function gizmo_sys:init()
	navigizmo:init()
end

function gizmo_sys:entity_init()
	navigizmo:entity_init()
end

function gizmo:update()
	self:set_position()
	self:set_rotation()
	self:update_scale()
	self:updata_uniform_scale()
	self:update_axis_plane()
end

function gizmo:set_target(eids, group_center)
	self.group_eids = nil
	local target = eids
	if eids then
		target = #eids > 1 and self.group_root or eids[1]
		if self.group_root == target then
			self.group_eids = eids
			local e <close> = world:entity(target)
			iom.set_position(e, group_center)
		end
	end
	if self.target_eid == target then
		if self.group_root == target then
			world:pub {"UpdateAABB", self.group_eids}
		end
		return
	end
	local old_target = self.target_eid
	self.target_eid = target
	if target then
		local e <close> = world:entity(target, "scene?in")
		if e.scene then
			local _, r, t = math3d.srt(iom.worldmat(e))
			self:set_rotation(r, true)
			self:set_position(t, true)
		end
	end
	gizmo:show_by_state(target ~= nil)
	world:pub {"Gizmo","ontarget", old_target, target}
end

function gizmo:updata_uniform_scale()
	if not self.rw.eid or not self.rw.eid[1] then return end
	local ce <close> = world:entity(irq.main_camera())
	self.rw.dir = math3d.totable(iom.get_direction(ce))
	local r = iom.get_rotation(ce)
	local e1 <close> = world:entity(self.rw.eid[1])
	local e3 <close> = world:entity(self.rw.eid[3])
	local e4 <close> = world:entity(self.rw.eid[4])
	iom.set_rotation(e1, r)
	iom.set_rotation(e3, r)
	iom.set_rotation(e4, r)
end
local function can_edit_srt(eid)
	if not eid then return end
	local e <close> = world:entity(eid, "scene?in")
	if eid and not hierarchy:is_locked(eid) and e.scene then
		return true
	end
end
function gizmo:set_scale(inscale)
	if not can_edit_srt(self.target_eid) then
		return
	end
	local e <close> = world:entity(self.target_eid)
	iom.set_scale(e, inscale)
	local info = hierarchy:get_node_info(self.target_eid)
	info.template.data.scene.s = inscale
	world:pub{"Patch", "", self.target_eid, "/data/scene/s", inscale}
	world:pub {"UpdateAABB", {self.target_eid}}
end

function gizmo:set_position(worldpos, gizmoonly)
	if not can_edit_srt(self.target_eid) then
		return
	end
	local newpos = worldpos
	local target <close> = world:entity(self.target_eid)
	if worldpos then
		if not gizmoonly then
			local pid = hierarchy:get_parent(gizmo.target_eid)
			local parent_worldmat
			if pid then
				local pe <close> = world:entity(pid)
				parent_worldmat = iom.worldmat(pe)
			end
			local localpos
			if not parent_worldmat then
				localpos = worldpos
			else
				localpos = math3d.transform(math3d.inverse(parent_worldmat), math3d.vector(worldpos), 1)
			end
			iom.set_position(target, localpos)
			local info = hierarchy:get_node_info(self.target_eid)
			local tp = (type(localpos) == "table") and localpos or math3d.tovalue(localpos)
			local t = {tp[1], tp[2], tp[3]}
			info.template.data.scene.t = t
			world:pub{"Patch", "", self.target_eid, "/data/scene/t", t}
		end
	else
		local wm = iom.worldmat(target)
		if wm ~= mc.NULL then
			local _, _, t = math3d.srt(wm)
			newpos = t
		else
			newpos = mc.ZERO
		end
	end
	local root <close> = world:entity(self.root_eid);
	local uniform_rot_root <close> = world:entity(self.uniform_rot_root_eid)
	iom.set_position(root, newpos)
	iom.set_position(uniform_rot_root, newpos)
end

function gizmo:set_rotation(inrot, gizmoonly)
	if not can_edit_srt(self.target_eid) then
		return
	end
	local target <close> = world:entity(self.target_eid)
	local newrot = inrot
	if inrot then
		if not gizmoonly then
			iom.set_rotation(target, inrot)
			local info = hierarchy:get_node_info(self.target_eid)
			local tv = math3d.tovalue(inrot)
			local r = {tv[1], tv[2], tv[3], tv[4]}
			info.template.data.scene.r = r
			world:pub{"Patch", "", self.target_eid, "/data/scene/r", r}
		end
	else
		newrot = iom.get_rotation(target)
	end
	local re <close> = world:entity(self.root_eid)
	if self.mode == gizmo_const.SCALE then
		iom.set_rotation(re, newrot)
	elseif self.mode == gizmo_const.MOVE or self.mode == gizmo_const.ROTATE then
		iom.set_rotation(re, local_space and newrot or mc.IDENTITY_QUAT)
	end
	world:pub {"UpdateAABB", {self.target_eid}}
end

function gizmo:on_mode(mode)
	self:show_by_state(false)
	self.mode = mode
	self:show_by_state(true)
	self:set_rotation()
	self:update_scale()
end

local function create_arrow_widget(axis_root, axis_str)
	local cone_t
	local cylindere_t
	local local_rotator
	local color
	local axis_len = gizmo_const.AXIS_LEN
	if axis_str == "x" then
		cone_t = {axis_len, 0, 0}
		local_rotator = {0, 0, math.rad(-90)}
		cylindere_t = {0.5 * axis_len, 0, 0}
		color = gizmo_const.COLOR.X
	elseif axis_str == "y" then
		cone_t = {0, axis_len, 0}
		local_rotator = mc.IDENTITY_QUAT
		cylindere_t = {0, 0.5 * axis_len, 0}
		color = gizmo_const.COLOR.Y
	elseif axis_str == "z" then
		cone_t = {0, 0, axis_len}
		local_rotator = {math.rad(90), 0, 0}
		cylindere_t = {0, 0, 0.5 * axis_len}
		color = gizmo_const.COLOR.Z
	end

	local cylindereid = world:create_entity{
		policy = {
			"ant.render|render",
		},
		data = {
			visible = false,
			scene = {
				s = {0.004, 0.1, 0.004},
				r = local_rotator,
				t = cylindere_t,
				parent = axis_root
			},
			material = "/pkg/ant.resources/materials/singlecolor_nocull.material",
			render_layer = "translucent",
			mesh = '/pkg/ant.resources.binary/meshes/base/cylinder.glb/meshes/Cylinder_P1.meshbin',
			on_ready = function (e)
				imaterial.set_property(e, "u_color", math3d.vector(color))
			end
		},
		tag = {
			"arrow.cylinder" .. axis_str,
		}
	}
	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
		},
		data = {
			visible = false,
			scene = {s = {0.02, 0.03, 0.02, 0}, r = local_rotator, t = cone_t, parent = axis_root},
			material = "/pkg/ant.resources/materials/singlecolor_nocull.material",
			render_layer = "translucent",
			mesh = '/pkg/ant.resources.binary/meshes/base/cone.glb/meshes/Cone_P1.meshbin',
			on_ready = function (e)
				imaterial.set_property(e, "u_color", math3d.vector(color))
			end
		},
		tag = {
			"arrow.cone" .. axis_str,
		}
	}
	local axis
	if axis_str == "x" then
		axis = gizmo.tx
	elseif axis_str == "y" then
		axis = gizmo.ty
	elseif axis_str == "z" then
		axis = gizmo.tz
	end
	axis.eid = {cylindereid, coneeid}
end

local function mouse_hit_plane(screen_pos, plane_info)
	local c <close> = world:entity(irq.main_camera(), "camera:in")
	return utils.ray_hit_plane(iom.ray(c.camera.viewprojmat, screen_pos), plane_info)
end

function gizmo:update_scale()
	local ce <close> = world:entity(irq.main_camera())
	local viewdir = iom.get_direction(ce)
	local eyepos = iom.get_position(ce)
	local re <close> = world:entity(self.root_eid)
	local cam_to_origin = math3d.sub(iom.get_position(re), eyepos)
	local project_dist = math3d.dot(math3d.normalize(viewdir), cam_to_origin)
	gizmo.scale = project_dist * 0.6
	if self.root_eid then
		iom.set_scale(re, gizmo.scale)
	end
	if self.uniform_rot_root_eid then
		local ue <close> = world:entity(self.uniform_rot_root_eid)
		iom.set_scale(ue, gizmo.scale)
	end
	if light_gizmo.directional.root then
		local le <close> = world:entity(light_gizmo.directional.root)
		iom.set_scale(le, gizmo.scale * 0.2)
	end

	local get_mat = function(orign, cam_to_origin, zaxis)
		local yaxis = math3d.normalize(math3d.cross(cam_to_origin, zaxis))
		local xaxis = math3d.cross(yaxis, zaxis)
		return math3d.matrix(
			math3d.index(xaxis,1), math3d.index(xaxis,2), math3d.index(xaxis,3), 0,
			math3d.index(yaxis,1), math3d.index(yaxis,2), math3d.index(yaxis,3), 0,
			math3d.index(zaxis,1), math3d.index(zaxis,2), math3d.index(zaxis,3), 0,
			math3d.index(orign,1), math3d.index(orign,2), math3d.index(orign,3), 1)
	end

	local origin = iom.get_position(re)
	cam_to_origin = math3d.normalize(cam_to_origin)
	local rxe <close> = world:entity(gizmo.rx.eid[1])
	iom.set_srt_matrix(rxe, math3d.mul(get_mat(origin, cam_to_origin, mc.XAXIS), math3d.matrix{s = gizmo.scale}))
	local rye <close> = world:entity(gizmo.ry.eid[1])
	iom.set_srt_matrix(rye, math3d.mul(get_mat(origin, cam_to_origin, mc.YAXIS), math3d.matrix{s = gizmo.scale, r = math3d.quaternion{0, 0, math.rad(90)}}))
	local rze <close> = world:entity(gizmo.rz.eid[1])
	iom.set_srt_matrix(rze, math3d.mul(get_mat(origin, cam_to_origin, mc.ZAXIS), math3d.matrix{s = gizmo.scale}))
end

local ipl = ecs.require "ant.polyline|polyline"
local geopkg = import_package "ant.geometry"
local geolib = geopkg.geometry
local LINEWIDTH = 3
function gizmo_sys:post_init()
	gizmo.group_root = world:create_entity {
		policy = {
			"ant.scene|scene_object",
		},
		data = {
			scene = {},
		},
		tag = {
			"multi select root"
		}
	}
	local axis_root = world:create_entity {
		policy = {
			"ant.scene|scene_object",
		},
		data = {
			scene = {},
		},
		tag = {
			"axis root"
		}
	}
	gizmo.root_eid = axis_root
	local rot_circle_root = world:create_entity {
		policy = {
			"ant.scene|scene_object",
		},
		data = {
			scene = {parent = axis_root},
		},
		tag = {
			"rot root"
		}
	}

	gizmo.rot_circle_root_eid = rot_circle_root

	local uniform_rot_root = world:create_entity {
		policy = {
			"ant.scene|scene_object",
		},
		data = {
			scene = {},
		},
		tag = {
			"rot root"
		}
	}
	gizmo.uniform_rot_root_eid = uniform_rot_root

	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	
	local plane_xy_eid = ientity.create_prim_plane_entity(
		"/pkg/ant.resources/materials/singlecolor_nocull.material",
		{
			t = {gizmo_const.MOVE_PLANE_OFFSET, gizmo_const.MOVE_PLANE_OFFSET, 0, 1},
			s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0},
			r = math3d.quaternion{math.rad(90), 0, 0},
			parent = axis_root
		},
		gizmo_const.COLOR.Z_ALPHA,
		true, "translucent")
	gizmo.txy.eid = {plane_xy_eid, plane_xy_eid}

	local plane_yz_eid = ientity.create_prim_plane_entity(
		"/pkg/ant.resources/materials/singlecolor_nocull.material",
		{
			t = {0, gizmo_const.MOVE_PLANE_OFFSET, gizmo_const.MOVE_PLANE_OFFSET, 1},
			s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0},
			r = math3d.quaternion{0, 0, math.rad(90)},
			parent = axis_root
		},
		gizmo_const.COLOR.X_ALPHA,
		true, "translucent")
	gizmo.tyz.eid = {plane_yz_eid, plane_yz_eid}

	local plane_zx_eid = ientity.create_prim_plane_entity(
		"/pkg/ant.resources/materials/singlecolor_nocull.material",
		{
			t = {gizmo_const.MOVE_PLANE_OFFSET, 0, gizmo_const.MOVE_PLANE_OFFSET, 1},
			s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0},
			parent = axis_root
		},
		gizmo_const.COLOR.Y_ALPHA,
		true, "translucent")
	gizmo.tzx.eid = {plane_zx_eid, plane_zx_eid}
	gizmo:reset_move_axis_color()

	-- roate axis
	local function get_points(vertices)
		local points = {}
		for i = 1, #vertices, 3 do
			points[#points + 1] = {vertices[i], vertices[i+1], vertices[i+2]}
		end
		return points
	end
	local function create_polyline(points, color, srt)
		return ipl.add_strip_lines(points, LINEWIDTH, color, "/pkg/tools.editor/resource/materials/polyline.material", false, srt, "translucent", true)
	end
	local vertices, _ = geolib.circle(gizmo_const.UNIFORM_ROT_AXIS_LEN, gizmo_const.ROTATE_SLICES)
	local uniform_rot_eid = create_polyline(get_points(vertices), gizmo_const.COLOR.GRAY, {parent = uniform_rot_root})
	local function create_rotate_fan(radius, scene)
		local mesh_eid = ientity.create_circle_mesh_entity(radius, gizmo_const.ROTATE_SLICES, "/pkg/ant.resources/materials/singlecolor_nocull.material", scene, gizmo_const.COLOR.Z_ALPHA, true, "translucent")
		return mesh_eid
	end
	-- counterclockwise mesh
	local rot_ccw_mesh_eid = create_rotate_fan(gizmo_const.UNIFORM_ROT_AXIS_LEN, {parent = uniform_rot_root})
	-- clockwise mesh
	local rot_cw_mesh_eid = create_rotate_fan(gizmo_const.UNIFORM_ROT_AXIS_LEN, {parent = uniform_rot_root})
	gizmo.rw.eid = {uniform_rot_eid, uniform_rot_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}

	local function create_rotate_axis(axis, line_end, scene)
		local line_eid = create_polyline({{0, 0, 0},line_end}, axis.color, {parent = rot_circle_root})
		local arc = (axis == gizmo.ry) and {start_deg = math.rad(180), end_deg = math.rad(360) } or {start_deg = math.rad(-90), end_deg = math.rad(90) }
		vertices, _ = geolib.circle(gizmo_const.AXIS_LEN, gizmo_const.ROTATE_SLICES, arc)
		local rot_eid = create_polyline(get_points(vertices), axis.color, {})
		local ccw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, {parent = rot_circle_root, s = scene.s, r = scene.r, t = scene.t})
		local cw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, {parent = rot_circle_root, s = scene.s, r = scene.r, t = scene.t})
		axis.eid = {rot_eid, line_eid, ccw_mesh_eid, cw_mesh_eid}
	end
	create_rotate_axis(gizmo.rx, {gizmo_const.AXIS_LEN * 0.5, 0, 0}, {r = math3d.quaternion{0, math.rad(90), 0}})
	create_rotate_axis(gizmo.ry, {0, gizmo_const.AXIS_LEN * 0.5, 0}, {r = math3d.quaternion{math.rad(90), 0, 0}})
	create_rotate_axis(gizmo.rz, {0, 0, gizmo_const.AXIS_LEN * 0.5}, {})
	-- scale axis
	local function create_scale_cube(axis_name, scene, color)
		local eid = world:create_entity {
			policy = {
				"ant.render|render",
				"ant.scene|scene_object",
			},
			data = {
				visible = false,
				scene = scene or {},
				material = "/pkg/ant.resources/materials/singlecolor_nocull.material",
				mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb/meshes/Cube_P1.meshbin",
				render_layer = "translucent",
				on_ready = function (e)
					imaterial.set_property(e, "u_color", math3d.vector(color))
				end
			},
			tag = {
				"scale_cube" .. axis_name
			}
		}
		return eid
	end

	-- scale axis cube
	local cube_eid = create_scale_cube("uniform scale", {s = gizmo_const.AXIS_CUBE_SCALE, parent = axis_root}, gizmo_const.COLOR.GRAY)
	gizmo.uniform_scale_eid = cube_eid
	local function create_scale_axis(axis, axis_end)
		local cube_eid = create_scale_cube("scale axis", {t = axis_end, s = gizmo_const.AXIS_CUBE_SCALE, parent = axis_root}, axis.color)
		local line_eid = create_polyline({{0, 0, 0}, axis_end}, axis.color, {parent = axis_root})
		axis.eid = {cube_eid, line_eid}
	end
	create_scale_axis(gizmo.sx, {gizmo_const.AXIS_LEN, 0, 0})
	create_scale_axis(gizmo.sy, {0, gizmo_const.AXIS_LEN, 0})
	create_scale_axis(gizmo.sz, {0, 0, gizmo_const.AXIS_LEN})
end
local event_main_camera_changed = world:sub{"main_queue", "camera_changed"}

function gizmo_sys:init_world()
	navigizmo:create_navi_axis()
	rectselect:init()
end
function gizmo_sys:entity_ready()
	for _ in event_main_camera_changed:each() do
		gizmo:update_scale()
		gizmo:show_by_state(false)
		gizmo:hide_rotate_fan()
	end
end

local function gizmo_dir_to_world(localDir)
	if local_space or (gizmo.mode == gizmo_const.SCALE) then
		local re <close> = world:entity(gizmo.root_eid)
		return math3d.totable(math3d.transform(iom.get_rotation(re), localDir, 0))
	else
		return localDir
	end
end

function gizmo:update_axis_plane()
	if self.mode ~= gizmo_const.MOVE or not self.target_eid then
		return
	end
	local function do_update_axis_plane(axis_plane, invmat, gizmo_pos, eye_pos)
		local axis_dir = axis_plane.dir
		local world_dir = math3d.vector(gizmo_dir_to_world(axis_dir))
		local plane = {n = world_dir, d = -math3d.dot(world_dir, gizmo_pos)}
		local project = math3d.sub(eye_pos, math3d.mul(plane.n, math3d.dot(plane.n, eye_pos) + plane.d))
		local point = math3d.transform(invmat, project, 1)
		local e <close> = world:entity(axis_plane.eid[1])
		local x, y, z = math3d.index(point, 1), math3d.index(point, 2), math3d.index(point, 3)
		if axis_dir == gizmo_const.DIR_Z then
			iom.set_position(e, {(x > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (y > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0})
			axis_plane.area = (x > 0) and ((y > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((y > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))
		elseif axis_dir == gizmo_const.DIR_Y then
			iom.set_position(e, {(x > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0, (z > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
			axis_plane.area = (x > 0) and ((z > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((z > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))
		elseif axis_dir == gizmo_const.DIR_X then
			iom.set_position(e, {0, (y > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (z > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
			axis_plane.area = z > 0 and ((y > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((y > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))
		end
	end
	local re <close> = world:entity(gizmo.root_eid)
	local invmat = math3d.inverse(iom.worldmat(re))
	local gizmo_pos = iom.get_position(re)
	local ce <close> = world:entity(irq.main_camera())
	local eye_pos = iom.get_position(ce)
	do_update_axis_plane(self.txy, invmat, gizmo_pos, eye_pos)
	do_update_axis_plane(self.tzx, invmat, gizmo_pos, eye_pos)
	do_update_axis_plane(self.tyz, invmat, gizmo_pos, eye_pos)
end

local event_pickup = world:sub {"pickup"}

local function select_axis_plane(x, y)
	if gizmo.mode ~= gizmo_const.MOVE then
		return
	end
	local function hit_test_axis_plane(axis_plane, plane_hit_radius)
		local e <close> = world:entity(gizmo.root_eid)
		local gizmo_pos = iom.get_position(e)
		local hit_pos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(axis_plane.dir), pos = math3d.totable(gizmo_pos)})
		if not hit_pos then
			return
		end
		local to_gizmo = math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(e)), math3d.sub(hit_pos, gizmo_pos), 0))
		local idx0, idx1
		if axis_plane == gizmo.tyz then
			idx0, idx1 = 2, 3
		elseif axis_plane == gizmo.txy then
			idx0, idx1 = 2, 1
		elseif axis_plane == gizmo.tzx then
			idx0, idx1 = 3, 1
		end
		if axis_plane.area == gizmo_const.RIGHT_BOTTOM then
			to_gizmo[idx0] = -to_gizmo[idx0]
		elseif axis_plane.area == gizmo_const.LEFT_BOTTOM then
			to_gizmo[idx0] = -to_gizmo[idx0]
			to_gizmo[idx1] = -to_gizmo[idx1]
		elseif axis_plane.area == gizmo_const.LEFT_TOP then
			to_gizmo[idx1] = -to_gizmo[idx1]
		end
		if to_gizmo[idx0] > 0 and to_gizmo[idx0] < plane_hit_radius and to_gizmo[idx1] > 0 and to_gizmo[idx1] < plane_hit_radius then
			return true
		end
	end
	local plane_hit_radius = gizmo.scale * gizmo_const.MOVE_PLANE_HIT_RADIUS * 0.5
	if hit_test_axis_plane(gizmo.tyz, plane_hit_radius) then
		return gizmo.tyz
	end
	if hit_test_axis_plane(gizmo.txy, plane_hit_radius) then
		return gizmo.txy
	end
	if hit_test_axis_plane(gizmo.tzx, plane_hit_radius) then
		return gizmo.tzx
	end
end

local function world_to_screen(wpos)
	local ce <close> = world:entity(irq.main_camera())
	local vpmat = icamera.calc_viewproj(ce)
	local mqvr = irq.view_rect "main_queue"
	-- local ndcPos = math3d.transformH(vpmat, wpos, 1)
	-- return math3d.vector{(math3d.index(ndcPos, 1) * 0.5 + 0.5) * mqvr.w, (1.0 - (math3d.index(ndcPos, 2) * 0.5 + 0.5)) * mqvr.h, 0}
	return mu.world_to_screen(vpmat, mqvr, wpos)
end

local function set_color(eid, color)
	local e <close> = world:entity(eid)
	imaterial.set_property(e, "u_color", color)
end

local function select_axis(x, y)
	if not gizmo.target_eid then
		return
	end
	assert(x and y)
	local mqvr = irq.view_rect "main_queue"
	if not mu.pt2d_in_rect(x, y, mqvr) then
		return
	end

	if gizmo.mode == gizmo_const.SCALE then
		gizmo:reset_scale_axis_color()
	elseif gizmo.mode == gizmo_const.MOVE then
		gizmo:reset_move_axis_color()
	end
	-- by plane
	local axis_plane = select_axis_plane(x, y)
	if axis_plane then
		return axis_plane
	end
	local re <close> = world:entity(gizmo.root_eid)
	local gizmo_obj_pos = iom.get_position(re)
	local start = world_to_screen(gizmo_obj_pos)
	uniform_scale = false
	-- uniform scale
	local hp = math3d.vector(x, y, 0)
	if gizmo.mode == gizmo_const.SCALE then
		local radius = math3d.length(math3d.sub(hp, start))
		if radius < gizmo_const.MOVE_HIT_RADIUS_PIXEL then
			uniform_scale = true
			local hlcolor = gizmo_const.COLOR.HIGHLIGHT
			set_color(gizmo.uniform_scale_eid, hlcolor)
			set_color(gizmo.sx.eid[1], hlcolor)
			set_color(gizmo.sx.eid[2], hlcolor)
			set_color(gizmo.sy.eid[1], hlcolor)
			set_color(gizmo.sy.eid[2], hlcolor)
			set_color(gizmo.sz.eid[1], hlcolor)
			set_color(gizmo.sz.eid[2], hlcolor)
			return
		end
	end
	-- by axis
	local line_len = gizmo_const.AXIS_LEN * gizmo.scale

	local axes = {
		x = {line_len, 0, 0},
		y = {0, line_len, 0},
		z = {0, 0, line_len},
	}

	for k, delta_dir in pairs(axes) do
		local end_ptWS = math3d.add(gizmo_obj_pos, math3d.vector(gizmo_dir_to_world(delta_dir)))
		local end_pt = world_to_screen(end_ptWS)
		local dis, intersectpt = mu.pt2d_line_intersect(start, end_pt, hp)
		if math.abs(dis) < gizmo_const.MOVE_HIT_RADIUS_PIXEL and mu.pt2d_in_line(start, end_pt, intersectpt) then
			local tn = gizmo.mode == gizmo_const.SCALE and "s" or "t"
			return gizmo[tn .. k]
		end
	end
end

local function select_rotate_axis(x, y)
	if not gizmo.target_eid then
		return
	end

	assert(x and y)
	local mqvr = irq.view_rect "main_queue"
	if not mu.pt2d_in_rect(x, y, mqvr) then
		return
	end

	gizmo:reset_rotate_axis_color()

	local function hit_test_rotate_axis(axis)
		local re <close> = world:entity(gizmo.root_eid)
		local gizmo_pos = iom.get_position(re)
		local axis_dir = (axis ~= gizmo.rw) and gizmo_dir_to_world(axis.dir) or axis.dir
		local hit_pos = mouse_hit_plane({x, y}, {dir = axis_dir, pos = math3d.totable(gizmo_pos)})
		if not hit_pos then
			return
		end
		local dist = math3d.length(math3d.sub(gizmo_pos, hit_pos))
		local adjust_axis_len = (axis == gizmo.rw) and gizmo_const.UNIFORM_ROT_AXIS_LEN or gizmo_const.AXIS_LEN
		local a1 <close> = world:entity(axis.eid[1])
		local a2 <close> = world:entity(axis.eid[2])
		if math.abs(dist - gizmo.scale * adjust_axis_len) < gizmo_const.ROTATE_HIT_RADIUS * gizmo.scale then
			local hlcolor = gizmo_const.COLOR.HIGHLIGHT
			set_color(axis.eid[1], hlcolor)
			set_color(axis.eid[2], hlcolor)
			return hit_pos
		else
			local cc = math3d.vector(axis.color)
			set_color(axis.eid[1], cc)
			set_color(axis.eid[2], cc)
		end
	end

	local hit = hit_test_rotate_axis(gizmo.rx)
	if hit then
		return gizmo.rx, hit
	end

	hit = hit_test_rotate_axis(gizmo.ry)
	if hit then
		return gizmo.ry, hit
	end

	hit = hit_test_rotate_axis(gizmo.rz)
	if hit then
		return gizmo.rz, hit
	end

	hit = hit_test_rotate_axis(gizmo.rw)
	if hit then
		return gizmo.rw, hit
	end
end

local last_mouse_pos
local last_gizmo_pos
local last_gizmo_scale
local init_offset 		= math3d.ref()
local last_rotate_axis 	= math3d.ref()
local last_rotate 		= math3d.ref()
local last_hit 			= math3d.ref()
local gizmo_seleted = false
local is_tran_dirty = false

local function move_gizmo(x, y)
	if not gizmo.target_eid or not x or not y then
		return
	end
	local world_pos = last_gizmo_pos
	if move_axis == gizmo.txy or move_axis == gizmo.tyz or move_axis == gizmo.tzx then
		local re <close> = world:entity(gizmo.root_eid)
		local gizmo_pos = math3d.totable(iom.get_position(re))
		local downpos = mouse_hit_plane(last_mouse_pos, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmo_pos})
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmo_pos})
		if downpos and curpos then
			world_pos = math3d.add(last_gizmo_pos, math3d.sub(curpos, downpos))
		end
	else
		local ce <close> = world:entity(irq.main_camera(), "camera:in")
		local new_offset = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
		world_pos = math3d.add(last_gizmo_pos, math3d.sub(new_offset, init_offset))
	end
	gizmo:set_position(world_pos)
	gizmo:update_scale()
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end

local light_gizmo = ecs.require "gizmo.light"
local light_gizmo_mode = 0
-- light_gizmo_mode:
-- 1 point light  x axis
-- 2 point light x axis
-- 3 point light x axis
-- 4 spot light range
-- 5 spot light radian
local click_dir_point_light
local click_dir_spot_light
local last_spot_range
local function move_light_gizmo(x, y)
	if light_gizmo_mode == 0 then return end
	local circle_centre
	local le <close> = world:entity(light_gizmo.current_light, "light:in")
	if light_gizmo_mode == 4 or light_gizmo_mode == 5 then
		local mat = iom.worldmat(le)
		circle_centre = math3d.transform(mat, math3d.vector{0, 0, ilight.range(le)}, 1)
	end
	local lightPos = iom.get_position(le)
	local info = hierarchy:get_node_info(light_gizmo.current_light)
	if light_gizmo_mode == 4 then
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(click_dir_spot_light), pos = math3d.totable(circle_centre)})
		local value = 2.0 * math.atan(math3d.length(math3d.sub(curpos, circle_centre)), ilight.range(le))
		ilight.set_outter_radian(le, value)
		info.template.data.light.outter_radian = value
		world:pub { "Patch", "", light_gizmo.current_light, "/data/light/outter_radian", value }
	elseif light_gizmo_mode == 5 then
		local move_dir = math3d.sub(circle_centre, lightPos)
		local ce <close> = world:entity(irq.main_camera(), "camera:in")
		local new_offset = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_dir), last_gizmo_pos)
		local offset = math3d.length(math3d.sub(new_offset, init_offset))
		if math3d.length(math3d.sub(new_offset, lightPos)) < math3d.length(math3d.sub(init_offset, lightPos)) then
			offset = -offset
		end
		local value = last_spot_range + offset
		ilight.set_range(le, value)
		info.template.data.light.range = value
		world:pub { "Patch", "", light_gizmo.current_light, "/data/light/range", value }
	else
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(click_dir_point_light), pos = math3d.totable(lightPos)})
		local value = math3d.length(math3d.sub(curpos, lightPos))
		ilight.set_range(le, value)
    	info.template.data.light.range = value
		world:pub { "Patch", "", light_gizmo.current_light, "/data/light/range", value }
	end
	light_gizmo.update_gizmo()
	light_gizmo.highlight(true)
	world:pub {"Gizmo", "update"}
end

local function show_rotate_fan(rot_axis, start_angle, delta_angle)
	local e3_start, e3_num
	local step_angle = gizmo_const.ROTATE_SLICES / 360
	local e4 <close> = world:entity(rot_axis.eid[4], "render_object:update")
	local ro4 = e4.render_object
	ro4.ib_start, ro4.ib_num = 0, 0
	if delta_angle > 0 then
		e3_start = math.floor(start_angle * step_angle) * 3
		local total_angle = start_angle + delta_angle
		if total_angle > 360 then
			local extra_angle = (total_angle - 360)
			delta_angle = delta_angle - extra_angle
			if extra_angle > start_angle then
				extra_angle = start_angle
			end
			local e4num = math.floor(extra_angle * step_angle) * 3
			ro4.ib_num = e4num
			irender.set_visible(e4, e4num > 0)
		end
		e3_num = math.floor(delta_angle * step_angle + 1) * 3
	else
		local extra_angle = start_angle + delta_angle
		if extra_angle < 0 then
			e3_start = 0
			e3_num = math.floor(start_angle * step_angle) * 3
			if extra_angle < start_angle - 360 then
				extra_angle = start_angle - 360
			end
			local e4start, e4num = math.floor((360 + extra_angle) * step_angle) * 3, math.floor(-extra_angle * step_angle + 1) * 3
			if e4start < 0 then
				e4start = 0
			end
			ro4.ib_start, ro4.ib_num = e4start, e4num
			irender.set_visible(e4, e4num > 0)
		else
			e3_num = math.floor(-delta_angle * step_angle + 1) * 3
			e3_start = math.floor(start_angle * step_angle) * 3 - e3_num
			if e3_start < 0 then
				e3_num = e3_num + e3_start
				e3_start = 0
			end
		end
	end
	local e3 <close> = world:entity(rot_axis.eid[3], "render_object:update")
	local ro3 = e3.render_object
	ro3.ib_start, ro3.ib_num = e3_start, e3_num

	irender.set_visible(e3, e3_num > 0)
end

local init_screen_offest = math3d.ref()
local local_angle = 0
local revolutions = 0
local function rotate_gizmo(x, y)
	if not x or not y then
		return
	end
	local axis_dir = (rotate_axis ~= gizmo.rw) and gizmo_dir_to_world(rotate_axis.dir) or rotate_axis.dir
	local re <close> = world:entity(gizmo.root_eid)
	local gizmo_pos = iom.get_position(re)
	local hit_pos = mouse_hit_plane({x, y}, {dir = axis_dir, pos = math3d.totable(gizmo_pos)})
	if not hit_pos then
		return
	end
	local init_point = world_to_screen(gizmo_pos)
	local screen_pos = math3d.vector{x - math3d.index(init_point, 1), y - math3d.index(init_point, 2), 0}
	local ax = math3d.dot(screen_pos, init_screen_offest)
	local ay = math3d.dot(screen_pos, math3d.vector{-1.0 * math3d.index(init_screen_offest, 2), math3d.index(init_screen_offest, 1), 0})
	local prev_local_angle = local_angle
	local_angle = math.atan(ay, ax)
	if local_angle * prev_local_angle < 0.0 and (2.0 * math.abs(local_angle) > math.pi) then
		if 2.0 * math.abs(local_angle) > math.pi then
			if local_angle < 0.0 then
				revolutions = revolutions + 1
			else
				revolutions = revolutions - 1
			end
		end
	end
	local delta_angle = math.deg(local_angle + revolutions * math.pi * 2.0)
	if rotate_axis == gizmo.rz or rotate_axis == gizmo.rw then
		delta_angle = -1.0 * delta_angle
	end
	local gizmo_to_last_hit = math3d.normalize(math3d.sub(last_hit, gizmo_pos))
	local angle_base_dir = gizmo_dir_to_world(mc.XAXIS)
	if rotate_axis == gizmo.rx then
		angle_base_dir = gizmo_dir_to_world(mc.NZAXIS)
	elseif rotate_axis == gizmo.rw then
		angle_base_dir = math3d.normalize(math3d.cross(mc.YAXIS, axis_dir))
	end
	local fan_angle = math.deg(math.acos(math3d.dot(gizmo_to_last_hit, angle_base_dir)))
	if local_space and rotate_axis ~= gizmo.rw then
		gizmo_to_last_hit = math3d.transform(math3d.inverse(iom.get_rotation(re)), gizmo_to_last_hit, 0)
	end
	local is_top = (rotate_axis == gizmo.ry) and (math3d.index(gizmo_to_last_hit, 3) > 0) or (math3d.index(gizmo_to_last_hit, 2) > 0)
	if not is_top then
		fan_angle = 360 - fan_angle
	end
	local ce <close> = world:entity(irq.main_camera(), "camera:in")
	local hitray = iom.ray(ce.camera.viewprojmat, {x, y})
	local fan_delta = math3d.dot(hitray.dir, axis_dir) > 0 and -delta_angle or delta_angle
	if rotate_axis == gizmo.rx then
		fan_delta = -fan_delta
	end
	show_rotate_fan(rotate_axis, fan_angle, fan_delta)
	local quat = math3d.quaternion { axis = last_rotate_axis, r = math.rad(delta_angle) }
	gizmo:set_rotation(math3d.mul(last_rotate, quat))
	if local_space then
		local e <close> = world:entity(gizmo.rot_circle_root_eid)
		iom.set_rotation(e, quat)
	end
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end

local function scale_gizmo(x, y)
	if not x or not y then return end
	local new_scale
	if uniform_scale then
		local delta_x = x - last_mouse_pos[1]
		local delta_y = last_mouse_pos[2] - y
		local factor = (delta_x + delta_y) / 60.0
		local scale_factor = 1.0
		if factor < 0 then
			scale_factor = 1 / (1 + math.abs(factor))
		else
			scale_factor = 1 + factor
		end
		new_scale = {last_gizmo_scale[1] * scale_factor, last_gizmo_scale[2] * scale_factor, last_gizmo_scale[3] * scale_factor}
	else
		new_scale = {last_gizmo_scale[1], last_gizmo_scale[2], last_gizmo_scale[3]}
		local ce <close> = world:entity(irq.main_camera(), "camera:in")
		local new_offset = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
		local delta_offset = math3d.sub(new_offset, init_offset)
		local scale_factor = (1.0 + 3.0 * math3d.length(delta_offset))
		local index = 0
		if move_axis.dir == gizmo_const.DIR_X then
			index = 1
		elseif move_axis.dir == gizmo_const.DIR_Y then
			index = 2
		elseif move_axis.dir == gizmo_const.DIR_Z then
			index = 3
		end
		if index > 0 then
			if math3d.index(delta_offset, index) < 0 then
				new_scale[index] = last_gizmo_scale[index] / scale_factor
			else
				new_scale[index] = last_gizmo_scale[index] * scale_factor
			end
		end
	end
	gizmo:set_scale(new_scale)
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end

local function select_light_gizmo(x, y)
	light_gizmo_mode = 0
	if not light_gizmo.current_light then return light_gizmo_mode end

	local le <close> = world:entity(light_gizmo.current_light, "light:in")
	local light_pos = iom.get_position(le)
	local function hit_test_circle(axis, radius, pos)
		local hit_pos = mouse_hit_plane({x, y}, {dir = axis, pos = math3d.totable(pos)})
		if not hit_pos then
			return
		end
		local dist = math3d.length(math3d.sub(pos, hit_pos))
		local high_light = math.abs(dist - radius) < gizmo_const.ROTATE_HIT_RADIUS * gizmo.scale * 2.5
		light_gizmo.highlight(high_light)
		return high_light
	end

	click_dir_point_light = nil
	click_dir_spot_light = nil
	local radius = ilight.range(le)
	if le.light.type == "point" then
		if hit_test_circle({1, 0, 0}, radius, light_pos) then
			click_dir_point_light = {1, 0, 0}
			light_gizmo_mode = 1
		elseif hit_test_circle({0, 1, 0}, radius, light_pos) then
			click_dir_point_light = {0, 1, 0}
			light_gizmo_mode = 2
		elseif hit_test_circle({0, 0, 1}, radius, light_pos) then
			click_dir_point_light = {0, 0, 1}
			light_gizmo_mode = 3
		end
	elseif le.light.type == "spot" then
		local dir = math3d.totable(math3d.transform(iom.get_rotation(le), mc.ZAXIS, 0))
		local mat = iom.worldmat(le)
		local centre = math3d.transform(mat, math3d.vector{0, 0, ilight.range(le)}, 1)
		radius = radius * math.tan(ilight.outter_radian(le) * 0.5)
		if hit_test_circle(dir, radius, centre) then
			click_dir_spot_light = dir
			light_gizmo_mode = 4
		else
			local dist = mu.pt2d_line_distance(world_to_screen(light_pos), world_to_screen(centre), math3d.vector(x, y, 0.0))
			if math.abs(dist) < 9.0 then
				light_gizmo_mode = 5
				light_gizmo.highlight(true)
			else
				light_gizmo.highlight(false)
			end
		end
	end
	return light_gizmo_mode
end

function gizmo:select_gizmo(x, y)
	if not x or not y or not can_edit_srt(gizmo.target_eid) then return false end
	if self.mode == gizmo_const.MOVE or self.mode == gizmo_const.ROTATE then
		last_mouse_pos = {x, y}
		local mode = select_light_gizmo(x, y)
		if mode ~= 0 then
			if mode == 5 then
				local le <close> = world:entity(light_gizmo.current_light, "light:in")
				last_spot_range = ilight.range(le)
				last_gizmo_pos = math3d.totable(iom.get_position(le))
				local mat = iom.worldmat(le)
				local circle_centre = math3d.transform(mat, math3d.vector{0, 0, ilight.range(le)}, 1)
				local move_dir = math3d.sub(circle_centre, iom.get_position(le))
				local ce <close> = world:entity(irq.main_camera(), "camera:in")
				init_offset.v = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_dir), last_gizmo_pos)
			end
			return true
		end
	end
	local te <close> = world:entity(gizmo.target_eid)
	if self.mode == gizmo_const.MOVE or self.mode == gizmo_const.SCALE then
		move_axis = select_axis(x, y)
		gizmo:highlight_axis_or_plane(move_axis)
		if move_axis or uniform_scale then
			last_mouse_pos = {x, y}
			last_gizmo_scale = math3d.totable(iom.get_scale(te))
			if move_axis then
				local re <close> = world:entity(gizmo.root_eid)
				last_gizmo_pos = math3d.totable(iom.get_position(re))
				local ce <close> = world:entity(irq.main_camera(), "camera:in")
				init_offset.v = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
			end
			return true
		end
	elseif self.mode == gizmo_const.ROTATE then
		rotate_axis, last_hit.v = select_rotate_axis(x, y)
		if rotate_axis then
			last_rotate.q = iom.get_rotation(te)
			if rotate_axis == gizmo.rw or not local_space then
				last_rotate_axis.v = math3d.transform(math3d.inverse(iom.get_rotation(te)), rotate_axis.dir, 0)
			else
				last_rotate_axis.v = rotate_axis.dir
			end

			local sc = world_to_screen(iom.get_position(te))
			init_screen_offest.v = math3d.normalize(math3d.vector(x - math3d.index(sc, 1), y - math3d.index(sc, 2), 0))
			local_angle = 0
			revolutions = 0
			return true
		end
	end
	return false
end

local last_mouse_pos_x = 0
local last_mouse_pos_y = 0
local function on_mouse_move()
	local mp = world:get_mouse()
	local x, y = iviewport.cvt2scenept(mp.x, mp.y)
	if navigizmo:hit_test(x, y) then
		return
	end
	if gizmo_seleted or gizmo.mode == gizmo_const.SELECT then
		return
	end
	
	if last_mouse_pos_x ~= x or last_mouse_pos_y ~= y then
		last_mouse_pos_x = x
		last_mouse_pos_y = y
		local mx, my = x, y
		if select_light_gizmo(mx, my) == 0 then
			if gizmo.mode == gizmo_const.MOVE or gizmo.mode == gizmo_const.SCALE then
				local axis = select_axis(mx, my)
				gizmo:highlight_axis_or_plane(axis)
			elseif gizmo.mode == gizmo_const.ROTATE then
				gizmo:hide_rotate_fan()
				select_rotate_axis(mx, my)
			end
		end
	end
end

function gizmo_sys:render_submit()
	navigizmo:draw()
end

function gizmo_sys:camera_usage()
	navigizmo:update()
end

local event_mouse_drag	= world:sub {"mousedrag"}
local event_mouse_down	= world:sub {"mousedown"}
local event_mouse_up	= world:sub {"mouseup"}
local event_keypress	= world:sub {"keyboard"}
local vr_mb 			= world:sub {"scene_viewrect_changed"}

function gizmo_sys:handle_input()
	for _, viewrect in vr_mb:unpack() do
		navigizmo:on_view_rect(viewrect)
        break
    end
	for _, what, x, y in event_mouse_down:unpack() do
		x, y = iviewport.cvt2scenept(x, y)
		if what == "LEFT" then
			rectselect:start(x, y)
			if not navigizmo:on_click(x, y) then
				gizmo_seleted = gizmo:select_gizmo(x, y)
				gizmo:click_axis_or_plane(move_axis)
				gizmo:click_axis(rotate_axis)
			end
		end
	end


	on_mouse_move()

	for _, what, x, y in event_mouse_drag:unpack() do
		x, y = iviewport.cvt2scenept(x, y)
		if what == "LEFT" then
			if light_gizmo_mode ~= 0 then
				move_light_gizmo(x, y)
			elseif gizmo.mode == gizmo_const.MOVE and move_axis then
				move_gizmo(x, y)
			elseif gizmo.mode == gizmo_const.SCALE then
				if move_axis or uniform_scale then
					scale_gizmo(x, y)
				end
			elseif gizmo.mode == gizmo_const.ROTATE and rotate_axis then
				rotate_gizmo(x, y)
			else
				rectselect:draw(x, y)
			end
		end
	end

	for _, what, x, y in event_mouse_up:unpack() do
		x, y = iviewport.cvt2scenept(x, y)
		rectselect:finish()
		if what == "LEFT" then
			gizmo:reset_move_axis_color()
			if gizmo.mode == gizmo_const.ROTATE then
				if local_space then
					if gizmo.target_eid then
						local re <close> = world:entity(gizmo.root_eid)
						iom.set_rotation(re, iom.get_rotation(gizmo.target_eid))
					end
					local e <close> = world:entity(gizmo.rot_circle_root_eid)
					iom.set_rotation(e, mc.IDENTITY_QUAT)
				end
			end
			gizmo_seleted = false
			light_gizmo_mode = 0
			if is_tran_dirty then
				is_tran_dirty = false
				local target = gizmo.target_eid
				if target then
					local te <close> = world:entity(target)
					if gizmo.mode == gizmo_const.SCALE then
						cmd_queue:record({action = gizmo_const.SCALE, eid = target, oldvalue = last_gizmo_scale, newvalue = math3d.totable(iom.get_scale(te))})
					elseif gizmo.mode == gizmo_const.ROTATE then
						cmd_queue:record({action = gizmo_const.ROTATE, eid = target, oldvalue = math3d.totable(last_rotate), newvalue = math3d.totable(iom.get_rotation(te))})
					elseif gizmo.mode == gizmo_const.MOVE then
						local parent = hierarchy:get_parent(gizmo.target_eid)
						local pw = nil
						if parent then
							local pe <close> = world:entity(parent)
							pw = parent and iom.worldmat(pe) or nil
						end
						local localpos = last_gizmo_pos
						if pw then
							localpos = math3d.totable(math3d.transform(math3d.inverse(pw), last_gizmo_pos, 1))
						end
						cmd_queue:record({action = gizmo_const.MOVE, eid = target, oldvalue = localpos, newvalue = math3d.totable(iom.get_position(te))})
					end
				end
			end
		end
	end
	
	for _, key, press, state in event_keypress:unpack() do
		if state.CTRL then
			if key == "Z" and press == 1 then
				cmd_queue:undo()
			elseif key == "Y" and press == 1 then
				cmd_queue:redo()
			end
		end
	end
end

local event_camera 			= world:sub {"camera"}
local event_gizmo_mode 		= world:sub {"GizmoMode"}
function gizmo_sys:handle_event()
	for _ in event_camera:unpack() do
		gizmo:update_scale()
		gizmo:updata_uniform_scale()
		gizmo:update_axis_plane()
		break
	end
	for _, what, value in event_gizmo_mode:unpack() do
		if what == "select" then
			gizmo:on_mode(gizmo_const.SELECT)
		elseif what == "rotate" then
			gizmo:on_mode(gizmo_const.ROTATE)
		elseif what == "move" then
			gizmo:on_mode(gizmo_const.MOVE)
		elseif what == "scale" then
			gizmo:on_mode(gizmo_const.SCALE)
		elseif what == "localspace" then
			local_space = value
			gizmo:update_axis_plane()
			gizmo:set_rotation()
		end
	end
	for _,pick_id in event_pickup:unpack() do
		local eid = pick_id
		if eid then
			if not gizmo_seleted then
				local teid = hierarchy:get_select_adapter(eid)
				if hierarchy:get_node(teid) then
					gizmo:set_target({teid})
				end
			end
			if imodifier.highlight then
				imodifier.set_target(imodifier.highlight, eid)
                imodifier.start(imodifier.highlight, {})
			end
		else
			if not gizmo_seleted and not camera_mgr.select_frustum then
				if last_mouse_pos_x and last_mouse_pos_y then
					gizmo:set_target()
				end
			end
		end
	end
end

function gizmo_sys:data_changed()
end