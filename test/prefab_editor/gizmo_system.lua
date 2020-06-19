local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local rhwi = import_package 'ant.render'.hwi
local assetmgr  = import_package "ant.asset"
local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local iwd = world:interface "ant.render|iwidget_drawer"
local computil = world:interface "ant.render|entity"
local gizmo_sys = ecs.system "gizmo_system"
local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera
local camera_motion = world:interface "ant.objcontroller|camera_motion"
local ies = world:interface "ant.scene|ientity_state"

local gizmo_scale = 1.0
local axis_radius = 0.2
local move_axis
local rotate_axis
local scale_axis
local SELECT = 0
local MOVE = 1
local ROTATE = 2
local SCALE = 3

local gizmo_obj = {
	mode = SELECT,
	position = {0,0,0},
	highlight = world.component "vector" {1, 1, 0, 1},
	tx = {dir = {1, 0, 0}, color = world.component "vector" {1, 0, 0, 1}},
	ty = {dir = {0, 1, 0}, color = world.component "vector" {0, 1, 0, 1}},
	tz = {dir = {0, 0, 1}, color = world.component "vector" {0, 0, 1, 1}},

	rx = {dir = {1, 0, 0}, color = world.component "vector" {1, 0, 0, 1}},
	ry = {dir = {0, 1, 0}, color = world.component "vector" {0, 1, 0, 1}},
	rz = {dir = {0, 0, 1}, color = world.component "vector" {0, 0, 1, 1}},
}


local function showMoveGizmo(show)
	ies.set_state(gizmo_obj.tx.eid[1], "visible", show)
	ies.set_state(gizmo_obj.tx.eid[2], "visible", show)
	ies.set_state(gizmo_obj.ty.eid[1], "visible", show)
	ies.set_state(gizmo_obj.ty.eid[2], "visible", show)
	ies.set_state(gizmo_obj.tz.eid[1], "visible", show)
	ies.set_state(gizmo_obj.tz.eid[2], "visible", show)
end

local function showRotateGizmo(show)
	ies.set_state(gizmo_obj.rx.eid, "visible", show)
	ies.set_state(gizmo_obj.ry.eid, "visible", show)
	ies.set_state(gizmo_obj.rz.eid, "visible", show)
end

local function showScaleGizmo(show)

end

local function showGizmoByState(show)
	if show and not gizmo_obj.target_eid then
		return
	end
	if gizmo_obj.mode == MOVE then
		showMoveGizmo(show)
	elseif gizmo_obj.mode == ROTATE then
		showRotateGizmo(show)
	elseif gizmo_obj.mode == SCALE then
		showScaleGizmo(show)
	else
		showMoveGizmo(false)
		showRotateGizmo(false)
		showScaleGizmo(false)
	end
end

local function onGizmoMode(mode)
	showGizmoByState(false)
	gizmo_obj.mode = mode
	showGizmoByState(true)
end

local imaterial = world:interface "ant.asset|imaterial"

local function resetAxisColor()
	imaterial.set_property(gizmo_obj.tx.eid[1], "u_color", gizmo_obj.tx.color)
	imaterial.set_property(gizmo_obj.tx.eid[2], "u_color", gizmo_obj.tx.color)
	imaterial.set_property(gizmo_obj.ty.eid[1], "u_color", gizmo_obj.ty.color)
	imaterial.set_property(gizmo_obj.ty.eid[2], "u_color", gizmo_obj.ty.color)
	imaterial.set_property(gizmo_obj.tz.eid[1], "u_color", gizmo_obj.tz.color)
	imaterial.set_property(gizmo_obj.tz.eid[2], "u_color", gizmo_obj.tz.color)
end

