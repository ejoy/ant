local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util

local icamera	= ecs.import.interface "ant.camera|icamera"
local iom 		= ecs.import.interface "ant.objcontroller|iobj_motion"
local ifs 		= ecs.import.interface "ant.scene|ifilter_state"
local ientity 	= ecs.import.interface "ant.render|ientity"
local ilight 	= ecs.import.interface "ant.render|ilight"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local imesh		= ecs.import.interface "ant.asset|imesh"

local igui		= ecs.import.interface "tools.prefab_editor|igui"


local cmd_queue = ecs.require "gizmo.command_queue"
local utils 	= ecs.require "mathutils"
local camera_mgr= ecs.require "camera_manager"
local gizmo 	= ecs.require "gizmo.gizmo"
local inspector = ecs.require "widget.inspector"

local hierarchy = require "hierarchy_edit"
local global_data= require "common.global_data"
local gizmo_const= require "gizmo.const"

local math3d = require "math3d"

local gizmo_sys = ecs.system "gizmo_system"

local move_axis
local rotate_axis
local uniform_scale = false
local gizmo_scale = 1.0
local local_space = false


function gizmo:update()
	self:set_position()
	self:set_rotation()
	self:update_scale()
	self:updata_uniform_scale()
	self:update_axis_plane()
	inspector.update_ui(false)
end

function gizmo:set_target(eid)
	local target = hierarchy:get_select_adapter(eid)
	if self.target_eid == target then
		return
	end
	local old_target = self.target_eid
	self.target_eid = target
	gizmo:show_by_state(target ~= nil)
	world:pub {"Gizmo","ontarget", old_target, target}
end

function gizmo:updata_uniform_scale()
	if not self.rw.eid or not self.rw.eid[1] then return end
	local mc = irq.main_camera()
	self.rw.dir = math3d.totable(iom.get_direction(mc))
	--update_camera
	local r = iom.get_rotation(mc)
	iom.set_rotation(self.rw.eid[1], r)
	iom.set_rotation(self.rw.eid[3], r)
	iom.set_rotation(self.rw.eid[4], r)
end

function gizmo:set_scale(inscale)
	if not self.target_eid or hierarchy:is_locked(self.target_eid) then
		return
	end
	iom.set_scale(self.target_eid, inscale)
end

function gizmo:update_position(worldpos)
	local newpos
	if worldpos then
		local pid
		if not gizmo.target_eid.scene then
			w:sync("scene:in", gizmo.target_eid)
		end
		pid = gizmo.target_eid.scene.parent
		local parent_e
		if pid then
			for e in w:select "scene:in" do
				if e.scene.id == pid then
					parent_e = e
					break
				end
			end
		end
		local parent_worldmat = parent_e and iom.worldmat(parent_e) or nil
		local localPos
		if not parent_worldmat then
			localPos = worldpos
		else
			localPos = math3d.totable(math3d.transform(math3d.inverse(parent_worldmat), math3d.vector(worldpos), 1))
		end
		iom.set_position(self.target_eid, localPos)
		newpos = worldpos
		inspector.update_template_tranform(self.target_eid)
	else
		local wm = iom.worldmat(gizmo.target_eid)
		local s, r, t = math3d.srt(wm)
		newpos = math3d.totable(t)
	end
	iom.set_position(self.root_eid, newpos)
	iom.set_position(self.uniform_rot_root_eid, newpos)
end

function gizmo:set_position(worldpos)
	if not self.target_eid or hierarchy:is_locked(self.target_eid) then
		return
	end
	world:pub {"Gizmo", "updateposition", worldpos}
end

function gizmo:set_rotation(inrot)
	if not self.target_eid or hierarchy:is_locked(self.target_eid) then
		return
	end
	local newrot
	if inrot then
		iom.set_rotation(self.target_eid, inrot)
		newrot = inrot
	else
		newrot = iom.get_rotation(self.target_eid)
	end
	if self.mode == gizmo_const.SCALE then
		iom.set_rotation(self.root_eid, newrot)
	elseif self.mode == gizmo_const.MOVE or self.mode == gizmo_const.ROTATE then
		if local_space then
			iom.set_rotation(self.root_eid, newrot)
		else
			iom.set_rotation(self.root_eid, math3d.quaternion{0,0,0})
		end
	end
end

function gizmo:on_mode(mode)
	self:show_by_state(false)
	self.mode = mode
	self:show_by_state(true)
	self:set_rotation()
end

