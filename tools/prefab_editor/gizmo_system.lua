local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local rhwi = import_package 'ant.render'.hwi
local mc = import_package "ant.math".constant
local iwd = world:interface "ant.render|iwidget_drawer"
local iss = world:interface "ant.scene|iscenespace"
local computil = world:interface "ant.render|entity"
local gizmo_sys = ecs.system "gizmo_system"
local iom = world:interface "ant.objcontroller|obj_motion"
local ies = world:interface "ant.scene|ientity_state"

local imaterial = world:interface "ant.asset|imaterial"
local queue = require "queue"
local prefab_view = require "prefab_view"
local utils = require "mathutils"
local worldedit = require "worldedit"(world)
local move_axis
local rotate_axis
local uniform_scale = false
local axis_cube_scale <const> = 2.5
local gizmo_scale = 1.0
local axis_len <const> = 0.2
local uniform_rot_axis_len <const> = axis_len + 0.05
local move_plane_scale <const> = 0.08
local move_plane_offset <const> = 0.04
local move_plane_hit_radius <const> = 0.22
local rotate_slices <const> = 72

local SELECT <const> = 0
local MOVE <const> = 1
local ROTATE <const> = 2
local SCALE <const> = 3
local DIR_X   = {1, 0, 0}
local DIR_Y   = {0, 1, 0}
local DIR_Z   = {0, 0, 1}
local COLOR_X = {1, 0, 0, 1}
local COLOR_Y = {0, 1, 0, 1}
local COLOR_Z = {0, 0, 1, 1}
local COLOR_X_ALPHA       = {1, 0, 0, 0.5}
local COLOR_Y_ALPHA       = {0, 1, 0, 0.5}
local COLOR_Z_ALPHA       = {0, 0, 1, 0.5}
local COLOR_GRAY          = {0.5, 0.5, 0.5, 1}
local COLOR_GRAY_ALPHA    = {0.5, 0.5, 0.5, 0.5}

local HIGHTLIGHT_COLOR = {1, 1, 0, 1}
local HIGHTLIGHT_COLOR_ALPHA = {1, 1, 0, 0.5}

local RIGHT_TOP <const> = 0
local RIGHT_BOTTOM <const> = 1
local LEFT_BOTTOM <const> = 2
local LEFT_TOP <const> = 3
local localSpace = false

local global_axis_eid

local current_viewport
local axis_plane_area
local camera_eid
local gizmo = {
    mode = SELECT,
	--move
	tx = {dir = DIR_X, color = COLOR_X},
	ty = {dir = DIR_Y, color = COLOR_Y},
	tz = {dir = DIR_Z, color = COLOR_Z},
	txy = {dir = DIR_Z, color = COLOR_Z_ALPHA, area = right_top},
	tyz = {dir = DIR_X, color = COLOR_X_ALPHA, area = right_top},
	tzx = {dir = DIR_Y, color = COLOR_Y_ALPHA, area = right_top},
	--rotate
	rx = {dir = DIR_X, color = COLOR_X},
	ry = {dir = DIR_Y, color = COLOR_Y},
	rz = {dir = DIR_Z, color = COLOR_Z},
	rw = {dir = DIR_Z, color = COLOR_GRAY},
	--scale
	sx = {dir = DIR_X, color = COLOR_X},
	sy = {dir = DIR_Y, color = COLOR_Y},
	sz = {dir = DIR_Z, color = COLOR_Z},
}

local function highlight_axis(axis)
	imaterial.set_property(axis.eid[1], "u_color", HIGHTLIGHT_COLOR)
	imaterial.set_property(axis.eid[2], "u_color", HIGHTLIGHT_COLOR)
end

local function gray_axis(axis)
	imaterial.set_property(axis.eid[1], "u_color", COLOR_GRAY_ALPHA)
	imaterial.set_property(axis.eid[2], "u_color", COLOR_GRAY_ALPHA)
end

function gizmo:highlight_axis_plane(axis_plane)
	imaterial.set_property(axis_plane.eid[1], "u_color", HIGHTLIGHT_COLOR_ALPHA)
	if axis_plane == self.tyz then
		highlight_axis(self.ty)
		highlight_axis(self.tz)
	elseif axis_plane == self.txy then
		highlight_axis(self.tx)
		highlight_axis(self.ty)
	elseif axis_plane == self.tzx then
		highlight_axis(self.tz)
		highlight_axis(self.tx)
	end
end

function gizmo:highlight_axis_or_plane(axis)
	if not axis then return end

	if axis == self.tyz or axis == self.txy or axis == self.tzx then
		self:highlight_axis_plane(axis)
	else
		highlight_axis(axis)
	end
end

function gizmo:click_axis(axis)
	if not axis then return end

	if self.mode == SCALE then
		if axis == self.sx then
			gray_axis(self.sy)
			gray_axis(self.sz)
		elseif axis == self.sy then
			gray_axis(self.sx)
			gray_axis(self.sz)
		elseif axis == self.sz then
			gray_axis(self.sx)
			gray_axis(self.sy)
		end
	elseif self.mode == ROTATE then
		if axis == self.rx then
			gray_axis(self.ry)
			gray_axis(self.rz)
		elseif axis == self.ry then
			gray_axis(self.rx)
			gray_axis(self.rz)
		elseif axis == self.rz then
			gray_axis(self.rx)
			gray_axis(self.ry)
		elseif axis == self.rw then
			gray_axis(self.rx)
			gray_axis(self.ry)
			gray_axis(self.rz)
		end
	else
		local state = "visible"
		ies.set_state(self.tyz.eid[1], state, false)
		ies.set_state(self.txy.eid[1], state, false)
		ies.set_state(self.tzx.eid[1], state, false)
		if axis == self.tx then
			gray_axis(self.ty)
			gray_axis(self.tz)
		elseif axis == self.ty then
			gray_axis(self.tx)
			gray_axis(self.tz)
		elseif axis == self.tz then
			gray_axis(self.tx)
			gray_axis(self.ty)
		end
	end
end

