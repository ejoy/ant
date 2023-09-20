local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util

local icamera	= ecs.require "ant.camera|camera"
local iom 		= ecs.require "ant.objcontroller|obj_motion"
local ivs 		= ecs.require "ant.render|visible_state"
local ientity 	= ecs.require "ant.render|components.entity"
local ilight 	= ecs.require "ant.render|light.light"
local irq		= ecs.require "ant.render|render_system.renderqueue"
local imaterial = ecs.require "ant.asset|material"
local imodifier = ecs.require "ant.modifier|modifier"
local prefab_mgr = ecs.require "prefab_manager"

local cmd_queue = ecs.require "gizmo.command_queue"
local utils 	= ecs.require "mathutils"
local camera_mgr= ecs.require "camera.camera_manager"
local gizmo 	= ecs.require "gizmo.gizmo"
local light_gizmo = ecs.require "gizmo.light"
local inspector = ecs.require "widget.inspector"

local hierarchy = require "hierarchy_edit"
local gizmo_const= require "gizmo.const"

local math3d = require "math3d"

local gizmo_sys = ecs.system "gizmo_system"

local move_axis
local rotate_axis
local uniform_scale = false
local local_space = false

local function cvt2scenept(x, y)
    return x - world.args.viewport.x, y - world.args.viewport.y
end

function gizmo:update()
	self:set_position()
	self:set_rotation()
	self:update_scale()
	self:updata_uniform_scale()
	self:update_axis_plane()
	inspector.update_ui()
end

function gizmo:set_target(eid)
	local target = eid
	if self.target_eid == target then
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
	prefab_mgr:on_patch_tranform(self.target_eid, "s", inscale)
	world:pub {"UpdateAABB", self.target_eid}
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
			local localPos
			if not parent_worldmat then
				localPos = worldpos
			else
				localPos = math3d.transform(math3d.inverse(parent_worldmat), math3d.vector(worldpos), 1)
			end
			iom.set_position(target, localPos)
			local info = hierarchy:get_node_info(self.target_eid)
			local tp = (type(localPos) == "table") and localPos or math3d.tovalue(localPos)
			local t = {tp[1], tp[2], tp[3]}
			info.template.data.scene.t = t
			prefab_mgr:on_patch_tranform(self.target_eid, "t", t)
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
			prefab_mgr:on_patch_tranform(self.target_eid, "r", r)
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
	world:pub {"UpdateAABB", self.target_eid}
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
			visible_state = "",
			scene = {
				s = {0.004, 0.1, 0.004},
				r = local_rotator,
				t = cylindere_t,
				parent = axis_root
			},
			material = "/pkg/ant.resources/materials/singlecolor_nocull.material",
			render_layer = "translucent",
			mesh = '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/Cylinder_P1.meshbin',
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
			visible_state = "",
			scene = {s = {0.02, 0.03, 0.02, 0}, r = local_rotator, t = cone_t, parent = axis_root},
			material = "/pkg/ant.resources/materials/singlecolor_nocull.material",
			render_layer = "translucent",
			mesh = '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/Cone_P1.meshbin',
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

function gizmo_sys:init()

end

local function mouse_hit_plane(screen_pos, plane_info)
	local c <close> = world:entity(irq.main_camera(), "camera:in")
	return utils.ray_hit_plane(iom.ray(c.camera.viewprojmat, screen_pos), plane_info)
end

local function create_global_axes(scene)
	local offset = 0.1
	ientity.create_screen_axis_entity({type = "percent", screen_pos = {offset, 1 - offset}}, scene)
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