local function create_arrow_widget(axis_root, axis_str)
	local cone_t
	local cylindere_t
	local local_rotator
	local color
	if axis_str == "x" then
		cone_t = math3d.vector(gizmo_const.AXIS_LEN, 0, 0)
		local_rotator = math3d.quaternion{0, 0, math.rad(-90)}
		cylindere_t = math3d.vector(0.5 * gizmo_const.AXIS_LEN, 0, 0)
		color = gizmo_const.COLOR_X
	elseif axis_str == "y" then
		cone_t = math3d.vector(0, gizmo_const.AXIS_LEN, 0)
		local_rotator = mc.IDENTITY_QUAT
		cylindere_t = math3d.vector(0, 0.5 * gizmo_const.AXIS_LEN, 0)
		color = gizmo_const.COLOR_Y
	elseif axis_str == "z" then
		cone_t = math3d.vector(0, 0, gizmo_const.AXIS_LEN)
		local_rotator = math3d.quaternion{math.rad(90), 0, 0}
		cylindere_t = math3d.vector(0, 0, 0.5 * gizmo_const.AXIS_LEN)
		color = gizmo_const.COLOR_Z
	end
	local cylindereid = ecs.create_entity{
		policy = {
			"ant.general|name",
			"ant.render|render",
		},
		data = {
			reference = true,
			filter_state = "main_view",
			scene = {
				srt = {
					s = {0.2, 10, 0.2},
					r = local_rotator,
					t = cylindere_t
				}
			},
			material = "/pkg/ant.resources/materials/singlecolor_translucent_nocull.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder" .. axis_str,
			on_ready = function (e)
				ifs.set_state(e, "main_view", false)
				imaterial.set_property(e, "u_color", color)
			end
		}
	}
	ecs.method.set_parent(cylindereid, axis_root)
	local coneeid = ecs.create_entity{
		policy = {
			"ant.general|name",
			"ant.render|render",
		},
		data = {
			reference = true,
			filter_state = "main_view",
			scene = {srt = {s = {1, 1.5, 1, 0}, r = local_rotator, t = cone_t}},
			material = "/pkg/ant.resources/materials/singlecolor_translucent_nocull.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone" .. axis_str,
			on_ready = function (e)
				ifs.set_state(e, "main_view", false)
				imaterial.set_property(e, "u_color", color)
			end
		}
	}
	ecs.method.set_parent(coneeid, axis_root)
	if axis_str == "x" then
		gizmo.tx.eid = {cylindereid, coneeid}
	elseif axis_str == "y" then
		gizmo.ty.eid = {cylindereid, coneeid}
	elseif axis_str == "z" then
		gizmo.tz.eid = {cylindereid, coneeid}
	end
end

function gizmo_sys:init()

end

local function mouse_hit_plane(screen_pos, plane_info)
	return utils.ray_hit_plane(iom.ray(irq.main_camera(), screen_pos), plane_info)
end

local function create_global_axes(srt)
	local off = 0.1
	ientity.create_screen_axis_entity(srt, {type = "percent", screen_pos = {off, 1-off}}, "global_axes")
end

function gizmo:update_scale()
	local mc = irq.main_camera()
	local viewdir = iom.get_direction(mc)
	local eyepos = iom.get_position(mc)
	local project_dist = math3d.dot(math3d.normalize(viewdir), math3d.sub(iom.get_position(self.root_eid), eyepos))
	gizmo_scale = project_dist * 0.6
	if self.root_eid then
		iom.set_scale(self.root_eid, gizmo_scale)
	end
	if self.uniform_rot_root_eid then
		iom.set_scale(self.uniform_rot_root_eid, gizmo_scale)
	end
end