function gizmo:click_plane(axis)
	local state = "visible"
	if axis == self.tyz then
		gray_axis(self.tx)
		ies.set_state(self.txy.eid[1], state, false)
		ies.set_state(self.tzx.eid[1], state, false)
	elseif axis == self.txy then
		gray_axis(self.tz)
		ies.set_state(self.tyz.eid[1], state, false)
		ies.set_state(self.tzx.eid[1], state, false)
	elseif axis == self.tzx then
		gray_axis(self.ty)
		ies.set_state(self.txy.eid[1], state, false)
		ies.set_state(self.tyz.eid[1], state, false)
	end
end

function gizmo:click_axis_or_plane(axis)
	if not axis then return end

	if axis == self.tyz or axis == self.txy or axis == self.tzx then
		self:click_plane(axis)
	else
		self:click_axis(axis)
	end
end

function gizmo:show_rotate_fan(show)
	local state = "visible"
	ies.set_state(self.rx.eid[3], state, show)
	ies.set_state(self.rx.eid[4], state, show)
	ies.set_state(self.ry.eid[3], state, show)
	ies.set_state(self.ry.eid[4], state, show)
	ies.set_state(self.rz.eid[3], state, show)
	ies.set_state(self.rz.eid[4], state, show)
	ies.set_state(self.rw.eid[3], state, show)
	ies.set_state(self.rw.eid[4], state, show)
	world[self.rx.eid[3]]._rendercache.ib.num = 0
	world[self.rx.eid[4]]._rendercache.ib.num = 0
	world[self.ry.eid[3]]._rendercache.ib.num = 0
	world[self.ry.eid[4]]._rendercache.ib.num = 0
	world[self.rz.eid[3]]._rendercache.ib.num = 0
	world[self.rz.eid[4]]._rendercache.ib.num = 0
	world[self.rw.eid[3]]._rendercache.ib.num = 0
	world[self.rw.eid[4]]._rendercache.ib.num = 0
end

function gizmo:show_move(show)
	local state = "visible"
	ies.set_state(self.tx.eid[1], state, show)
	ies.set_state(self.tx.eid[2], state, show)
	ies.set_state(self.ty.eid[1], state, show)
	ies.set_state(self.ty.eid[2], state, show)
	ies.set_state(self.tz.eid[1], state, show)
	ies.set_state(self.tz.eid[2], state, show)
	--
	ies.set_state(self.txy.eid[1], state, show)
	ies.set_state(self.tyz.eid[1], state, show)
	ies.set_state(self.tzx.eid[1], state, show)
end

function gizmo:show_rotate(show)
	local state = "visible"
	ies.set_state(self.rx.eid[1], state, show)
	ies.set_state(self.rx.eid[2], state, show)
	ies.set_state(self.ry.eid[1], state, show)
	ies.set_state(self.ry.eid[2], state, show)
	ies.set_state(self.rz.eid[1], state, show)
	ies.set_state(self.rz.eid[2], state, show)
	ies.set_state(self.rw.eid[1], state, show)
end

function gizmo:show_scale(show)
	local state = "visible"
	ies.set_state(self.sx.eid[1], state, show)
	ies.set_state(self.sx.eid[2], state, show)
	ies.set_state(self.sy.eid[1], state, show)
	ies.set_state(self.sy.eid[2], state, show)
	ies.set_state(self.sz.eid[1], state, show)
	ies.set_state(self.sz.eid[2], state, show)
	ies.set_state(self.uniform_scale_eid, state, show)
end

function gizmo:show_by_state(show)
	if show and not self.target_eid then
		return
	end
	if self.mode == MOVE then
		self:show_move(show)
	elseif self.mode == ROTATE then
		self:show_rotate(show)
	elseif self.mode == SCALE then
		self:show_scale(show)
	else
		self:show_move(false)
		self:show_rotate(false)
		self:show_scale(false)
	end
end

local cmd_queue = {
	cmd_undo = queue.new(),
	cmd_redo = queue.new()
}
local isTranDirty = false
function cmd_queue:undo()
	local cmd = queue.pop_last(self.cmd_undo)
	if not cmd then return end
	if cmd.action == SCALE then
		iom.set_scale(cmd.eid, cmd.oldvalue)
	elseif cmd.action == ROTATE then
		iom.set_rotation(cmd.eid, cmd.oldvalue)
		if gizmo.mode ~= SELECT and localSpace then
			iom.set_rotation(cmd.eid, cmd.oldvalue)
		end
	elseif cmd.action == MOVE then
		iom.set_position(cmd.eid, cmd.oldvalue)
		if gizmo.mode ~= SELECT then
			iom.set_position(cmd.eid, cmd.oldvalue)
		end
	end
	gizmo:set_position()
	gizmo:set_rotation()
	world:pub {"Gizmo", "update"}
	queue.push_last(self.cmd_redo, cmd)
end

function cmd_queue:redo()
	local cmd = queue.pop_last(self.cmd_redo)
	if not cmd then return end
	if cmd.action == SCALE then
		iom.set_scale(cmd.eid, cmd.newvalue)
	elseif cmd.action == ROTATE then
		iom.set_rotation(cmd.eid, cmd.newvalue)
		if gizmo.mode ~= SELECT and localSpace then
			iom.set_rotation(cmd.eid, cmd.newvalue)
		end
	elseif cmd.action == MOVE then
		iom.set_position(cmd.eid, cmd.newvalue)
		if gizmo.mode ~= SELECT then
			iom.set_position(cmd.eid, cmd.newvalue)
		end
	end
	gizmo:set_position()
	gizmo:set_rotation()
	world:pub {"Gizmo", "update"}
	queue.push_last(self.cmd_undo, cmd)
end

function cmd_queue:record(cmd)
	local redocmd = queue.pop_last(self.cmd_redo)
	while redocmd do
		redocmd = queue.pop_last(self.cmd_redo)
	end
	queue.push_last(self.cmd_undo, cmd)
end

local function showRotateMeshByAxis(show, axis)
	ies.set_state(axis.eid[3], "visible", show)
	ies.set_state(axis.eid[4], "visible", show)
	world[axis.eid[3]]._rendercache.ib.start = 0
	world[axis.eid[4]]._rendercache.ib.start = 0
	world[axis.eid[3]]._rendercache.ib.num = 0
	world[axis.eid[4]]._rendercache.ib.num = 0
end

