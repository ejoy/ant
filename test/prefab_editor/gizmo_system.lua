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

local axis_length = 0.4
local cylinder_cone_ratio = 8
local cylinder_rawradius = 0.2
local selected_axis
local gizmo_obj = {
	position = {0,0,0},
	x = {eid = {}, dir = {1, 0, 0}},
	y = {eid = {}, dir = {0, 1, 0}},
	z = {eid = {}, dir = {0, 0, 1}},
}

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
	-- cube = world[cubeid]
	-- cube.material.properties.u_color = world.component "vector" {1, 1, 1, 1}

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

local ies = world:interface "ant.scene|ientity_state"

local function resetAxisColor()
	local xc = world.component "vector" {1, 0, 0, 1}
	local yc = world.component "vector" {0, 1, 0, 1}
	local zc = world.component "vector" {0, 0, 1, 1}
	world:set(gizmo_obj.x.eid[1], "material", {properties={u_color = xc}})
	world:set(gizmo_obj.x.eid[2], "material", {properties={u_color = xc}})
	world:set(gizmo_obj.y.eid[1], "material", {properties={u_color = yc}})
	world:set(gizmo_obj.y.eid[2], "material", {properties={u_color = yc}})
	world:set(gizmo_obj.z.eid[1], "material", {properties={u_color = zc}})
	world:set(gizmo_obj.z.eid[2], "material", {properties={u_color = zc}})
end

local function create_arrow_widget(axis_root, axis_str)
	--[[
		cylinde & cone
		1. center in (0, 0, 0, 1)
		2. size is 2
		3. pointer to (0, 1, 0)

		we need to:
		1. rotate arrow, make it rotate to (0, 0, 1)
		2. scale cylinder as it match cylinder_cone_ratio
		3. scale cylinder radius
	]]
	local cone_rawlen<const> = 2
	local cone_raw_halflen = cone_rawlen * 0.5
	local cylinder_rawlen = cone_rawlen
	local cylinder_len = cone_rawlen * cylinder_cone_ratio
	local cylinder_halflen = cylinder_len * 0.5
	local cylinder_scaleY = cylinder_len / cylinder_rawlen

	local cylinder_radius = cylinder_rawradius or 0.65

	local cone_raw_centerpos = mc.ZERO_PT
	local cone_centerpos = math3d.add(math3d.add({0, cylinder_len, 0, 1}, cone_raw_centerpos), {0, cone_raw_halflen, 0, 1})
	local cylinder_bottom_pos = math3d.vector(0, 0, 0, 1)
	local cone_top_pos = math3d.add(cone_centerpos, {0, cone_raw_halflen, 0, 1})

	local arrow_center = math3d.add(cylinder_bottom_pos, cone_top_pos)
	local cylinder_raw_centerpos = mc.ZERO_PT
	local cylinder_offset = math3d.sub(cylinder_raw_centerpos, arrow_center)

	local cone_offset = math3d.sub(cone_centerpos, arrow_center)

	local cone_t
	local cylindere_t
	local local_rotator
	--local color
	
	--print("cylinder_halflen", cylinder_halflen)

	if axis_str == "x" then
		cone_t = math3d.ref(math3d.add(math3d.vector(cylinder_len, 0, 0), math3d.vector(cone_raw_halflen, 0, 0)))
		local_rotator = math3d.ref(math3d.quaternion{0, 0, math.rad(-90)})
		cylindere_t = math3d.ref(math3d.vector(cylinder_halflen, 0, 0))
		--color = world.component "vector" {1, 0, 0, 1}
	elseif axis_str == "y" then
		cone_t = math3d.ref(math3d.add(math3d.vector(0, cylinder_len, 0), math3d.vector(0, cone_raw_halflen, 0)))
		local_rotator = math3d.ref(math3d.quaternion{0, 0, 0})
		cylindere_t = math3d.ref(math3d.vector(0, cylinder_halflen, 0))
		--color = world.component "vector" {0, 1, 0, 1}
	elseif axis_str == "z" then
		cone_t = math3d.ref(math3d.add(math3d.vector(0, 0, cylinder_len), math3d.vector(0, 0, cone_raw_halflen)))
		local_rotator = math3d.ref(math3d.quaternion{math.rad(90), 0, 0})
		cylindere_t = math3d.ref(math3d.vector(0, 0, cylinder_halflen))
		--color = world.component "vector" {0, 0, 1, 1}
	end
	local cylindereid = world:create_entity{
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
				srt = world.component "srt" {
					s = math3d.ref(math3d.mul(100, math3d.vector(cylinder_radius, cylinder_scaleY, cylinder_radius))),
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

	--world:set(cylindereid, "material", {properties={u_color=color}})

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
			transform =  {srt=world.component "srt"{s = {100}, r = local_rotator, t = cone_t}},
			material = world.component "resource" "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone" .. axis_str
		},
		action = {
            mount = axis_root,
		},
	}

	--world:set(coneeid, "material", {properties={u_color=color}})

	if axis_str == "x" then
		gizmo_obj.x.eid[1] = cylindereid
		gizmo_obj.x.eid[2] = coneeid
	elseif axis_str == "y" then
		gizmo_obj.y.eid[1] = cylindereid
		gizmo_obj.y.eid[2] = coneeid
	elseif axis_str == "z" then
		gizmo_obj.z.eid[1] = cylindereid
		gizmo_obj.z.eid[2] = coneeid
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

	world:set(coneeid, "material", {properties={u_color=world.component "vector" {0, 0.5, 0.5, 1}}})

	local srt = {s = {0.02,0.02,0.02,0}, r = math3d.quaternion{0, 0, 0}, t = {0,0,0,1}}
	local axis_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform =  {srt= world.component "srt"(srt)},
			name = "directional light arrow",
		},
	}
	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	resetAxisColor()
	gizmo_obj.root = world[axis_root]
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}