function gizmo_sys:post_init()
	--local srt = {r = math3d.quaternion{0, 0, 0}, t = {0,0,0,1}}
	local axis_root = ecs.create_entity {
		policy = {
			"ant.general|name",
			"ant.scene|scene_object",
		},
		data = {
			reference = true,
			name = "axis root",
			scene = {srt = {}},
		},
	}
	gizmo.root_eid = axis_root
	local rot_circle_root = ecs.create_entity {
		policy = {
			"ant.general|name",
			"ant.scene|scene_object",
		},
		data = {
			reference = true,
			name = "rot root",
			scene = {srt = {}},
		},
	}

	ecs.method.set_parent(rot_circle_root, axis_root)
	gizmo.rot_circle_root_eid = rot_circle_root

	local uniform_rot_root = ecs.create_entity {
		policy = {
			"ant.general|name",
			"ant.scene|scene_object",
		},
		data = {
			reference = true,
			name = "rot root",
			scene = {srt = {}},
		},
	}
	gizmo.uniform_rot_root_eid = uniform_rot_root

	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	
	local plane_xy_eid = ientity.create_prim_plane_entity(
		{t = {gizmo_const.MOVE_PLANE_OFFSET, gizmo_const.MOVE_PLANE_OFFSET, 0, 1}, s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0}, r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})},
		"/pkg/ant.resources/materials/singlecolor_translucent_nocull.material",
		gizmo.txy.color,
		"plane_xy", true)
	ecs.method.set_parent(plane_xy_eid, axis_root)
	gizmo.txy.eid = {plane_xy_eid, plane_xy_eid}

	local plane_yz_eid = ientity.create_prim_plane_entity(
		{t = {0, gizmo_const.MOVE_PLANE_OFFSET, gizmo_const.MOVE_PLANE_OFFSET, 1}, s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0}, r = math3d.tovalue(math3d.quaternion{0, 0, math.rad(90)})},
		"/pkg/ant.resources/materials/singlecolor_translucent_nocull.material",
		gizmo.tyz.color,
		"plane_yz", true)
	ecs.method.set_parent(plane_yz_eid, axis_root)
	gizmo.tyz.eid = {plane_yz_eid, plane_yz_eid}

	local plane_zx_eid = ientity.create_prim_plane_entity(
		{t = {gizmo_const.MOVE_PLANE_OFFSET, 0, gizmo_const.MOVE_PLANE_OFFSET, 1}, s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0}},
		"/pkg/ant.resources/materials/singlecolor_translucent_nocull.material",
		gizmo.tzx.color,
		"plane_zx", true)
	ecs.method.set_parent(plane_zx_eid, axis_root)
	gizmo.tzx.eid = {plane_zx_eid, plane_zx_eid}
	gizmo:reset_move_axis_color()

	-- roate axis
	local uniform_rot_eid = ientity.create_circle_entity(gizmo_const.UNIFORM_ROT_AXIS_LEN, gizmo_const.ROTATE_SLICES, {}, "rotate_gizmo_uniform", gizmo_const.COLOR_GRAY, true)
	ecs.method.set_parent(uniform_rot_eid, uniform_rot_root)
	local function create_rotate_fan(radius, circle_trans)
		local mesh_eid = ientity.create_circle_mesh_entity(radius, gizmo_const.ROTATE_SLICES, circle_trans, "/pkg/ant.resources/materials/singlecolor_translucent_nocull.material", "rotate_mesh_gizmo_uniform", {0, 0, 1, 0.5}, true)
		ecs.method.set_parent(mesh_eid, axis_root)
		return mesh_eid
	end
	-- counterclockwise mesh
	local rot_ccw_mesh_eid = create_rotate_fan(gizmo_const.UNIFORM_ROT_AXIS_LEN, {})
	ecs.method.set_parent(rot_ccw_mesh_eid, uniform_rot_root)
	-- clockwise mesh
	local rot_cw_mesh_eid = create_rotate_fan(gizmo_const.UNIFORM_ROT_AXIS_LEN, {})
	ecs.method.set_parent(rot_cw_mesh_eid, uniform_rot_root)
	gizmo.rw.eid = {uniform_rot_eid, uniform_rot_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}

	local function create_rotate_axis(axis, line_end, circle_trans)
		local line_eid = ientity.create_line_entity({}, {0, 0, 0}, line_end, "", axis.color, true)
		ecs.method.set_parent(line_eid, rot_circle_root)
		local rot_eid = ientity.create_circle_entity(gizmo_const.AXIS_LEN, gizmo_const.ROTATE_SLICES, circle_trans, "rotate gizmo circle", axis.color, true)
		ecs.method.set_parent(rot_eid, rot_circle_root)
		local rot_ccw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, circle_trans)
		local rot_cw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, circle_trans)
		axis.eid = {rot_eid, line_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}
	end
	create_rotate_axis(gizmo.rx, {gizmo_const.AXIS_LEN * 0.5, 0, 0}, {r = math3d.tovalue(math3d.quaternion{0, math.rad(90), 0})})
	create_rotate_axis(gizmo.ry, {0, gizmo_const.AXIS_LEN * 0.5, 0}, {r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})})
	create_rotate_axis(gizmo.rz, {0, 0, gizmo_const.AXIS_LEN * 0.5}, {})
	
	-- scale axis
	local function create_scale_cube(srt, color, axis_name)
		local eid = ecs.create_entity {
			policy = {
				"ant.render|render",
				"ant.general|name",
				"ant.scene|scene_object",
			},
			data = {
				reference = true,
				filter_state = "main_view|selectable",
				scene = {srt = srt},
				material = "/pkg/ant.resources/materials/singlecolor_translucent_nocull.material",
				mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
				name = "scale_cube" .. axis_name,
				on_ready = function (e)
					ifs.set_state(e, "main_view", false)
					imaterial.set_property(e, "u_color", color)
				end
			}
		}
		return eid
	end

	-- scale axis cube
	local cube_eid = create_scale_cube({s = gizmo_const.AXIS_CUBE_SCALE}, gizmo_const.COLOR_GRAY, "uniform scale")
	ecs.method.set_parent(cube_eid, axis_root)
	gizmo.uniform_scale_eid = cube_eid
	local function create_scale_axis(axis, axis_end)
		local cube_eid = create_scale_cube({t = axis_end, s = gizmo_const.AXIS_CUBE_SCALE}, axis.color, "scale axis")
		ecs.method.set_parent(cube_eid, axis_root)
		local line_eid = ientity.create_line_entity({}, {0, 0, 0}, axis_end, "", axis.color, true)
		ecs.method.set_parent(line_eid, axis_root)
		axis.eid = {cube_eid, line_eid}
	end
	create_scale_axis(gizmo.sx, {gizmo_const.AXIS_LEN, 0, 0})
	create_scale_axis(gizmo.sy, {0, gizmo_const.AXIS_LEN, 0})
	create_scale_axis(gizmo.sz, {0, 0, gizmo_const.AXIS_LEN})

	-- global_axis_x_eid = ientity.create_line_entity({}, {0, 0, 0}, {0.1, 0, 0}, "", gizmo_const.COLOR_X)
	-- global_axis_y_eid = ientity.create_line_entity({}, {0, 0, 0}, {0, 0.1, 0}, "", gizmo_const.COLOR_Y)
	-- global_axis_z_eid = ientity.create_line_entity({}, {0, 0, 0}, {0, 0, 0.1}, "", gizmo_const.COLOR_Z)
	
    ientity.create_grid_entity("", 64, 64, 1, 1)