function gizmo:set_target(eid)
	if self.target_eid == eid then
		return
	end
	self.target_eid = eid
	if eid then
		self:set_position()
		self:set_rotation()
		self:update_scale()
		self:updata_uniform_scale()
		self:update_axis_plane()
	end
	gizmo:show_by_state(eid ~= nil)
	world:pub {"Gizmo","ontarget"}
end

function gizmo:reset_move_axis_color()
	if self.mode ~= MOVE then return end
	local uname = "u_color"
	imaterial.set_property(self.tx.eid[1], uname, self.tx.color)
	imaterial.set_property(self.tx.eid[2], uname, self.tx.color)
	imaterial.set_property(self.ty.eid[1], uname, self.ty.color)
	imaterial.set_property(self.ty.eid[2], uname, self.ty.color)
	imaterial.set_property(self.tz.eid[1], uname, self.tz.color)
	imaterial.set_property(self.tz.eid[2], uname, self.tz.color)
	--plane
	ies.set_state(self.txy.eid[1], "visible", self.target_eid ~= nil)
	ies.set_state(self.tyz.eid[1], "visible", self.target_eid ~= nil)
	ies.set_state(self.tzx.eid[1], "visible", self.target_eid ~= nil)
	imaterial.set_property(self.txy.eid[1], uname, self.txy.color)
	imaterial.set_property(self.tyz.eid[1], uname, self.tyz.color)
	imaterial.set_property(self.tzx.eid[1], uname, self.tzx.color)
end

function gizmo:reset_rotate_axis_color()
	local uname = "u_color"
	imaterial.set_property(self.rx.eid[1], uname, self.rx.color)
	imaterial.set_property(self.rx.eid[2], uname, self.rx.color)
	imaterial.set_property(self.ry.eid[1], uname, self.ry.color)
	imaterial.set_property(self.ry.eid[2], uname, self.ry.color)
	imaterial.set_property(self.rz.eid[1], uname, self.rz.color)
	imaterial.set_property(self.rz.eid[2], uname, self.rz.color)
	imaterial.set_property(self.rw.eid[1], uname, self.rw.color)
end

function gizmo:reset_scale_axis_color()
	local uname = "u_color"
	imaterial.set_property(self.sx.eid[1], uname, self.sx.color)
	imaterial.set_property(self.sx.eid[2], uname, self.sx.color)
	imaterial.set_property(self.sy.eid[1], uname, self.sy.color)
	imaterial.set_property(self.sy.eid[2], uname, self.sy.color)
	imaterial.set_property(self.sz.eid[1], uname, self.sz.color)
	imaterial.set_property(self.sz.eid[2], uname, self.sz.color)
	imaterial.set_property(self.uniform_scale_eid, uname, COLOR_GRAY)
end

function gizmo:updata_uniform_scale()
	if not self.rw.eid[1] then return end
	self.rw.dir = math3d.totable(iom.get_direction(camera_eid))
	--update_camera
	local r = iom.get_rotation(camera_eid)
	-- local s,r,t = math3d.srt(world[cameraeid].transform)
	iom.set_rotation(self.rw.eid[1], r)
	iom.set_rotation(self.rw.eid[3], r)
	iom.set_rotation(self.rw.eid[4], r)
end

function gizmo:set_scale(inscale)
	if not self.target_eid then
		return
	end
	iom.set_scale(self.target_eid, inscale)
end

function gizmo:set_position(worldpos)
	if not self.target_eid then
		return
	end
	local newpos
	if worldpos then
		local localPos = math3d.totable(math3d.transform(math3d.inverse(iom.calc_worldmat(world[gizmo.target_eid].parent)), worldpos, 1))
		iom.set_position(self.target_eid, localPos)
		newpos = worldpos
	else
		local s,r,t = math3d.srt(iom.calc_worldmat(gizmo.target_eid))
		newpos = math3d.totable(t)
	end
	iom.set_position(self.root_eid, newpos)
	iom.set_position(self.uniform_rot_root_eid, newpos)
end

function gizmo:set_rotation(inrot)
	if not self.target_eid then
		return
	end
	local newrot
	if inrot then
		iom.set_rotation(self.target_eid, inrot)
		newrot = inrot
	else
		newrot = iom.get_rotation(self.target_eid)
	end
	if self.mode == SCALE then
		iom.set_rotation(self.root_eid, newrot)
	elseif self.mode == MOVE or self.mode == ROTATE then
		if localSpace then
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
	if axis_str == "x" then
		cone_t = math3d.vector(axis_len, 0, 0)
		local_rotator = math3d.quaternion{0, 0, math.rad(-90)}
		cylindere_t = math3d.vector(0.5 * axis_len, 0, 0)
	elseif axis_str == "y" then
		cone_t = math3d.vector(0, axis_len, 0)
		local_rotator = math3d.quaternion{0, 0, 0}
		cylindere_t = math3d.vector(0, 0.5 * axis_len, 0)
	elseif axis_str == "z" then
		cone_t = math3d.vector(0, 0, axis_len)
		local_rotator = math3d.quaternion{math.rad(90), 0, 0}
		cylindere_t = math3d.vector(0, 0, 0.5 * axis_len)
	end
	local cylindereid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform = {
				s = math3d.ref(math3d.vector(0.2, 10, 0.2)),
				r = local_rotator,
				t = cylindere_t,
			},
			material = "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder" .. axis_str
		}
	}
	iss.set_parent(cylindereid, axis_root)
	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform = {s = {1, 1.5, 1, 0}, r = local_rotator, t = cone_t},
			material = "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone" .. axis_str
		}
	}
	iss.set_parent(coneeid, axis_root)
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

local function mouseHitPlane(screen_pos, plane_info)
	return utils.ray_hit_plane(iom.ray(camera_eid, screen_pos), plane_info)
end

local function updateGlobalAxis()
	if not current_viewport then return end
	local sw, sh = current_viewport.w, current_viewport.h --rhwi.screen_size()
	local worldPos = mouseHitPlane({50, sh - 50}, {dir = {0,1,0}, pos = {0,0,0}})
	if worldPos then
		iom.set_position(global_axis_eid, math3d.totable(worldPos))
	end
	--print("gizmo_scale", gizmo_scale)
	--todo：
	local adjustScale = (gizmo_scale < 4.5) and 4.5 or gizmo_scale
	iom.set_scale(global_axis_eid, adjustScale * 0.5)