local test_bone
function gizmo_sys:post_init()
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
	local uniform_rot_eid = ientity.create_circle_entity(gizmo_const.UNIFORM_ROT_AXIS_LEN, gizmo_const.ROTATE_SLICES, {parent = uniform_rot_root}, gizmo_const.COLOR.GRAY, true)
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
		local line_eid = ientity.create_line_entity({0, 0, 0}, line_end, {parent = rot_circle_root}, axis.color, true)
		local arc = (axis == gizmo.ry) and {start_deg = math.rad(180), end_deg = math.rad(360) } or {start_deg = math.rad(-90), end_deg = math.rad(90) }
		local rot_eid = ientity.create_circle_entity(gizmo_const.AXIS_LEN, gizmo_const.ROTATE_SLICES, {}, axis.color, true, arc)
		local rot_ccw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, {parent = rot_circle_root, s = scene.s, r = scene.r, t = scene.t})
		local rot_cw_mesh_eid = create_rotate_fan(gizmo_const.AXIS_LEN, {parent = rot_circle_root, s = scene.s, r = scene.r, t = scene.t})
		axis.eid = {rot_eid, line_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}
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
				visible_state = "",
				scene = scene or {},
				material = "/pkg/ant.resources/materials/singlecolor_nocull.material",
				mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
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
		local line_eid = ientity.create_line_entity({0, 0, 0}, axis_end, {parent = axis_root}, axis.color, true)
		axis.eid = {cube_eid, line_eid}
	end
	create_scale_axis(gizmo.sx, {gizmo_const.AXIS_LEN, 0, 0})
	create_scale_axis(gizmo.sy, {0, gizmo_const.AXIS_LEN, 0})
	create_scale_axis(gizmo.sz, {0, 0, gizmo_const.AXIS_LEN})
	
    -- ientity.create_grid_entity(64, 64, 1, 1)
	-- test_bone = ientity.create_bone_mesh("testbone", "/pkg/tools.editor/res/materials/joint.material", {s = 5}, gizmo.rz.color, false)
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
	local re <close> = world:entity(gizmo.root_eid)
	local gizmoPosVec = iom.get_position(re)
	local worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_Z))
	local plane_xy = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_Y))
	local plane_zx = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmo_dir_to_world(gizmo_const.DIR_X))
	local plane_yz = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}

	local ce <close> = world:entity(irq.main_camera())
	local eyepos = iom.get_position(ce)

	local project = math3d.sub(eyepos, math3d.mul(plane_xy.n, math3d.dot(plane_xy.n, eyepos) + plane_xy.d))
	local invmat = math3d.inverse(iom.worldmat(re))
	local tp = math3d.totable(math3d.transform(invmat, project, 1))
	local txy <close> = world:entity(self.txy.eid[1])
	iom.set_position(txy, {(tp[1] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (tp[2] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0})
	self.txy.area = (tp[1] > 0) and ((tp[2] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[2] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_zx.n, math3d.dot(plane_zx.n, eyepos) + plane_zx.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	local tzx <close> = world:entity(self.tzx.eid[1])
	iom.set_position(tzx, {(tp[1] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, 0, (tp[3] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
	self.tzx.area = (tp[1] > 0) and ((tp[3] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[3] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_yz.n, math3d.dot(plane_yz.n, eyepos) + plane_yz.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	local tyz <close> = world:entity(self.tyz.eid[1])
	iom.set_position(tyz, {0,(tp[2] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET, (tp[3] > 0) and gizmo_const.MOVE_PLANE_OFFSET or -gizmo_const.MOVE_PLANE_OFFSET})
	self.tyz.area = (tp[3] > 0) and ((tp[2] > 0) and gizmo_const.RIGHT_TOP or gizmo_const.RIGHT_BOTTOM) or (((tp[2] > 0) and gizmo_const.LEFT_TOP or gizmo_const.LEFT_BOTTOM))
end

local pickup_mb = world:sub {"pickup"}

local function select_axis_plane(x, y)
	if gizmo.mode ~= gizmo_const.MOVE then
		return nil
	end
	local function hit_test_axis_plane(axis_plane)
		local e <close> = world:entity(gizmo.root_eid)
		local gizmoPos = iom.get_position(e)
		local hitPosVec = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(axis_plane.dir), pos = math3d.totable(gizmoPos)})
		if hitPosVec then
			return math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(e)), math3d.sub(hitPosVec, gizmoPos), 0))
		end
		return nil
	end
	local planeHitRadius = gizmo.scale * gizmo_const.MOVE_PLANE_HIT_RADIUS * 0.5
	local axis_plane = gizmo.tyz
	local posToGizmo = hit_test_axis_plane(axis_plane)
	
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
	posToGizmo = hit_test_axis_plane(gizmo.txy)
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
	posToGizmo = hit_test_axis_plane(gizmo.tzx)
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

local function world_to_screen(wpos)
	local ce <close> = world:entity(irq.main_camera())
	local vpmat = icamera.calc_viewproj(ce)
	local mqvr = irq.view_rect "main_queue"
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
	local axisPlane = select_axis_plane(x, y)
	if axisPlane then
		return axisPlane
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
		local gizmoPos = iom.get_position(re)
		local axisDir = (axis ~= gizmo.rw) and gizmo_dir_to_world(axis.dir) or axis.dir
		local hitPosVec = mouse_hit_plane({x, y}, {dir = axisDir, pos = math3d.totable(gizmoPos)})
		if not hitPosVec then
			return
		end
		local dist = math3d.length(math3d.sub(gizmoPos, hitPosVec))
		local adjust_axis_len = (axis == gizmo.rw) and gizmo_const.UNIFORM_ROT_AXIS_LEN or gizmo_const.AXIS_LEN
		local a1 <close> = world:entity(axis.eid[1])
		local a2 <close> = world:entity(axis.eid[2])
		if math.abs(dist - gizmo.scale * adjust_axis_len) < gizmo_const.ROTATE_HIT_RADIUS * gizmo.scale then
			local hlcolor = gizmo_const.COLOR.HIGHLIGHT
			set_color(axis.eid[1], hlcolor)
			set_color(axis.eid[2], hlcolor)
			return hitPosVec
		else
			local cc = math3d.vector(axis.color)
			set_color(axis.eid[1], cc)
			set_color(axis.eid[2], cc)
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

local camera_event = world:sub {"camera"}
local mouse_drag = world:sub {"mousedrag"}
local mouse_down = world:sub {"mousedown"}
local mouse_move = world:sub {"mousemove"}
local mouse_up = world:sub {"mouseup"}
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
	local worldPos = last_gizmo_pos
	if move_axis == gizmo.txy or move_axis == gizmo.tyz or move_axis == gizmo.tzx then
		local re <close> = world:entity(gizmo.root_eid)
		local gizmoTPos = math3d.totable(iom.get_position(re))
		local downpos = mouse_hit_plane(last_mouse_pos, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmoTPos})
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(move_axis.dir), pos = gizmoTPos})
		if downpos and curpos then
			worldPos = math3d.add(last_gizmo_pos, math3d.sub(curpos, downpos))
		end
	else
		local ce <close> = world:entity(irq.main_camera(), "camera:in")
		local newOffset = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
		worldPos = math3d.add(last_gizmo_pos, math3d.sub(newOffset, init_offset))
	end
	gizmo:set_position(worldPos)
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
	if light_gizmo_mode == 4 then
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(click_dir_spot_light), pos = math3d.totable(circle_centre)})
		ilight.set_inner_radian(le, math3d.length(math3d.sub(curpos, circle_centre)))
	elseif light_gizmo_mode == 5 then
		local move_dir = math3d.sub(circle_centre, lightPos)
		local ce <close> = world:entity(irq.main_camera(), "camera:in")
		local new_offset = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_dir), last_gizmo_pos)
		local offset = math3d.length(math3d.sub(new_offset, init_offset))
		if math3d.length(math3d.sub(new_offset, lightPos)) < math3d.length(math3d.sub(init_offset, lightPos)) then
			offset = -offset
		end
		ilight.set_range(le, last_spot_range + offset)
	else
		local curpos = mouse_hit_plane({x, y}, {dir = gizmo_dir_to_world(click_dir_point_light), pos = math3d.totable(lightPos)})
		ilight.set_range(le, math3d.length(math3d.sub(curpos, lightPos)))
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
			
			local e4num = math.floor(extra_angle * step_angle) * 3
			ro4.ib_num = e4num
			ivs.set_state(e4, "main_view", e4num > 0)
			ivs.set_state(e4, "selectable", e4num > 0)
		end
		e3_num = math.floor(delta_angle * step_angle + 1) * 3
	else
		local extra_angle = start_angle + delta_angle
		if extra_angle < 0 then
			e3_start = 0
			e3_num = math.floor(start_angle * step_angle) * 3

			local e4start, e4num = math.floor((360 + extra_angle) * step_angle) * 3, math.floor(-extra_angle * step_angle + 1) * 3
			ro4.ib_start, ro4.ib_num = e4start, e4num
			ivs.set_state(e4, "main_view", e4num > 0)
			ivs.set_state(e4, "selectable", e4num > 0)
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

	local e3_visible = e3_num > 0
	ivs.set_state(e3, "main_view", e3_visible)
	ivs.set_state(e3, "selectable", e3_visible)