end
local mb_main_camera_changed = world:sub{"main_queue", "camera_changed"}

function gizmo_sys:init_world()
	create_global_axes{s=0.1}
end
function gizmo_sys:entity_ready()
	for _ in mb_main_camera_changed:each() do
		gizmo:update_scale()
		gizmo:show_by_state(false)
		gizmo:hide_rotate_fan()
	end
end

local function gizmo_dir_to_world(localDir)
	if local_space or (gizmo.mode == gizmo_const.SCALE) then
		return math3d.totable(math3d.transform(iom.get_rotation(gizmo.root_eid), localDir, 0))
	else
		return localDir
	end
end

function gizmo:update_axis_plane()
	if self.mode ~= gizmo_const.MOVE or not self.target_eid then
		return
	end

	local gizmoPosVec = iom.get_position(self.root_eid)
	local worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_Z))
	local plane_xy = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_Y))
	local plane_zx = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_X))
	local plane_yz = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}


	local eyepos = iom.get_position(irq.main_camera())

	local project = math3d.sub(eyepos, math3d.mul(plane_xy.n, math3d.dot(plane_xy.n, eyepos) + plane_xy.d))
	local invmat = math3d.inverse(iom.worldmat(self.root_eid))
	local tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.txy.eid[1], {(tp[1] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (tp[2] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0})
	self.txy.area = (tp[1] > 0) and ((tp[2] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[2] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_zx.n, math3d.dot(plane_zx.n, eyepos) + plane_zx.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.tzx.eid[1], {(tp[1] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0, (tp[3] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
	self.tzx.area = (tp[1] > 0) and ((tp[3] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[3] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_yz.n, math3d.dot(plane_yz.n, eyepos) + plane_yz.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.tyz.eid[1], {0,(tp[2] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (tp[3] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
	self.tyz.area = (tp[3] > 0) and ((tp[2] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[2] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}

local camera_event = world:sub{"Camera"}

local function select_axis_plane(x, y)
	if gizmo.mode ~= gizmo_const.MOVE then
		return nil
	end
	local function hit_test_axix_plane(axis_plane)
		local gizmoPos = iom.get_position(gizmo.root_eid)
		local hitPosVec = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(axis_plane.dir), pos = math3d.totable(gizmoPos)})
		if hitPosVec then
			return math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(gizmo.root_eid)), math3d.sub(hitPosVec, gizmoPos), 0))
		end
		return nil
	end
	local planeHitRadius = gizmo_scale * gizmo_const.MOVE_PLANE_HIT_RADIUS * 0.5
	local axis_plane = gizmo.tyz
	local posToGizmo = hit_test_axix_plane(axis_plane)
	
	if posToGizmo then
		if axis_plane.area == gizmo_const.RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_TOP then
			posToGizmo[3] = -posToGizmo[3]
		end
		if posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			return axis_plane
		end
	end
	posToGizmo = hit_test_axix_plane(gizmo.txy)
	axis_plane = gizmo.txy
	if posToGizmo then
		if axis_plane.area == gizmo_const.RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == gizmo_const.LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius then
			return axis_plane
		end
	end
	posToGizmo = hit_test_axix_plane(gizmo.tzx)
	axis_plane = gizmo.tzx
	if posToGizmo then
		if axis_plane.area == gizmo_const.RIGHT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == gizmo_const.LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == gizmo_const.LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			return axis_plane
		end
	end
	return nil
end

local function select_axis(x, y)
	if not gizmo.target_eid then
		return
	end
	assert(x and y)
	local vx, vy = igui.cvt2scenept(x, y)
	local mqvr = irq.view_rect "main_queue"
	if not mu.pt2d_in_rect(vx, vy, mqvr) then
		return
	end

	if gizmo.mode == gizmo_const.SCALE then
		gizmo:reset_scale_axis_color()
	elseif gizmo.mode == gizmo_const.MOVE then
		gizmo:reset_move_axis_color()
	end
	-- by plane
	local axisPlane = select_axis_plane(x, y)
	if axisPlane then
		return axisPlane
	end
	local mcref = irq.main_camera()
	w:sync("camera:in", mcref)
	local vpmat = mcref.camera.viewprojmat

	local gizmo_obj_pos = iom.get_position(gizmo.root_eid)
	local start = mu.world_to_screen(mc, mqvr, gizmo_obj_pos)
	uniform_scale = false
	-- uniform scale
	local hp = math3d.vector(vx, vy, 0)
	if gizmo.mode == gizmo_const.SCALE then
		local radius = math3d.length(math3d.sub(hp, start))
		if radius < gizmo_const.MOVE_HIT_RADIUS_PIXEL then
			uniform_scale = true
			imaterial.set_property(gizmo.uniform_scale_eid, "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sx.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sx.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sy.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sy.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sz.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sz.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			return
		end
	end
	-- by axis
	local line_len = gizmo_const.AXIS_LEN * gizmo_scale

	local axes = {
		x = {line_len, 0, 0},
		y = {0, line_len, 0},
		z = {0, 0, line_len},
	}

	for k, delta_dir in pairs(axes) do
		local end_ptWS = math3d.add(gizmo_obj_pos, math3d.vector(gizmo_dir_to_world(delta_dir)))
		local end_pt = mu.world_to_screen(vpmat, mqvr, end_ptWS)
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
	local vx, vy = igui.cvt2scenept(x, y)
	local mqvr = irq.view_rect "main_queue"
	if not mu.pt2d_in_rect(vx, vy, mqvr) then
		return
	end

	gizmo:reset_rotate_axis_color()

	local function hit_test_rotate_axis(axis)
		local gizmoPos = iom.get_position(gizmo.root_eid)
		local axisDir = (axis ~= gizmo.rw) and gizmo_dir_to_world(axis.dir) or axis.dir
		local hitPosVec = mouse_hit_plane({vx, vy}, {dir = axisDir, pos = math3d.totable(gizmoPos)})
		if not hitPosVec then
			return
		end
		local dist = math3d.length(math3d.sub(gizmoPos, hitPosVec))
		local adjust_axis_len = (axis == gizmo.rw) and gizmo_const.UNIFORM_ROT_AXIS_LEN or gizmo_const.AXIS_LEN
		if math.abs(dist - gizmo_scale * adjust_axis_len) < gizmo_const.ROTATE_HIT_RADIUS * gizmo_scale then
			imaterial.set_property(axis.eid[1], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			imaterial.set_property(axis.eid[2], "u_color", gizmo_const.HIGHTLIGHT_COLOR)
			return hitPosVec
		else
			imaterial.set_property(axis.eid[1], "u_color", axis.color)
			imaterial.set_property(axis.eid[2], "u_color", axis.color)
			return nil
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

local camera_zoom = world:sub {"camera", "zoom"}
local mouse_drag = world:sub {"mousedrag"}
local mouse_down = world:sub {"mousedown"}
local mouse_up = world:sub {"mouseup"}
local gizmo_target_event = world:sub {"Gizmo"}
local gizmo_mode_event = world:sub {"GizmoMode"}

local last_mouse_pos
local last_gizmo_pos
local init_offset = math3d.ref()
local last_gizmo_scale
local last_rotate_axis = math3d.ref()
local last_rotate = math3d.ref()
local last_hit = math3d.ref()
local gizmo_seleted = false
local is_tran_dirty = false

local function move_gizmo(x, y)
	if not gizmo.target_eid or not x or not y then
		return
	end
	local deltaPos
	if move_axis == gizmo.txy or move_axis == gizmo.tyz or move_axis == gizmo.tzx then
		local gizmoTPos = math3d.totable(iom.get_position(gizmo.root_eid))
		local downpos = mouse_hit_plane(last_mouse_pos, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmoTPos})
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmoTPos})
		if downpos and curpos then
			local deltapos = math3d.totable(math3d.sub(curpos, downpos))
			deltaPos = {last_gizmo_pos[1] + deltapos[1], last_gizmo_pos[2] + deltapos[2], last_gizmo_pos[3] + deltapos[3]}
		end
	else
		local mc = irq.main_camera()
		local newOffset = utils.view_to_axis_constraint(iom.ray(mc, {x, y}), iom.get_position(mc), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
		local deltaOffset = math3d.totable(math3d.sub(newOffset, init_offset))
		deltaPos = {last_gizmo_pos[1] + deltaOffset[1], last_gizmo_pos[2] + deltaOffset[2], last_gizmo_pos[3] + deltaOffset[3]}
	end

	gizmo:set_position(deltaPos)
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
	if light_gizmo_mode == 4 or light_gizmo_mode == 5 then
		local mat = iom.worldmat(light_gizmo.current_light)
		circle_centre = math3d.transform(mat, math3d.vector{0, 0, ilight.range(light_gizmo.current_light)}, 1)
	end
	local lightPos = iom.get_position(light_gizmo.current_light)
	if light_gizmo_mode == 4 then
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(click_dir_spot_light), pos = math3d.totable(circle_centre)})
		ilight.set_inner_radian(light_gizmo.current_light, math3d.length(math3d.sub(curpos, circle_centre)))
	elseif light_gizmo_mode == 5 then
		local move_dir = math3d.sub(circle_centre, lightPos)
		local mc = irq.main_camera()
		local new_offset = utils.view_to_axis_constraint(iom.ray(mc, {x, y}), iom.get_position(mc), gizmo_dir_to_world(move_dir), last_gizmo_pos)
		local offset = math3d.length(math3d.sub(new_offset, init_offset))
		if math3d.length(math3d.sub(new_offset, lightPos)) < math3d.length(math3d.sub(init_offset, lightPos)) then
			offset = -offset
		end
		ilight.set_range(light_gizmo.current_light, last_spot_range + offset)
	else
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(click_dir_point_light), pos = math3d.totable(lightPos)})
		ilight.set_range(light_gizmo.current_light, math3d.length(math3d.sub(curpos, lightPos)))
	end
	light_gizmo.update_gizmo()
	light_gizmo.highlight(true)
	world:pub {"Gizmo", "update"}
end

local function show_rotate_fan(rotAxis, startAngle, deltaAngle)
	if not rotAxis.eid[3].render_object then
		w:sync("render_object:in", rotAxis.eid[3])
	end
	rotAxis.eid[3].render_object.ib.num = 0
	if not rotAxis.eid[4].render_object then
		w:sync("render_object:in", rotAxis.eid[4])
	end
	rotAxis.eid[4].render_object.ib.num = 0
	local start
	local num
	local stepAngle = gizmo_const.ROTATE_SLICES / 360
	if deltaAngle > 0 then
		start = math.floor(startAngle * stepAngle) * 3
		local totalAngle = startAngle + deltaAngle
		if totalAngle > 360 then
			local extraAngle = (totalAngle - 360)
			deltaAngle = deltaAngle - extraAngle
			rotAxis.eid[4].render_object.ib.start = 0
			rotAxis.eid[4].render_object.ib.num = math.floor(extraAngle * stepAngle) * 3
		end
		num = math.floor(deltaAngle * stepAngle + 1) * 3
	else
		local extraAngle = startAngle + deltaAngle
		if extraAngle < 0 then
			start = 0
			num = math.floor(startAngle * stepAngle) * 3
			rotAxis.eid[4].render_object.ib.start = math.floor((360 + extraAngle) * stepAngle) * 3
			rotAxis.eid[4].render_object.ib.num = math.floor(-extraAngle * stepAngle + 1) * 3
		else
			num = math.floor(-deltaAngle * stepAngle + 1) * 3
			start = math.floor(startAngle * stepAngle) * 3 - num
			if start < 0 then
				num = num + start
				start = 0
			end
		end
	end
	rotAxis.eid[3].render_object.ib.start = start
	rotAxis.eid[3].render_object.ib.num = num

	ifs.set_state(rotAxis.eid[3], "main_view", rotAxis.eid[3].render_object.ib.num > 0)
	ifs.set_state(rotAxis.eid[4], "main_view", rotAxis.eid[4].render_object.ib.num > 0)
end

local function rotate_gizmo(x, y)
	if not x or not y then return end
	local axis_dir = (rotate_axis ~= gizmo.rw) and gizmo_dir_to_world(rotate_axis.dir) or rotate_axis.dir
	local gizmoPos = iom.get_position(gizmo.root_eid)
	local hitPosVec = mouse_hit_plane({x, y}, {dir = axis_dir, pos = math3d.totable(gizmoPos)})
	if not hitPosVec then
		return
	end
	local gizmo_to_last_hit = math3d.normalize(math3d.sub(last_hit, gizmoPos))
	local tangent = math3d.normalize(math3d.cross(axis_dir, gizmo_to_last_hit))
	local proj_len = math3d.dot(tangent, math3d.sub(hitPosVec, last_hit))
	
	local angleBaseDir = gizmo_dir_to_world(mc.XAXIS)
	if rotate_axis == gizmo.rx then
		angleBaseDir = gizmo_dir_to_world(mc.NZAXIS)
	elseif rotate_axis == gizmo.rw then
		angleBaseDir = math3d.normalize(math3d.cross(mc.YAXIS, axis_dir))
	end
	
	local deltaAngle = proj_len * 200 / gizmo_scale
	if deltaAngle > 360 then
		deltaAngle = deltaAngle - 360
	elseif deltaAngle < -360 then
		deltaAngle = deltaAngle + 360
	end
	if math.abs(deltaAngle) < 0.0001 then
		return
	end
	local tableGizmoToLastHit
	if local_space and rotate_axis ~= gizmo.rw then
		tableGizmoToLastHit = math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(gizmo.root_eid)), gizmo_to_last_hit, 0))
	else
		tableGizmoToLastHit = math3d.totable(gizmo_to_last_hit)
	end
	local isTop  = tableGizmoToLastHit[2] > 0
	if rotate_axis == gizmo.ry then
		isTop = tableGizmoToLastHit[3] > 0
	end
	local angle = math.deg(math.acos(math3d.dot(gizmo_to_last_hit, angleBaseDir)))
	if not isTop then
		angle = 360 - angle
	end

	show_rotate_fan(rotate_axis, angle, (rotate_axis == gizmo.ry) and -deltaAngle or deltaAngle)
	
	local quat = math3d.quaternion { axis = last_rotate_axis, r = math.rad(deltaAngle) }
	
	gizmo:set_rotation(math3d.mul(last_rotate, quat))
	if local_space then
		iom.set_rotation(gizmo.rot_circle_root_eid, quat)
	end
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end