local function isGizmo(eid)
	if eid == gizmo_obj.x.eid[1] or eid == gizmo_obj.x.eid[2] then
		return true
	elseif eid == gizmo_obj.y.eid[1] or eid == gizmo_obj.y.eid[2] then
		return true
	elseif eid == gizmo_obj.z.eid[1] or eid == gizmo_obj.z.eid[2] then
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

local function selectAxis(x, y, hit_radius)
	local hp = {x, y, 0}
	local highlight = world.component "vector" {1, 1, 0, 1}
	resetAxisColor()

	local start = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3]))
	local end_x = worldToScreen(math3d.vector(gizmo_obj.position[1] + axis_length, gizmo_obj.position[2], gizmo_obj.position[3]))
	
	local ret = pointToLineDistance2D(start, end_x, hp)
	if ret < hit_radius then
		world:set(gizmo_obj.x.eid[1], "material", {properties={u_color=highlight}})
		world:set(gizmo_obj.x.eid[2], "material", {properties={u_color=highlight}})
		return gizmo_obj.x
	end

	local end_y = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2] + axis_length, gizmo_obj.position[3]))
	ret = pointToLineDistance2D(start, end_y, hp)
	if ret < hit_radius then
		world:set(gizmo_obj.y.eid[1], "material", {properties={u_color=highlight}})
		world:set(gizmo_obj.y.eid[2], "material", {properties={u_color=highlight}})
		return gizmo_obj.y
	end

	local end_z = worldToScreen(math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3] + axis_length))
	ret = pointToLineDistance2D(start, end_z, hp)
	if ret < hit_radius then
		world:set(gizmo_obj.z.eid[1], "material", {properties={u_color=highlight}})
		world:set(gizmo_obj.z.eid[2], "material", {properties={u_color=highlight}})
		return gizmo_obj.z
	end
	return nil
end

local function updateGizmoScale()
	local camera = camerautil.main_queue_camera(world)
	local gizmo_dist = math3d.length(math3d.sub(camera.eyepos, math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3])))
	local scale = gizmo_dist * 0.007
	gizmo_obj.root.transform.srt.s = math3d.vector(scale, scale, scale)
end