end

function gizmo:update_scale()
	local viewdir = iom.get_direction(camera_eid)
	local eyepos = iom.get_position(camera_eid)
	local project_dist = math3d.dot(math3d.normalize(viewdir), math3d.sub(iom.get_position(self.root_eid), eyepos))
	gizmo_scale = project_dist * 0.35
	if self.root_eid then
		iom.set_scale(self.root_eid, gizmo_scale)
	end
	if self.uniform_rot_root_eid then
		iom.set_scale(self.uniform_rot_root_eid, gizmo_scale)
	end
end
local testcylinder
local testcubeid
local testconeeid
function gizmo_sys:post_init()
	camera_eid = world:singleton_entity "main_queue".camera_eid

	local srt = {r = math3d.quaternion{0, 0, 0}, t = {0,0,0,1}}
	local axis_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {},
			name = "axis root",
		},
	}
	gizmo.root_eid = axis_root
	local rot_circle_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = srt,
			name = "rot root",
		},
	}

	iss.set_parent(rot_circle_root, axis_root)
	gizmo.rot_circle_root_eid = rot_circle_root

	local uniform_rot_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = srt,
			name = "rot root",
		},
	}
	gizmo.uniform_rot_root_eid = uniform_rot_root

	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	local plane_xy_eid = computil.create_prim_plane_entity(
		{t = {move_plane_offset, move_plane_offset, 0, 1}, s = {move_plane_scale, 1, move_plane_scale, 0}, r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_xy")
	imaterial.set_property(plane_xy_eid, "u_color", gizmo.txy.color)
	iss.set_parent(plane_xy_eid, axis_root)
	gizmo.txy.eid = {plane_xy_eid, plane_xy_eid}

	plane_yz_eid = computil.create_prim_plane_entity(
		{t = {0, move_plane_offset, move_plane_offset, 1}, s = {move_plane_scale, 1, move_plane_scale, 0}, r = math3d.tovalue(math3d.quaternion{0, 0, math.rad(90)})},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_yz")
	imaterial.set_property(plane_yz_eid, "u_color", gizmo.tyz.color)
	iss.set_parent(plane_yz_eid, axis_root)
	gizmo.tyz.eid = {plane_yz_eid, plane_yz_eid}

	plane_zx_eid = computil.create_prim_plane_entity(
		{t = {move_plane_offset, 0, move_plane_offset, 1}, s = {move_plane_scale, 1, move_plane_scale, 0}},
		"/pkg/ant.resources/materials/t_gizmos.material",
		"plane_zx")
	imaterial.set_property(plane_zx_eid, "u_color", gizmo.tzx.color)
	iss.set_parent(plane_zx_eid, axis_root)
	gizmo.tzx.eid = {plane_zx_eid, plane_zx_eid}
	gizmo:reset_move_axis_color()

	-- roate axis
	local uniform_rot_eid = computil.create_circle_entity(uniform_rot_axis_len, rotate_slices, {}, "rotate_gizmo_uniform")
	imaterial.set_property(uniform_rot_eid, "u_color", COLOR_GRAY)
	iss.set_parent(uniform_rot_eid, uniform_rot_root)
	local function create_rotate_fan(radius, circle_trans)
		local mesh_eid = computil.create_circle_mesh_entity(radius, rotate_slices, circle_trans, "/pkg/ant.resources/materials/t_gizmos.material", "rotate_mesh_gizmo_uniform")
		imaterial.set_property(mesh_eid, "u_color", {0, 0, 1, 0.5})
		ies.set_state(mesh_eid, "visible", false)
		iss.set_parent(mesh_eid, axis_root)
		return mesh_eid
	end
	-- counterclockwise mesh
	local rot_ccw_mesh_eid = create_rotate_fan(uniform_rot_axis_len, {})
	iss.set_parent(rot_ccw_mesh_eid, uniform_rot_root)
	-- clockwise mesh
	local rot_cw_mesh_eid = create_rotate_fan(uniform_rot_axis_len, {})
	iss.set_parent(rot_cw_mesh_eid, uniform_rot_root)
	gizmo.rw.eid = {uniform_rot_eid, uniform_rot_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}

	local function create_rotate_axis(axis, line_end, circle_trans)
		local line_eid = computil.create_line_entity({}, {0, 0, 0}, line_end)
		imaterial.set_property(line_eid, "u_color", axis.color)
		iss.set_parent(line_eid, rot_circle_root)
		local rot_eid = computil.create_circle_entity(axis_len, rotate_slices, circle_trans, "rotate gizmo circle")
		imaterial.set_property(rot_eid, "u_color", axis.color)
		iss.set_parent(rot_eid, rot_circle_root)
		local rot_ccw_mesh_eid = create_rotate_fan(axis_len, circle_trans)
		local rot_cw_mesh_eid = create_rotate_fan(axis_len, circle_trans)
		axis.eid = {rot_eid, line_eid, rot_ccw_mesh_eid, rot_cw_mesh_eid}
	end
	create_rotate_axis(gizmo.rx, {axis_len * 0.5, 0, 0}, {r = math3d.tovalue(math3d.quaternion{0, math.rad(90), 0})})
	create_rotate_axis(gizmo.ry, {0, axis_len * 0.5, 0}, {r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})})
	create_rotate_axis(gizmo.rz, {0, 0, axis_len * 0.5}, {})
	
	-- scale axis
	local function create_scale_cube(srt, color, axis_name)
		local eid = world:create_entity {
			policy = {
				"ant.render|render",
				"ant.general|name",
				"ant.scene|hierarchy_policy",
			},
			data = {
				scene_entity = true,
				state = ies.create_state "visible|selectable",
				transform = srt,
				material = "/pkg/ant.resources/materials/t_gizmos.material",
				mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
				name = "scale_cube" .. axis_name
			}
		}
		-- prefab = worldedit:prefab_template(filename)
    	-- entities = worldedit:prefab_instance(prefab, {root=root})
		-- local eid = world:instance("res/cube.prefab", srt)
		-- worldedit:prefab_set(prefab, "/1/data/ma", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
		-- print("state", world[eid[1]]._rendercache.state)
		-- if srt.t then
		-- 	iom.set_position(eid[1], srt.t)
		-- end
		-- iom.set_scale(eid[1], axis_cube_scale)

		imaterial.set_property(eid, "u_color", color)
		return eid
	end
	-- scale axis cube
	local cube_eid = create_scale_cube({s = axis_cube_scale}, COLOR_GRAY, "uniform scale")
	iss.set_parent(cube_eid, axis_root)
	gizmo.uniform_scale_eid = cube_eid
	local function create_scale_axis(axis, axis_end)
		local cube_eid = create_scale_cube({t = axis_end, s = axis_cube_scale}, axis.color, "scale axis")
		iss.set_parent(cube_eid, axis_root)
		local line_eid = computil.create_line_entity({}, {0, 0, 0}, axis_end)
		imaterial.set_property(line_eid, "u_color", axis.color)
		iss.set_parent(line_eid, axis_root)
		axis.eid = {cube_eid, line_eid}
	end
	create_scale_axis(gizmo.sx, {axis_len, 0, 0})
	create_scale_axis(gizmo.sy, {0, axis_len, 0})
	create_scale_axis(gizmo.sz, {0, 0, axis_len})

	global_axis_eid = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = srt,
			name = "global axis root",
		},
	}

	local new_eid = computil.create_line_entity({}, {0, 0, 0}, {0.1, 0, 0})
	imaterial.set_property(new_eid, "u_color", COLOR_X)
	iss.set_parent(new_eid, global_axis_eid)
	new_eid = computil.create_line_entity({}, {0, 0, 0}, {0, 0.1, 0})
	imaterial.set_property(new_eid, "u_color", COLOR_Y)
	iss.set_parent(new_eid, global_axis_eid)
	new_eid = computil.create_line_entity({}, {0, 0, 0}, {0, 0, 0.1})
	imaterial.set_property(new_eid, "u_color", COLOR_Z)
	iss.set_parent(new_eid, global_axis_eid)
	updateGlobalAxis()
	gizmo:update_scale()
	gizmo:show_by_state(false)
	world:pub {"Gizmo", "create", gizmo, cmd_queue}