local function scale_gizmo(x, y)
	if not x or not y then return end
	local newScale
	if uniform_scale then
		local delta_x = x - last_mouse_pos[1]
		local delta_y = last_mouse_pos[2] - y
		local factor = (delta_x + delta_y) / 60.0
		local scaleFactor = 1.0
		if factor < 0 then
			scaleFactor = 1 / (1 + math.abs(factor))
		else
			scaleFactor = 1 + factor
		end
		newScale = {last_gizmo_scale[1] * scaleFactor, last_gizmo_scale[2] * scaleFactor, last_gizmo_scale[3] * scaleFactor}
	else
		newScale = {last_gizmo_scale[1], last_gizmo_scale[2], last_gizmo_scale[3]}
		local mc = irq.main_camera()
		local newOffset = utils.view_to_axis_constraint(iom.ray(mc, {x, y}), iom.get_position(mc), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
		local deltaOffset = math3d.totable(math3d.sub(newOffset, init_offset))
		local scaleFactor = (1.0 + 3.0 * math3d.length(deltaOffset))
		if move_axis.dir == gizmo_const.DIR_X then
			if deltaOffset[1] < 0 then
				newScale[1] = last_gizmo_scale[1] / scaleFactor
			else
				newScale[1] = last_gizmo_scale[1] * scaleFactor
			end
		elseif move_axis.dir == gizmo_const.DIR_Y then
			if deltaOffset[2] < 0 then
				newScale[2] = last_gizmo_scale[2] / scaleFactor
			else
				newScale[2] = last_gizmo_scale[2] * scaleFactor
			end
			
		elseif move_axis.dir == gizmo_const.DIR_Z then
			if deltaOffset[3] < 0 then
				newScale[3] = last_gizmo_scale[3] / scaleFactor
			else
				newScale[3] = last_gizmo_scale[3] * scaleFactor
			end
		end

	end
	gizmo:set_scale(newScale)
	is_tran_dirty = true
	world:pub {"Gizmo", "update"}
end

local function select_light_gizmo(x, y)
	light_gizmo_mode = 0
	if not light_gizmo.current_light then return light_gizmo_mode end

	local function hit_test_circle(axis, radius, pos)
		local gizmoPos = pos or iom.get_position(light_gizmo.current_light)
		local hitPosVec = mouse_hit_plane({x, y}, {dir = axis, pos = math3d.totable(gizmoPos)})
		if not hitPosVec then
			return
		end
		local dist = math3d.length(math3d.sub(gizmoPos, hitPosVec))
		local highlight = math.abs(dist - radius) < gizmo_const.ROTATE_HIT_RADIUS * 3
		light_gizmo.highlight(highlight)
		return highlight
	end
	
	click_dir_point_light = nil
	click_dir_spot_light = nil
	if not light_gizmo.current_light.light then
		w:sync("light:in", light_gizmo.current_light)
	end
	local radius = ilight.range(light_gizmo.current_light)
	if light_gizmo.current_light.light.type == "point" then
		if hit_test_circle({1, 0, 0}, radius) then
			click_dir_point_light = {1, 0, 0}
			light_gizmo_mode = 1
		elseif hit_test_circle({0, 1, 0}, radius) then
			click_dir_point_light = {0, 1, 0}
			light_gizmo_mode = 2
		elseif hit_test_circle({0, 0, 1}, radius) then
			click_dir_point_light = {0, 0, 1}
			light_gizmo_mode = 3
		end
	elseif light_gizmo.current_light.light.type == "spot" then
		local dir = math3d.totable(math3d.transform(iom.get_rotation(light_gizmo.current_light), mc.ZAXIS, 0))
		local mat = iom.worldmat(light_gizmo.current_light)
		local centre = math3d.transform(mat, math3d.vector{0, 0, ilight.range(light_gizmo.current_light)}, 1)
		if hit_test_circle(dir, ilight.inner_radian(light_gizmo.current_light), centre) then
			click_dir_spot_light = dir
			light_gizmo_mode = 4
		else
			local vpmat = icamera.calc_viewproj(irq.main_camera())
			local mqvr = irq.view_rect "main_queue"
			local sp1 = mu.world_to_screen(vpmat, mqvr, iom.get_position(light_gizmo.current_light))
			local sp2 = mu.world_to_screen(vpmat, mqvr, centre)
			local sx, sy = igui.cvt2scenept(x, y)

			if mu.pt2d_line_distance(sp1, sp2, math3d.vector(sx, sy, 0.0)) < 5.0 then
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
	if not x or not y then return false end
	if self.mode == gizmo_const.MOVE or self.mode == gizmo_const.ROTATE then
		last_mouse_pos = {x, y}
		local mode = select_light_gizmo(x, y)
		if mode ~= 0 then
			if mode == 5 then
				last_spot_range = ilight.range(light_gizmo.current_light)
				last_gizmo_pos = math3d.totable(iom.get_position(light_gizmo.current_light))
				local mat = iom.worldmat(light_gizmo.current_light)
				local circle_centre = math3d.transform(mat, math3d.vector{0, 0, ilight.range(light_gizmo.current_light)}, 1)
				local move_dir = math3d.sub(circle_centre, iom.get_position(light_gizmo.current_light))
				local mc = irq.main_camera()
				init_offset.v = utils.view_to_axis_constraint(iom.ray(mc, {x, y}), iom.get_position(mc), gizmo_dir_to_world(move_dir), last_gizmo_pos)
			end
			return true
		end
	end
	if self.mode == gizmo_const.MOVE or self.mode == gizmo_const.SCALE then
		move_axis = select_axis(x, y)
		gizmo:highlight_axis_or_plane(move_axis)
		if move_axis or uniform_scale then
			last_mouse_pos = {x, y}
			last_gizmo_scale = math3d.totable(iom.get_scale(gizmo.target_eid))
			if move_axis then
				last_gizmo_pos = math3d.totable(iom.get_position(gizmo.root_eid))
				local mc = irq.main_camera()
				init_offset.v = utils.view_to_axis_constraint(iom.ray(mc, {x, y}), iom.get_position(mc), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
			end
			return true
		end
	elseif self.mode == gizmo_const.ROTATE then
		rotate_axis, last_hit.v = select_rotate_axis(x, y)
		if rotate_axis then
			last_rotate.q = iom.get_rotation(gizmo.target_eid)
			if rotate_axis == gizmo.rw or not local_space then
				last_rotate_axis.v = math3d.transform(math3d.inverse(iom.get_rotation(gizmo.target_eid)), rotate_axis.dir, 0)
			else
				last_rotate_axis.v = rotate_axis.dir
			end
			return true
		end
	end
	return false
end

local keypress_mb = world:sub{"keyboard"}
local prefab_mgr  = ecs.require "prefab_manager"
local function on_mouse_move()
	if not global_data.mouse_move or gizmo_seleted or gizmo.mode == gizmo_const.SELECT then return end
	local mx, my = global_data.mouse_pos_x, global_data.mouse_pos_y
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

local gizmo_event = world:sub{"Gizmo"}

function gizmo_sys:handle_event()
	for _, what, wp in gizmo_event:unpack() do
		if what == "updateposition" then
			gizmo:update_position(wp)
		elseif what == "ontarget" then
			gizmo:update()
		end
	end

	for _ in camera_zoom:unpack() do
		gizmo:update_scale()
	end

	for _, what, value in gizmo_mode_event:unpack() do
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

	for _, what, x, y in mouse_down:unpack() do
		if what == "LEFT" then
			gizmo_seleted = gizmo:select_gizmo(x, y)
			
			gizmo:click_axis_or_plane(move_axis)
			gizmo:click_axis(rotate_axis)
		elseif what == "MIDDLE" then
		end
	end

	for _, what, x, y in mouse_up:unpack() do
		if what == "LEFT" then
			gizmo:reset_move_axis_color()
			if gizmo.mode == gizmo_const.ROTATE then
				--gizmo:hide_rotate_fan()
				if local_space then
					if gizmo.target_eid then
						iom.set_rotation(gizmo.root_eid, iom.get_rotation(gizmo.target_eid))
					end
					iom.set_rotation(gizmo.rot_circle_root_eid, mc.IDENTITY_QUAT)
				end
			end
			gizmo_seleted = false
			light_gizmo_mode = 0
			if is_tran_dirty then
				is_tran_dirty = false
				local target = gizmo.target_eid
				if target then
					if gizmo.mode == gizmo_const.SCALE then
						cmd_queue:record({action = gizmo_const.SCALE, eid = target, oldvalue = last_gizmo_scale, newvalue = math3d.totable(iom.get_scale(target))})
					elseif gizmo.mode == gizmo_const.ROTATE then
						cmd_queue:record({action = gizmo_const.ROTATE, eid = target, oldvalue = math3d.totable(last_rotate), newvalue = math3d.totable(iom.get_rotation(target))})
					elseif gizmo.mode == gizmo_const.MOVE then
						local parent
						if not gizmo.target_eid.scene then
							w:sync("scene:in", gizmo.target_eid)
							parent = gizmo.target_eid.scene.parent
						end

						local pw = parent and iom.worldmat(parent) or nil
						local localPos = last_gizmo_pos
						if pw then
							localPos = math3d.totable(math3d.transform(math3d.inverse(pw), last_gizmo_pos, 1))
						end
						cmd_queue:record({action = gizmo_const.MOVE, eid = target, oldvalue = localPos, newvalue = math3d.totable(iom.get_position(target))})
					end
				end
			end
		elseif what == "RIGHT" then
			gizmo:update_axis_plane()
		end
	end
	
	on_mouse_move()
	
	for _, what, x, y, dx, dy in mouse_drag:unpack() do
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
			end
		elseif what == "RIGHT" then
			gizmo:update_scale()
			gizmo:updata_uniform_scale()
		end
	end
	
	for _,pick_id in pickup_mb:unpack() do
		local eid = pick_id
		if eid then
			if gizmo.mode ~= gizmo_const.SELECT and not gizmo_seleted then
				gizmo:set_target(prefab_mgr:find_entity(eid))
			end
		else
			if not gizmo_seleted and not camera_mgr.select_frustum then
				local vx, vy = igui.cvt2scenept(global_data.mouse_pos_x, global_data.mouse_pos_y)
				if vx and vy then
					gizmo:set_target(nil)
				end
			end
		end
	end
	for _, key, press, state in keypress_mb:unpack() do
		if state.CTRL then
			if key == "Z" then
				if press == 1 then
					cmd_queue:undo()
				end
			elseif key == "Y" then
				if press == 1 then
					cmd_queue:redo()
				end
			end
		end
	end
end