local function drawRotateGizmo()
	-- -- x axis
	-- local lx = {math3d.vector(0,0,0), math3d.vector(1,0,0)}
	-- iwd.draw_lines(lx, world.component "srt" {s = {1.0}, t = {0.0, 0.5, 0.0, 1}}, 0xff0000ff)
	-- -- y axis
	-- local ly = {math3d.vector(0,0,0), math3d.vector(0,1,0)}
	-- iwd.draw_lines(ly, world.component "srt" {s = {1.0}, t = {0.0, 0.5, 0.0, 1}}, 0xff00ff00)
	-- -- z axis
	-- local lz = {math3d.vector(0,0,0), math3d.vector(0,0,1)}
	-- iwd.draw_lines(lz, world.component "srt" {s = {1.0}, t = {0.0, 0.5, 0.0, 1}}, 0xffff0000)
	-- local seg = 72
	-- local radius = 0.5
	-- for i = 1, seg do
	-- 	local lz = {math3d.vector(0,0,0), math3d.vector(0,0,1)}
	-- 	iwd.draw_lines(lz, world.component "srt" {s = {1.0}, t = {gizmo_position[1], gizmo_position[2], gizmo_position[3], 1}}, 0xffff0000)
	-- end
end

local cameraZoom = world:sub {"camera", "zoom"}
local mouseDrag = world:sub {"mousedrag"}
local mouseMove = world:sub {"mousemove"}
local mouseDown = world:sub {"mousedown"}
local mouseUp = world:sub {"mouseup"}

local lastGizmoPos
local lastMousePos
local initOffset
local function moveGizmo(x, y)
	local newOffset = viewToAxisConstraint({x, y}, selected_axis.dir, lastGizmoPos)
	local deltaOffset = {newOffset[1] - initOffset[1], newOffset[2] - initOffset[2], newOffset[3] - initOffset[3]}
	gizmo_obj.position = {
		lastGizmoPos[1] + deltaOffset[1],
		lastGizmoPos[2] + deltaOffset[2],
		lastGizmoPos[3] + deltaOffset[3]
	}	--math3d.totable(world[eid].transform.srt.t)
	local new_pos = math3d.vector(gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3])
	gizmo_obj.root.transform.srt.t = new_pos
	if gizmo_obj.target_eid then
		world[gizmo_obj.target_eid].transform.srt.t = new_pos
	end
	updateGizmoScale()
end

function gizmo_sys:data_changed()
	for _ in cameraZoom:unpack() do
		updateGizmoScale()
	end

	for _, what, x, y in mouseDown:unpack() do
		if what == "LEFT" then
			selected_axis = selectAxis(x, y, 10)
			if selected_axis then
				lastGizmoPos = {gizmo_obj.position[1], gizmo_obj.position[2], gizmo_obj.position[3]}
				lastMousePos = {x, y}
				initOffset = viewToAxisConstraint(lastMousePos, selected_axis.dir, lastGizmoPos)
			else
				gizmo_obj.target_eid = nil
			end
			-- local sw, sh = rhwi.screen_size()
			-- local camera = camerautil.main_queue_camera(world)
			-- local q = world:singleton_entity("main_queue")
			-- local ray = camera_motion.ray(q.camera_eid, {x, y})
			-- print("ray.origin",ray.origin[1], ray.origin[2], ray.origin[3], ray.origin[4])
			-- print("ray.dir",ray.dir[1], ray.dir[2], ray.dir[3])
		end
	end

	for _, what, x, y in mouseUp:unpack() do
		if what == "LEFT" then
			print("UP")
		end
	end

	for _, what, x, y in mouseMove:unpack() do
		if what == "UNKNOWN" then
			selectAxis(x, y, 10)
		end
	end
	
	for _, what, x, y, dx, dy in mouseDrag:unpack() do
		if what == "LEFT" then
			if selected_axis then
				moveGizmo(x, y)
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
            -- if not world[eid].gizmo_object then
            --     hub.publish(WatcherEvent.RTE.SceneEntityPick,{eid})
            --     on_pick_entity(eid)
			-- end
			--onChangeColor(world[eid])
			if not isGizmo(eid) and gizmo_obj.target_eid ~= eid then
				gizmo_obj.position = math3d.totable(world[eid].transform.srt.t)
				gizmo_obj.root.transform.srt.t = world[eid].transform.srt.t
				gizmo_obj.target_eid = eid
				updateGizmoScale()
			end
        else
            -- hub.publish(WatcherEvent.RTE.SceneEntityPick,{})
            -- on_pick_entity(nil)
		end
	end
	drawRotateGizmo()
end