end

local function gizmoDirToWorld(localDir)
	if localSpace or (gizmo.mode == SCALE) then
		return math3d.totable(math3d.transform(iom.get_rotation(gizmo.root_eid), localDir, 0))
	else
		return localDir
	end
end

function gizmo:update_axis_plane()
	if self.mode ~= MOVE or not self.target_eid then
		return
	end

	local gizmoPosVec = iom.get_position(self.root_eid)
	local worldDir = math3d.vector(gizmoDirToWorld(DIR_Z))
	local plane_xy = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmoDirToWorld(DIR_Y))
	local plane_zx = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}
	worldDir = math3d.vector(gizmoDirToWorld(DIR_X))
	local plane_yz = {n = worldDir, d = -math3d.dot(worldDir, gizmoPosVec)}

	local eyepos = iom.get_position(camera_eid)

	local project = math3d.sub(eyepos, math3d.mul(plane_xy.n, math3d.dot(plane_xy.n, eyepos) + plane_xy.d))
	local invmat = math3d.inverse(iom.srt(self.root_eid))
	local tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.txy.eid[1], {(tp[1] > 0) and move_plane_offset or -move_plane_offset, (tp[2] > 0) and move_plane_offset or -move_plane_offset, 0})
	self.txy.area = (tp[1] > 0) and ((tp[2] > 0) and RIGHT_TOP or RIGHT_BOTTOM) or (((tp[2] > 0) and LEFT_TOP or LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_zx.n, math3d.dot(plane_zx.n, eyepos) + plane_zx.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.tzx.eid[1], {(tp[1] > 0) and move_plane_offset or -move_plane_offset, 0, (tp[3] > 0) and move_plane_offset or -move_plane_offset})
	self.tzx.area = (tp[1] > 0) and ((tp[3] > 0) and RIGHT_TOP or RIGHT_BOTTOM) or (((tp[3] > 0) and LEFT_TOP or LEFT_BOTTOM))

	project = math3d.sub(eyepos, math3d.mul(plane_yz.n, math3d.dot(plane_yz.n, eyepos) + plane_yz.d))
	tp = math3d.totable(math3d.transform(invmat, project, 1))
	iom.set_position(self.tyz.eid[1], {0,(tp[2] > 0) and move_plane_offset or -move_plane_offset, (tp[3] > 0) and move_plane_offset or -move_plane_offset})
	self.tyz.area = (tp[3] > 0) and ((tp[2] > 0) and RIGHT_TOP or RIGHT_BOTTOM) or (((tp[2] > 0) and LEFT_TOP or LEFT_BOTTOM))
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}

local icamera = world:interface "ant.camera|camera"
local function worldToScreen(world_pos)
	local vp = icamera.calc_viewproj(camera_eid)
	local proj_pos = math3d.totable(math3d.transform(vp, world_pos, 1))
	local sw, sh = current_viewport.w, current_viewport.h --rhwi.screen_size()
	return {(1 + proj_pos[1] / proj_pos[4]) * sw * 0.5, (1 - proj_pos[2] / proj_pos[4]) * sh * 0.5, 0}
end

local rotateHitRadius = 0.02
local moveHitRadiusPixel = 10

local function selectAxisPlane(x, y)
	if gizmo.mode ~= MOVE then
		return nil
	end
	local function hitTestAxixPlane(axis_plane)
		local gizmoPos = iom.get_position(gizmo.root_eid)
		local hitPosVec = mouseHitPlane({x, y}, {dir = gizmoDirToWorld(axis_plane.dir), pos = math3d.totable(gizmoPos)})
		if hitPosVec then
			return math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(gizmo.root_eid)), math3d.sub(hitPosVec, gizmoPos), 0))
		end
		return nil
	end
	local planeHitRadius = gizmo_scale * move_plane_hit_radius * 0.5
	local axis_plane = gizmo.tyz
	local posToGizmo = hitTestAxixPlane(axis_plane)
	
	if posToGizmo then
		if axis_plane.area == RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_TOP then
			posToGizmo[3] = -posToGizmo[3]
		end
		if posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			return axis_plane
		end
	end
	posToGizmo = hitTestAxixPlane(gizmo.txy)
	axis_plane = gizmo.txy
	if posToGizmo then
		if axis_plane.area == RIGHT_BOTTOM then
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[2] = -posToGizmo[2]
		elseif axis_plane.area == LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[2] > 0 and posToGizmo[2] < planeHitRadius then
			return axis_plane
		end
	end
	posToGizmo = hitTestAxixPlane(gizmo.tzx)
	axis_plane = gizmo.tzx
	if posToGizmo then
		if axis_plane.area == RIGHT_BOTTOM then
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == LEFT_BOTTOM then
			posToGizmo[1] = -posToGizmo[1]
			posToGizmo[3] = -posToGizmo[3]
		elseif axis_plane.area == LEFT_TOP then
			posToGizmo[1] = -posToGizmo[1]
		end
		if posToGizmo[1] > 0 and posToGizmo[1] < planeHitRadius and posToGizmo[3] > 0 and posToGizmo[3] < planeHitRadius then
			return axis_plane
		end
	end
	return nil