function gizmo_sys:init()
	-- local cubeid = world:create_entity {
	-- 	policy = {
	-- 		"ant.render|render",
	-- 		"ant.general|name",
	-- 		"ant.objcontroller|select",
	-- 	},
	-- 	data = {
	-- 		scene_entity = true,
	--		state = ies.create_state "visible|selectable",
	-- 		transform =  {
	-- 			srt= world.component "srt" {
	-- 				s={100},
	-- 				t={0, 2, 0, 0}
	-- 			}
	-- 		},
	-- 		material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
	-- 		mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
	-- 		name = "test_cube",
	-- 	}
	-- }
	--world:set(cubeid, "material", {properties={u_color=world.component "vector"{1, 1, 1, 1}}})

	-- local rooteid = world:create_entity {
	-- 	policy = {
	-- 		"ant.scene|transform_policy",
	-- 		"ant.general|name",
	-- 	},
	-- 	data = {
	-- 		transform =  {
	-- 			srt = world.component "srt" {
	-- 				t = {0, 0, 3, 1}
	-- 			}
	-- 		},
	-- 		name = "mesh_root",
	-- 		scene_entity = true,
	-- 	}
	-- }
	-- -- world:instance("/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab", {import={root=rooteid}})

    -- -- computil.create_plane_entity(
	-- -- 	{t = {0, 0, 0, 1}, s = {50, 1, 50, 0}},
	-- -- 	"/pkg/ant.resources/materials/mesh_shadow.material",
	-- -- 	{0.8, 0.8, 0.8, 1},
	-- -- 	"test shadow plane"
	-- -- )
end


local function create_arrow_widget(axis_root, axis_str)
	local cylinder_len = 0.1
	local cylinder_halflen = 0.1
	local cone_raw_halflen = 0.1

	local cone_t
	local cylindere_t
	local local_rotator
	if axis_str == "x" then
		cone_t = math3d.add(math3d.vector(cylinder_len, 0, 0), math3d.vector(cone_raw_halflen, 0, 0))
		local_rotator = math3d.quaternion{0, 0, math.rad(-90)}
		cylindere_t = math3d.vector(cylinder_halflen, 0, 0)
	elseif axis_str == "y" then
		cone_t = math3d.add(math3d.vector(0, cylinder_len, 0), math3d.vector(0, cone_raw_halflen, 0))
		local_rotator = math3d.quaternion{0, 0, 0}
		cylindere_t = math3d.vector(0, cylinder_halflen, 0)
	elseif axis_str == "z" then
		cone_t = math3d.add(math3d.vector(0, 0, cylinder_len), math3d.vector(0, 0, cone_raw_halflen))
		local_rotator = math3d.quaternion{math.rad(90), 0, 0}
		cylindere_t = math3d.vector(0, 0, cylinder_halflen)
	end
	local cylindereid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
			--"ant.objcontroller|select",
		},
		data = {
			scene_entity = true,
			--state = ies.create_state "visible|selectable",
			state = ies.create_state "visible",
			transform =  {
				srt = world.component "srt" {
					s = math3d.ref(math3d.vector(0.2, 10, 0.2)),
					r = local_rotator,
					t = cylindere_t,
				},
			},
			material = world.component "resource" "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder" .. axis_str
		},
		action = {
            mount = axis_root,
		},
	}

	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
			--"ant.objcontroller|select",
		},
		data = {
			scene_entity = true,
			--state = ies.create_state "visible|selectable",
			state = ies.create_state "visible",
			transform =  {srt=world.component "srt"{s = {1, 1.5, 1, 0}, r = local_rotator, t = cone_t}},
			material = world.component "resource" "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone" .. axis_str
		},
		action = {
            mount = axis_root,
		},
	}

	if axis_str == "x" then
		gizmo_obj.tx.eid = {cylindereid, coneeid}
	elseif axis_str == "y" then
		gizmo_obj.ty.eid = {cylindereid, coneeid}
	elseif axis_str == "z" then
		gizmo_obj.tz.eid = {cylindereid, coneeid}
	end
end