end

local init_screen_offest = math3d.ref()
local local_angle = 0
local revolutions = 0
local function rotate_gizmo(x, y)
	if not x or not y then return end
	local axis_dir = (rotate_axis ~= gizmo.rw) and gizmo_dir_to_world(rotate_axis.dir) or rotate_axis.dir
	local re <close> = world:entity(gizmo.root_eid)
	local gizmoPos = iom.get_position(re)
	local hitPosVec = mouse_hit_plane({x, y}, {dir = axis_dir, pos = math3d.totable(gizmoPos)})
	if not hitPosVec then
		return
	end
	local gizmo_to_last_hit = math3d.normalize(math3d.sub(last_hit, gizmoPos))
	-- local tangent = math3d.normalize(math3d.cross(axis_dir, gizmo_to_last_hit))
	-- local proj_len = math3d.dot(tangent, math3d.sub(hitPosVec, last_hit))
	
	local angleBaseDir = gizmo_dir_to_world(mc.XAXIS)
	if rotate_axis == gizmo.rx then
		angleBaseDir = gizmo_dir_to_world(mc.NZAXIS)
	elseif rotate_axis == gizmo.rw then
		angleBaseDir = math3d.normalize(math3d.cross(mc.YAXIS, axis_dir))
	end
	
	local init_point = world_to_screen(gizmoPos)
	local screen_vec = math3d.vector{x - math3d.index(init_point, 1), y - math3d.index(init_point, 2), 0}
	local ax = math3d.dot(screen_vec, init_screen_offest)
	local ay = math3d.dot(screen_vec, math3d.vector{-1.0 * math3d.index(init_screen_offest, 2), math3d.index(init_screen_offest, 1), 0})
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
	-- delta_angle = math.fmod(delta_angle, 360)
	if rotate_axis == gizmo.rz or rotate_axis == gizmo.rw then
		delta_angle = -1.0 * delta_angle
	end
	local tableGizmoToLastHit
	if local_space and rotate_axis ~= gizmo.rw then
		tableGizmoToLastHit = math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(re)), gizmo_to_last_hit, 0))
	else
		tableGizmoToLastHit = math3d.totable(gizmo_to_last_hit)
	end
	local isTop  = tableGizmoToLastHit[2] > 0
	if rotate_axis == gizmo.ry then
		isTop = tableGizmoToLastHit[3] > 0
	end
	local fan_angle = math.deg(math.acos(math3d.dot(gizmo_to_last_hit, angleBaseDir)))
	if not isTop then
		fan_angle = 360 - fan_angle
	end

	show_rotate_fan(rotate_axis, fan_angle, (rotate_axis == gizmo.ry) and -delta_angle or delta_angle)
	
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
		local ce <close> = world:entity(irq.main_camera(), "camera:in")
		local newOffset = utils.view_to_axis_constraint(iom.ray(ce.camera.viewprojmat, {x, y}), iom.get_position(ce), gizmo_dir_to_world(move_axis.dir), last_gizmo_pos)
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

	local le <close> = world:entity(light_gizmo.current_light, "light:in")
	local function hit_test_circle(axis, radius, pos)
		local gizmoPos = pos or iom.get_position(le)
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
	local radius = ilight.range(le)
	if le.light.type == "point" then
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
	elseif le.light.type == "spot" then
		local dir = math3d.totable(math3d.transform(iom.get_rotation(le), mc.ZAXIS, 0))
		local mat = iom.worldmat(le)
		local centre = math3d.transform(mat, math3d.vector{0, 0, ilight.range(le)}, 1)
		if hit_test_circle(dir, ilight.inner_radian(le), centre) then
			click_dir_spot_light = dir
			light_gizmo_mode = 4
		else
			if mu.pt2d_line_distance(world_to_screen(iom.get_position(le)), world_to_screen(centre), math3d.vector(x, y, 0.0)) < 5.0 then
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