end

local function selectAxis(x, y)
	if not gizmo.target_eid then
		return
	end
	if gizmo.mode == SCALE then
		gizmo:reset_scale_axis_color()
	elseif gizmo.mode == MOVE then
		gizmo:reset_move_axis_color()
	end
	-- by plane
	local axisPlane = selectAxisPlane(x, y)
	if axisPlane then
		return axisPlane
	end
	
	local gizmo_obj_pos = iom.get_position(gizmo.root_eid)
	local start = worldToScreen(gizmo_obj_pos)
	uniform_scale = false
	-- uniform scale
	local hp = {x, y, 0}
	if gizmo.mode == SCALE then
		local radius = math3d.length(math3d.sub(hp, start))
		if radius < moveHitRadiusPixel then
			uniform_scale = true
			imaterial.set_property(gizmo.uniform_scale_eid, "u_color", HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sx.eid[1], "u_color", HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sx.eid[2], "u_color", HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sy.eid[1], "u_color", HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sy.eid[2], "u_color", HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sz.eid[1], "u_color", HIGHTLIGHT_COLOR)
			imaterial.set_property(gizmo.sz.eid[2], "u_color", HIGHTLIGHT_COLOR)
			return nil
		end
	end
	-- by axis
	local line_len = axis_len * gizmo_scale
	local end_x = worldToScreen(math3d.add(gizmo_obj_pos, math3d.vector(gizmoDirToWorld({line_len, 0, 0}))))
	
	local axis = (gizmo.mode == SCALE) and gizmo.sx or gizmo.tx
	if utils.point_to_line_distance2D(start, end_x, hp) < moveHitRadiusPixel then
		return axis
	end

	local end_y = worldToScreen(math3d.add(gizmo_obj_pos, math3d.vector(gizmoDirToWorld({0, line_len, 0}))))
	axis = (gizmo.mode == SCALE) and gizmo.sy or gizmo.ty
	if utils.point_to_line_distance2D(start, end_y, hp) < moveHitRadiusPixel then
		return axis
	end

	local end_z = worldToScreen(math3d.add(gizmo_obj_pos, math3d.vector(gizmoDirToWorld({0, 0, line_len}))))
	axis = (gizmo.mode == SCALE) and gizmo.sz or gizmo.tz
	if utils.point_to_line_distance2D(start, end_z, hp) < moveHitRadiusPixel then
		return axis
	end
	return nil
end

local function selectRotateAxis(x, y)
	if not gizmo.target_eid then
		return
	end
	gizmo:reset_rotate_axis_color()

	local function hittestRotateAxis(axis)
		local gizmoPos = iom.get_position(gizmo.root_eid)
		local axisDir = (axis ~= gizmo.rw) and gizmoDirToWorld(axis.dir) or axis.dir
		local hitPosVec = mouseHitPlane({x, y}, {dir = axisDir, pos = math3d.totable(gizmoPos)})
		if not hitPosVec then
			return
		end
		local dist = math3d.length(math3d.sub(gizmoPos, hitPosVec))
		local adjust_axis_len = (axis == gizmo.rw) and uniform_rot_axis_len or axis_len
		if math.abs(dist - gizmo_scale * adjust_axis_len) < rotateHitRadius * gizmo_scale then
			imaterial.set_property(axis.eid[1], "u_color", HIGHTLIGHT_COLOR)
			imaterial.set_property(axis.eid[2], "u_color", HIGHTLIGHT_COLOR)
			return hitPosVec
		else
			imaterial.set_property(axis.eid[1], "u_color", axis.color)
			imaterial.set_property(axis.eid[2], "u_color", axis.color)
			return nil
		end
	end

	local hit = hittestRotateAxis(gizmo.rx)
	if hit then
		return gizmo.rx, hit
	end

	hit = hittestRotateAxis(gizmo.ry)
	if hit then
		return gizmo.ry, hit
	end

	hit = hittestRotateAxis(gizmo.rz)
	if hit then
		return gizmo.rz, hit
	end

	hit = hittestRotateAxis(gizmo.rw)
	if hit then
		return gizmo.rw, hit
	end
end

local cameraZoom = world:sub {"camera", "zoom"}
local mouseDrag = world:sub {"mousedrag"}
local mouseMove = world:sub {"mousemove"}
local mouseDown = world:sub {"mousedown"}
local mouseUp = world:sub {"mouseup"}

local gizmoModeEvent = world:sub {"GizmoMode"}

local lastMousePos
local lastGizmoPos
local initOffset = math3d.ref()
local lastGizmoScale

local function moveGizmo(x, y)
	if not gizmo.target_eid then
		return
	end
	local deltaPos
	if move_axis == gizmo.txy or move_axis == gizmo.tyz or move_axis == gizmo.tzx then
		local gizmoTPos = math3d.totable(iom.get_position(gizmo.root_eid))
		local downpos = mouseHitPlane(lastMousePos, {dir = gizmoDirToWorld(move_axis.dir), pos = gizmoTPos})
		local curpos = mouseHitPlane({x, y}, {dir = gizmoDirToWorld(move_axis.dir), pos = gizmoTPos})
		if downpos and curpos then
			local deltapos = math3d.totable(math3d.sub(curpos, downpos))
			deltaPos = {lastGizmoPos[1] + deltapos[1], lastGizmoPos[2] + deltapos[2], lastGizmoPos[3] + deltapos[3]}
		end
	else
		local newOffset = utils.view_to_axis_constraint(iom.ray(camera_eid, {x, y}), iom.get_position(camera_eid), gizmoDirToWorld(move_axis.dir), lastGizmoPos)
		local deltaOffset = math3d.totable(math3d.sub(newOffset, initOffset))
		deltaPos = {lastGizmoPos[1] + deltaOffset[1], lastGizmoPos[2] + deltaOffset[2], lastGizmoPos[3] + deltaOffset[3]}
	end

	gizmo:set_position(deltaPos)
	gizmo:update_scale()
	isTranDirty = true
	world:pub {"Gizmo", "update"}