function gizmo_sys:post_init()
	local cubeid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
			"ant.objcontroller|select",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible|selectable",
			transform =  {
				srt= world.component "srt" {
					s={50},
					t={0, 0.5, 1, 0}
				}
			},
			material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
			mesh = world.component "resource" "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
			name = "test_cube",
		}
	}

	local coneeid = world:create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
			"ant.objcontroller|select",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible|selectable",
			transform =  {
				srt= world.component "srt" {
					s={50},
					t={-1, 0.5, 0}
				}
			},
			material = world.component "resource" "/pkg/ant.resources/materials/singlecolor.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "test_cone"
		},
	}

	imaterial.set_property(coneeid, "u_color", world.component "vector" {0, 0.5, 0.5, 1})
	local srt = {s = {1}, r = math3d.quaternion{0, 0, 0}, t = {0,0,0,1}}
	local axis_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform =  {srt= world.component "srt"(srt)},
			name = "axis root",
		},
	}

	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	resetAxisColor()
	 
	local rot_eid = computil.create_circle_entity(axis_radius, 72, {t = {0, 0, 0, 1}, r = math3d.tovalue(math3d.quaternion{0, 0, math.rad(90)})}, "rotate_gizmo_x")
	imaterial.set_property(rot_eid, "u_color", world.component "vector" {1, 0, 0, 1})
	world[rot_eid].parent = axis_root
	gizmo_obj.rx.eid = rot_eid

	rot_eid = computil.create_circle_entity(axis_radius, 72, {t = {0, 0, 0, 1}}, "rotate_gizmo_y")
	imaterial.set_property(rot_eid, "u_color", world.component "vector" {0, 1, 0, 1})
	world[rot_eid].parent = axis_root
	gizmo_obj.ry.eid = rot_eid

	rot_eid = computil.create_circle_entity(axis_radius, 72, {t = {0, 0, 0, 1}, r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})}, "rotate_gizmo_z")
	imaterial.set_property(rot_eid, "u_color", world.component "vector" {0, 0, 1, 1})
	world[rot_eid].parent = axis_root
	gizmo_obj.rz.eid = rot_eid
	showGizmoByState(false)
	gizmo_obj.root = world[axis_root]
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}

local function isGizmo(eid)
	if eid == gizmo_obj.tx.eid[1] or eid == gizmo_obj.tx.eid[2] then
		return true
	elseif eid == gizmo_obj.ty.eid[1] or eid == gizmo_obj.ty.eid[2] then
		return true
	elseif eid == gizmo_obj.tz.eid[1] or eid == gizmo_obj.tz.eid[2] then
		return true
	else
		return false
	end
end

local function worldToScreen(world_pos)
	local camera = camerautil.main_queue_camera(world)
	local vp = mu.view_proj(camera)
	local proj_pos = math3d.totable(math3d.transform(vp, world_pos, 1))
	local sw, sh = rhwi.screen_size()
	return {(1 + proj_pos[1] / proj_pos[4]) * sw * 0.5, (1 - proj_pos[2] / proj_pos[4]) * sh * 0.5, 0}
end

local function pointToLineDistance2D(p1, p2, p3)
	local dx = p2[1] - p1[1];
	local dy = p2[2] - p1[2];
	if (dx + dy == 0) then
		return math.sqrt((p3[1] - p1[1]) * (p3[1] - p1[1]) + (p3[2] - p1[2]) * (p3[2] - p1[2]));
	end
	local u = ((p3[1] - p1[1]) * dx + (p3[2] - p1[2]) * dy) / (dx * dx + dy * dy);
	if u < 0 then
		return math.sqrt((p3[1] - p1[1]) * (p3[1] - p1[1]) + (p3[2] - p1[2]) * (p3[2] - p1[2]));
	elseif u > 1 then
		return math.sqrt((p3[1] - p2[1]) * (p3[1] - p2[1]) + (p3[2] - p2[2]) * (p3[2] - p2[2]));
	else
		local x = p1[1] + u * dx;
		local y = p1[2] + u * dy;
		return math.sqrt((p3[1] - x) * (p3[1] - x) + (p3[2] - y) * (p3[2] - y));
	end
end