local keypress_mb = world:sub{"keyboard"}
local look_at_target_mb = world:sub{"LookAtTarget"}
local last_mouse_pos_x = 0
local last_mouse_pos_y = 0
local function on_mouse_move()
	if gizmo_seleted or gizmo.mode == gizmo_const.SELECT then return end
	for _, what, x, y in mouse_move:unpack() do
		x, y = cvt2scenept(x, y)
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
end

local function focus_aabb(ce, aabb)
    local aabb_min, aabb_max= math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
    local center = math3d.mul(0.5, math3d.add(aabb_min, aabb_max))
    local dist = -2.0 * math3d.length(math3d.sub(aabb_max, center))
	local viewdir = iom.get_direction(ce)
    iom.lookto(ce, math3d.muladd(dist, viewdir, center), viewdir)
end

function gizmo_sys:handle_event()
	for _ in camera_event:unpack() do
		gizmo:update_scale()
		gizmo:updata_uniform_scale()
		break
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
		x, y = cvt2scenept(x, y)
		if what == "LEFT" then
			gizmo_seleted = gizmo:select_gizmo(x, y)
			gizmo:click_axis_or_plane(move_axis)
			gizmo:click_axis(rotate_axis)
		elseif what == "MIDDLE" then
		end
	end

	for _, what, x, y in mouse_up:unpack() do
		x, y = cvt2scenept(x, y)
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
						local localPos = last_gizmo_pos
						if pw then
							localPos = math3d.totable(math3d.transform(math3d.inverse(pw), last_gizmo_pos, 1))
						end
						cmd_queue:record({action = gizmo_const.MOVE, eid = target, oldvalue = localPos, newvalue = math3d.totable(iom.get_position(te))})
					end
				end
			end
		elseif what == "RIGHT" then
			gizmo:update_axis_plane()
		end
	end
	
	on_mouse_move()
	
	for _, what, x, y in mouse_drag:unpack() do
		x, y = cvt2scenept(x, y)
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
		end
	end
	
	for _,pick_id in pickup_mb:unpack() do
		local eid = pick_id
		if eid then
			if not gizmo_seleted then
				local teid = hierarchy:get_select_adapter(eid)
				if hierarchy:get_node(teid) then
					gizmo:set_target(teid)
				end
			end
			if imodifier.highlight then
				imodifier.set_target(imodifier.highlight, eid)
                imodifier.start(imodifier.highlight, {})
			end
		else
			if not gizmo_seleted and not camera_mgr.select_frustum then
				if last_mouse_pos_x and last_mouse_pos_y then
					gizmo:set_target(nil)
				end
			end
		end
	end
	for _, key, press, state in keypress_mb:unpack() do
		if state.CTRL then
			if key == "Z" and press == 1 then
				cmd_queue:undo()
			elseif key == "Y" and press == 1 then
				cmd_queue:redo()
			end
		end
	end
	for _, tid, anim in look_at_target_mb:unpack() do
		local target = tid or gizmo.target_eid
		if target then
			local aabb = prefab_mgr:get_world_aabb(target)
			if aabb then
				if anim then
					local aabb_min, aabb_max= math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
					local center = math3d.tovalue(math3d.mul(0.5, math3d.add(aabb_min, aabb_max)))
					world:pub {"SmoothLookAt", { center[1], center[2], center[3] }, 2.0 * math3d.length(math3d.sub(aabb_max, center))}
				else
					local ce <close> = world:entity(irq.main_camera())
					focus_aabb(ce, aabb)
				end
			end
		end
	end
end