end

local lastRotateAxis = math3d.ref()
local lastRotate = math3d.ref()
local lastHit = math3d.ref()

local function showRotateFan(rotAxis, startAngle, deltaAngle)
	world[rotAxis.eid[3]]._rendercache.ib.num = 0
	world[rotAxis.eid[4]]._rendercache.ib.num = 0
	local start
	local num
	local stepAngle = rotate_slices / 360
	if deltaAngle > 0 then
		start = math.floor(startAngle * stepAngle) * 3
		local totalAngle = startAngle + deltaAngle
		if totalAngle > 360 then
			local extraAngle = (totalAngle - 360)
			deltaAngle = deltaAngle - extraAngle
			world[rotAxis.eid[4]]._rendercache.ib.start = 0
			world[rotAxis.eid[4]]._rendercache.ib.num = math.floor(extraAngle * stepAngle) * 3
		end
		num = math.floor(deltaAngle * stepAngle + 1) * 3
	else
		local extraAngle = startAngle + deltaAngle
		if extraAngle < 0 then
			start = 0
			num = math.floor(startAngle * stepAngle) * 3
			world[rotAxis.eid[4]]._rendercache.ib.start = math.floor((360 + extraAngle) * stepAngle) * 3
			world[rotAxis.eid[4]]._rendercache.ib.num = math.floor(-extraAngle * stepAngle + 1) * 3
		else
			num = math.floor(-deltaAngle * stepAngle + 1) * 3
			start = math.floor(startAngle * stepAngle) * 3 - num
			if start < 0 then
				num = num + start
				start = 0
			end
		end
	end
	world[rotAxis.eid[3]]._rendercache.ib.start = start
	world[rotAxis.eid[3]]._rendercache.ib.num = num
end

local function rotateGizmo(x, y)
	local axis_dir = (rotate_axis ~= gizmo.rw) and gizmoDirToWorld(rotate_axis.dir) or rotate_axis.dir
	local gizmoPos = iom.get_position(gizmo.root_eid)
	local hitPosVec = mouseHitPlane({x, y}, {dir = axis_dir, pos = math3d.totable(gizmoPos)})
	if not hitPosVec then
		return
	end
	local gizmoToLastHit = math3d.normalize(math3d.sub(lastHit, gizmoPos))
	local tangent = math3d.normalize(math3d.cross(axis_dir, gizmoToLastHit))
	local proj_len = math3d.dot(tangent, math3d.sub(hitPosVec, lastHit))
	
	local angleBaseDir = gizmoDirToWorld(math3d.vector(1, 0, 0))
	if rotate_axis == gizmo.rx then
		angleBaseDir = gizmoDirToWorld(math3d.vector(0, 0, -1))
	elseif rotate_axis == gizmo.rw then
		angleBaseDir = math3d.normalize(math3d.cross(math3d.vector(0, 1, 0), axis_dir))
	end
	
	local deltaAngle = proj_len * 200 / gizmo_scale
	if deltaAngle > 360 then
		deltaAngle = deltaAngle - 360
	elseif deltaAngle < -360 then
		deltaAngle = deltaAngle + 360
	end
	local tableGizmoToLastHit
	if localSpace and rotate_axis ~= gizmo.rw then
		tableGizmoToLastHit = math3d.totable(math3d.transform(math3d.inverse(iom.get_rotation(gizmo.root_eid)), gizmoToLastHit, 0))
	else
		tableGizmoToLastHit = math3d.totable(gizmoToLastHit)
	end
	local isTop  = tableGizmoToLastHit[2] > 0
	if rotate_axis == gizmo.ry then
		isTop = tableGizmoToLastHit[3] > 0
	end
	local angle = math.deg(math.acos(math3d.dot(gizmoToLastHit, angleBaseDir)))
	if not isTop then
		angle = 360 - angle
	end

	showRotateFan(rotate_axis, angle, (rotate_axis == gizmo.ry) and -deltaAngle or deltaAngle)
	
	local quat = math3d.quaternion { axis = lastRotateAxis, r = math.rad(deltaAngle) }
	
	gizmo:set_rotation(math3d.mul(lastRotate, quat))
	if localSpace then
		iom.set_rotation(gizmo.rot_circle_root_eid, quat)
	end
	isTranDirty = true
	world:pub {"Gizmo", "update"}
end

local function scaleGizmo(x, y)
	local newScale
	if uniform_scale then
		local delta_x = x - lastMousePos[1]
		local delta_y = lastMousePos[2] - y
		local factor = (delta_x + delta_y) / 60.0
		local scaleFactor = 1.0
		if factor < 0 then
			scaleFactor = 1 / (1 + math.abs(factor))
		else
			scaleFactor = 1 + factor
		end
		newScale = {lastGizmoScale[1] * scaleFactor, lastGizmoScale[2] * scaleFactor, lastGizmoScale[3] * scaleFactor}
	else
		newScale = {lastGizmoScale[1], lastGizmoScale[2], lastGizmoScale[3]}
		local newOffset = utils.view_to_axis_constraint(iom.ray(camera_eid, {x, y}), iom.get_position(camera_eid), gizmoDirToWorld(move_axis.dir), lastGizmoPos)
		local deltaOffset = math3d.totable(math3d.sub(newOffset, initOffset))
		local scaleFactor = (1.0 + 3.0 * math3d.length(deltaOffset))
		if move_axis.dir == DIR_X then
			if deltaOffset[1] < 0 then
				newScale[1] = lastGizmoScale[1] / scaleFactor
			else
				newScale[1] = lastGizmoScale[1] * scaleFactor
			end
		elseif move_axis.dir == DIR_Y then
			if deltaOffset[2] < 0 then
				newScale[2] = lastGizmoScale[2] / scaleFactor
			else
				newScale[2] = lastGizmoScale[2] * scaleFactor
			end
			
		elseif move_axis.dir == DIR_Z then
			if deltaOffset[3] < 0 then
				newScale[3] = lastGizmoScale[3] / scaleFactor
			else
				newScale[3] = lastGizmoScale[3] * scaleFactor
			end
		end

	end
	gizmo:set_scale(newScale)
	isTranDirty = true
	world:pub {"Gizmo", "update"}