local function viewToAxisConstraint(point, axis, origin)
	local q = world:singleton_entity("main_queue")
	local ray = camera_motion.ray(q.camera_eid, point)
	local raySrc = math3d.vector(ray.origin[1], ray.origin[2], ray.origin[3])
	local camera = camerautil.main_queue_camera(world)
	local cameraPos = camera.eyepos

	-- find plane between camera and initial position and direction
	--local cameraToOrigin = math3d.sub(cameraPos - math3d.vector(origin[1], origin[2], origin[3]))
	local cameraToOrigin = math3d.vector(cameraPos[1] - origin[1], cameraPos[2] - origin[2], cameraPos[3] - origin[3])
	local axisVec = math3d.vector(axis[1], axis[2], axis[3])
	local lineViewPlane = math3d.normalize(math3d.cross(cameraToOrigin, axisVec))

	-- Now we project the ray from origin to the source point to the screen space line plane
	local cameraToSrc = math3d.normalize(math3d.sub(raySrc, cameraPos))

	local perpPlane = math3d.cross(cameraToSrc, lineViewPlane)

	-- finally, project along the axis to perpPlane
	local factor = (math3d.dot(perpPlane, cameraToOrigin) / math3d.dot(perpPlane, axisVec))
	return math3d.totable(math3d.mul(factor, axisVec))
end

local rotateHitRadius = 0.02
local moveHitRadiusPixel = 10
local function selectAxis(x, y)
	if not gizmo_obj.target_eid then
		return
	end
	local hp = {x, y, 0}
	local highlight = world.component "vector" {1, 1, 0, 1}
	resetAxisColor()

	local start = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3]))
	local end_x = worldToScreen(math3d.vector(gizmo_obj.position[1] + axis_radius * gizmo_scale, gizmo_obj.position[2], gizmo_obj.position[3]))
	
	local ret = pointToLineDistance2D(start, end_x, hp)
	if ret < moveHitRadiusPixel then
		imaterial.set_property(gizmo_obj.tx.eid[1], "u_color", highlight)
		imaterial.set_property(gizmo_obj.tx.eid[2], "u_color", highlight)
		return gizmo_obj.tx
	end

	local end_y = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2] + axis_radius * gizmo_scale, gizmo_obj.position[3]))
	ret = pointToLineDistance2D(start, end_y, hp)
	if ret < moveHitRadiusPixel then
		imaterial.set_property(gizmo_obj.ty.eid[1], "u_color", highlight)
		imaterial.set_property(gizmo_obj.ty.eid[2], "u_color", highlight)
		return gizmo_obj.ty
	end

	local end_z = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3] + axis_radius * gizmo_scale))
	ret = pointToLineDistance2D(start, end_z, hp)
	if ret < moveHitRadiusPixel then
		imaterial.set_property(gizmo_obj.tz.eid[1], "u_color", highlight)
		imaterial.set_property(gizmo_obj.tz.eid[2], "u_color", highlight)
		return gizmo_obj.tz
	end
	return nil
end

local function updateGizmoScale()
	local camera = camerautil.main_queue_camera(world)
	local gizmo_dist = math3d.length(math3d.sub(camera.eyepos, math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3])))
	gizmo_scale = gizmo_dist * 0.6
	gizmo_obj.root.transform.srt.s = math3d.vector(gizmo_scale, gizmo_scale, gizmo_scale)
end

local function distanceBetweenLines(p1, dir1, p2, dir2)
	local cross = math3d.cross(math3d.vector(dir2[1], dir2[2], dir2[3]), math3d.vector(dir1[1], dir1[2], dir1[3]))
	return math3d.dot(cross, math3d.sub(math3d.vector(p2[1], p2[2], p2[3]), math3d.vector(p1[1], p1[2], p1[3])))
end

local function rayHitPlane(ray, plane)
	local rayOriginVec = math3d.vector(ray.origin[1], ray.origin[2], ray.origin[3])
	local rayDirVec = math3d.vector(ray.dir[1], ray.dir[2], ray.dir[3])
	local planeDirVec = math3d.vector(plane.n[1], plane.n[2], plane.n[3])
	
	local d = math3d.dot(planeDirVec, rayDirVec)
	if math.abs(d) > 0.00001 then
		local t = -(math3d.dot(planeDirVec, rayOriginVec) + plane.d) / d
		if t >= 0.0 then
			return t
		end	
	end
	return 0
end

local function selectRotateAxis(x, y)
	if not gizmo_obj.target_eid then
		return
	end
	local q = world:singleton_entity("main_queue")
	local ray = camera_motion.ray(q.camera_eid, {x, y})
	local gizmoPosVec = math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3])
	
	local function hittestRotateAxis(axis)
		local t = rayHitPlane(ray, {n = axis.dir, d = -math3d.dot(math3d.vector(axis.dir[1], axis.dir[2], axis.dir[3]), gizmoPosVec)})
		local hitPosVec = math3d.vector(ray.origin[1] + t * ray.dir[1], ray.origin[2] + t * ray.dir[2], ray.origin[3] + t * ray.dir[3])
		local dist = math3d.length(math3d.sub(gizmoPosVec, hitPosVec))
		if math.abs(dist - gizmo_scale * axis_radius) < rotateHitRadius * gizmo_scale then
			imaterial.set_property(axis.eid, "u_color", gizmo_obj.highlight)
			
			return hitPosVec
		else
			imaterial.set_property(axis.eid, "u_color", axis.color)
			return nil
		end
	end

	local hit = hittestRotateAxis(gizmo_obj.rx)
	if hit then
		return gizmo_obj.rx, hit
	end

	hit = hittestRotateAxis(gizmo_obj.ry)
	if hit then
		return gizmo_obj.ry, hit
	end

	hit = hittestRotateAxis(gizmo_obj.rz)
	if hit then
		return gizmo_obj.rz, hit
	end
end

local cameraZoom = world:sub {"camera", "zoom"}
local mouseDrag = world:sub {"mousedrag"}
local mouseMove = world:sub {"mousemove"}
local mouseDown = world:sub {"mousedown"}
local mouseUp = world:sub {"mouseup"}

local gizmoState = world:sub {"gizmo"}

local lastMousePos
local lastGizmoPos
local initOffset
local function moveGizmo(x, y)
	local newOffset = viewToAxisConstraint({x, y}, move_axis.dir, lastGizmoPos)
	local deltaOffset = {newOffset[1] - initOffset[1], newOffset[2] - initOffset[2], newOffset[3] - initOffset[3]}
	gizmo_obj.position = {
		lastGizmoPos[1] + deltaOffset[1],
		lastGizmoPos[2] + deltaOffset[2],
		lastGizmoPos[3] + deltaOffset[3]
	}
	local new_pos = math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3])
	gizmo_obj.root.transform.srt.t = new_pos
	if gizmo_obj.target_eid then
		world[gizmo_obj.target_eid].transform.srt.t = new_pos
	end
	updateGizmoScale()
end
local lastRotateAxis = math3d.ref()
local lastRotate = math3d.ref()
local lastHit = math3d.ref()
local updateClockwise = false
local clockwise = false
local function rotateGizmo(x, y)

	local q = world:singleton_entity("main_queue")
	local ray = camera_motion.ray(q.camera_eid, {x, y})

	local gizmoPosVec = math3d.vector(gizmo_obj.position)
	local t = rayHitPlane(ray, {n = rotate_axis.dir, d = -math3d.dot(math3d.vector(rotate_axis.dir), gizmoPosVec)})
	local hitPosVec = math3d.vector(ray.origin[1] + t * ray.dir[1], ray.origin[2] + t * ray.dir[2], ray.origin[3] + t * ray.dir[3])
	
	local v0 = math3d.normalize(math3d.sub(lastHit, gizmoPosVec))
	local v1 = math3d.normalize(math3d.sub(hitPosVec, gizmoPosVec))
	local deltaAngle = math.acos(math3d.dot(v0, v1)) * 180 / math.pi
	local dir = math3d.dot(math3d.cross(v0, v1), rotate_axis.dir)

	if updateClockwise then
		updateClockwise = false
		if dir < 0 then
			clockwise = false
		else
			clockwise = true
		end
	end

	if clockwise then
		if dir < 0 then
			deltaAngle = deltaAngle - 360
		else
			deltaAngle = -deltaAngle
		end
	else
		if dir > 0 then
			deltaAngle = 360 - deltaAngle
		end
	end

	local quat
	if rotate_axis == gizmo_obj.rx then
		quat = math3d.quaternion { axis = lastRotateAxis, r = math.rad(-deltaAngle) }
	elseif rotate_axis == gizmo_obj.ry then
		quat = math3d.quaternion { axis = lastRotateAxis, r = math.rad(-deltaAngle) }
	elseif rotate_axis == gizmo_obj.rz then
		quat = math3d.quaternion { axis = lastRotateAxis, r = math.rad(-deltaAngle) }
	end
	
	world[gizmo_obj.target_eid].transform.srt.r = math3d.mul(lastRotate, quat)