end

local gizmo_seleted = false
function gizmo:selectGizmo(x, y)
	if self.mode == MOVE or self.mode == SCALE then
		move_axis = selectAxis(x, y)
		gizmo:highlight_axis_or_plane(move_axis)
		if move_axis or uniform_scale then
			lastMousePos = {x, y}
			lastGizmoScale = math3d.totable(iom.get_scale(gizmo.target_eid))
			if move_axis then
				lastGizmoPos = math3d.totable(iom.get_position(gizmo.root_eid))
				initOffset.v = utils.view_to_axis_constraint(iom.ray(camera_eid, {x, y}), iom.get_position(camera_eid), gizmoDirToWorld(move_axis.dir), lastGizmoPos)
			end
			return true
		end
	elseif self.mode == ROTATE then
		rotate_axis, lastHit.v = selectRotateAxis(x, y)
		if rotate_axis then
			lastRotate.q = iom.get_rotation(gizmo.target_eid)
			if rotate_axis == gizmo.rw or not localSpace then
				lastRotateAxis.v = math3d.transform(math3d.inverse(iom.get_rotation(gizmo.target_eid)), rotate_axis.dir, 0)
			else
				lastRotateAxis.v = rotate_axis.dir
			end
			showRotateMeshByAxis(true, rotate_axis)
			return true
		end
	end
	return false
end

local keypress_mb = world:sub{"keyboard"}
local viewposEvent = world:sub{"ViewportDirty"}

local function adjust_mouse_pos(x, y)
	return x - current_viewport.x, y - current_viewport.y
end

function gizmo_sys:data_changed()
	for _, vp in viewposEvent:unpack() do
		current_viewport = vp
		updateGlobalAxis()
	end

	for _ in cameraZoom:unpack() do
		gizmo:update_scale()
	end

	for _, what, value in gizmoModeEvent:unpack() do
		if what == "select" then
			gizmo:on_mode(SELECT)
		elseif what == "rotate" then
			gizmo:on_mode(ROTATE)
		elseif what == "move" then
			gizmo:on_mode(MOVE)
		elseif what == "scale" then
			gizmo:on_mode(SCALE)
		elseif what == "localspace" then-- or what == "worldspace" then
			localSpace = value--(what == "localspace")
			gizmo:update_axis_plane()
			gizmo:set_rotation()
		end
	end

	for _, what, x, y in mouseDown:unpack() do
		if what == "LEFT" then
			--print("Down", x, y, adjust_mouse_pos(x, y))
			gizmo_seleted = gizmo:selectGizmo(adjust_mouse_pos(x, y))
			gizmo:click_axis_or_plane(move_axis)
			gizmo:click_axis(rotate_axis)
		elseif what == "MIDDLE" then
			
		end
	end

	for _, what, x, y in mouseUp:unpack() do
		if what == "LEFT" then
			gizmo:reset_move_axis_color()
			if gizmo.mode == ROTATE then
				gizmo:show_rotate_fan(false)
				if localSpace then
					if gizmo.target_eid then
						iom.set_rotation(gizmo.root_eid, iom.get_rotation(gizmo.target_eid))
					end
					iom.set_rotation(gizmo.rot_circle_root_eid, math3d.quaternion{0,0,0})
				end
			end
			gizmo_seleted = false
			if isTranDirty then
				isTranDirty = false
				local target = gizmo.target_eid
				if gizmo.mode == SCALE then
					cmd_queue:record({action = SCALE, eid = target, oldvalue = lastGizmoScale, newvalue = math3d.totable(iom.get_scale(target))})
				elseif gizmo.mode == ROTATE then
					cmd_queue:record({action = ROTATE, eid = target, oldvalue = math3d.totable(lastRotate), newvalue = math3d.totable(iom.get_rotation(target))})
				elseif gizmo.mode == MOVE then
					local localPos = math3d.totable(math3d.transform(math3d.inverse(iom.calc_worldmat(world[target].parent)), lastGizmoPos, 1))
					cmd_queue:record({action = MOVE, eid = target, oldvalue = localPos, newvalue = math3d.totable(iom.get_position(target))})
				end
			end
		elseif what == "RIGHT" then
			gizmo:update_axis_plane()
		end
	end

	for _, what, x, y in mouseMove:unpack() do
		if what == "UNKNOWN" then
			x, y = adjust_mouse_pos(x, y)
			if gizmo.mode == MOVE or gizmo.mode == SCALE then
				local axis = selectAxis(x, y)
				gizmo:highlight_axis_or_plane(axis)
			elseif gizmo.mode == ROTATE then
				selectRotateAxis(x, y)
			end
		end
	end
	
	for _, what, x, y, dx, dy in mouseDrag:unpack() do
		if what == "LEFT" then
			x, y = adjust_mouse_pos(x, y)
			if gizmo.mode == MOVE and move_axis then
				moveGizmo(x, y)
			elseif gizmo.mode == SCALE then
				if move_axis or uniform_scale then
					scaleGizmo(x, y)
				end
			elseif gizmo.mode == ROTATE and rotate_axis then
				rotateGizmo(x, y)
			else
				world:pub { "camera", "pan", dx, dy }
			end
		elseif what == "RIGHT" then
			world:pub { "camera", "rotate", dx, dy }
			gizmo:update_scale()
			gizmo:updata_uniform_scale()
		end
	end
	
	for _,pick_id,pick_ids in pickup_mb:unpack() do
        local eid = pick_id
		if eid and world[eid] then
			if gizmo.mode ~= SELECT then
				gizmo:set_target(eid)
			end
		else
			if not gizmo_seleted then
				gizmo:set_target(nil)
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
	updateGlobalAxis()
end