end

local function scaleGizmo(x, y)

end
local gizmo_seleted = false
function gizmo_obj:selectGizmo(x, y)
	if self.mode == MOVE then
		move_axis = selectAxis(x, y)
		if move_axis then
			lastGizmoPos = {gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3]}
			lastMousePos = {x, y}
			initOffset = viewToAxisConstraint(lastMousePos, move_axis.dir, lastGizmoPos)
			return true
		end
	elseif self.mode == ROTATE then
		rotate_axis, lastHit.v = selectRotateAxis(x, y)
		if rotate_axis then
			updateClockwise = true
			lastRotateAxis.v = math3d.transform(math3d.inverse(world[gizmo_obj.target_eid].transform.srt.r), rotate_axis.dir, 0)
			lastRotate.q = world[gizmo_obj.target_eid].transform.srt.r
			return true
		end
	elseif self.mode == SCALE then
		return false
	end
	return false
end

function gizmo_sys:data_changed()
	for _ in cameraZoom:unpack() do
		updateGizmoScale()
	end

	for _, what in gizmoState:unpack() do
		if what == "select" then
			onGizmoMode(SELECT)
		elseif what == "rotate" then
			onGizmoMode(ROTATE)
		elseif what == "move" then
			onGizmoMode(MOVE)
		elseif what == "scale" then
			onGizmoMode(SCALE)
		end
	end

	for _, what, x, y in mouseDown:unpack() do
		if what == "LEFT" then
			gizmo_seleted = gizmo_obj:selectGizmo(x, y)
		end
	end

	for _, what, x, y in mouseUp:unpack() do
		if what == "LEFT" then
			gizmo_seleted = false
		end
	end

	for _, what, x, y in mouseMove:unpack() do
		if what == "UNKNOWN" then
			if gizmo_obj.mode == MOVE then
				selectAxis(x, y)
			elseif gizmo_obj.mode == ROTATE then
				selectRotateAxis(x, y)
			end
		end
	end
	
	for _, what, x, y, dx, dy in mouseDrag:unpack() do
		if what == "LEFT" then
			if gizmo_obj.mode == MOVE and move_axis then
				moveGizmo(x, y)
			elseif gizmo_obj.mode == ROTATE and rotate_axis then
				rotateGizmo(x, y)
			elseif gizmo_obj.mode == SCALE and scale_axis then
				scaleGizmo(x, y)
			else
				world:pub { "camera", "pan", dx, dy }
			end
		elseif what == "RIGHT" then
			world:pub { "camera", "rotate", dx, dy }
		end
	end

	for _,pick_id,pick_ids in pickup_mb:unpack() do
        local eid = pick_id
        if eid and world[eid] then
			if gizmo_obj.mode ~= SELECT and gizmo_obj.target_eid ~= eid then
				gizmo_obj.position = math3d.totable(world[eid].transform.srt.t)
				gizmo_obj.root.transform.srt.t = world[eid].transform.srt.t
				gizmo_obj.target_eid = eid
				updateGizmoScale()
				showGizmoByState(true)
			end
		else
			if not gizmo_seleted then
				gizmo_obj.target_eid = nil
				showGizmoByState(false)
			end
		end
	end
end