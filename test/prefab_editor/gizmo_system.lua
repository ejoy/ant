local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local computil = world:interface "ant.render|entity"
local gizmo_sys = ecs.system "gizmo_system"
local assetmgr  = import_package "ant.asset"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local cylinder_cone_ratio = 8
local cylinder_rawradius = 0.25

local gizmo
local gizmo_eid = {x = {}, y = {}, z ={}}
local switch = true
local function onChangeColor(obj)
	if switch then
		obj.material.properties.u_color = world.component "vector" {1, 0, 0, 1}
		switch = false
	else
		obj.material.properties.u_color = world.component "vector" {1, 1, 1, 1}
		switch = true
	end
	
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
	-- 		transform = world.component "transform" {
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
	-- 		transform = world.component "transform" {
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
	local color
	if axis_str == "x" then
		cone_t = math3d.ref(math3d.add(math3d.vector(cylinder_len, 0, 0), math3d.vector(cone_raw_halflen, 0, 0)))
		local_rotator = math3d.ref(math3d.quaternion{0, 0, math.rad(-90)})
		cylindere_t = math3d.ref(math3d.vector(cylinder_halflen, 0, 0))
		color = world.component "vector" {1, 0, 0, 1}
	elseif axis_str == "y" then
		cone_t = math3d.ref(math3d.add(math3d.vector(0, cylinder_len, 0), math3d.vector(0, cone_raw_halflen, 0)))
		local_rotator = math3d.ref(math3d.quaternion{0, 0, 0})
		cylindere_t = math3d.ref(math3d.vector(0, cylinder_halflen, 0))
		color = world.component "vector" {0, 1, 0, 1}
	elseif axis_str == "z" then
		cone_t = math3d.ref(math3d.add(math3d.vector(0, 0, cylinder_len), math3d.vector(0, 0, cone_raw_halflen)))
		local_rotator = math3d.ref(math3d.quaternion{math.rad(90), 0, 0})
		cylindere_t = math3d.ref(math3d.vector(0, 0, cylinder_halflen))
		color = world.component "vector" {0, 0, 1, 1}
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
			transform = world.component "transform" {
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

	world:set(cylindereid, "material", {properties={u_color=color}})

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
			transform = world.component "transform" {srt=world.component "srt"{s = {100}, r = local_rotator, t = cone_t}},
			material = world.component "resource" "/pkg/ant.resources/materials/t_gizmos.material",
			mesh = world.component "resource" '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone" .. axis_str
		},
		action = {
            mount = axis_root,
		},
	}

	world:set(coneeid, "material", {properties={u_color=color}})

	if axis_str == "x" then
		gizmo_eid.x[1] = cylindereid
		gizmo_eid.x[2] = coneeid
	elseif axis_str == "y" then
		gizmo_eid.y[1] = cylindereid
		gizmo_eid.y[2] = coneeid
	elseif axis_str == "z" then
		gizmo_eid.z[1] = cylindereid
		gizmo_eid.z[2] = coneeid
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
			transform = world.component "transform" {
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
			transform = world.component "transform" {
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
			transform = world.component "transform" {srt= world.component "srt"(srt)},
			name = "directional light arrow",
		},
	}
	create_arrow_widget(axis_root, "x")
	create_arrow_widget(axis_root, "y")
	create_arrow_widget(axis_root, "z")
	gizmo = world[axis_root]
end

local keypress_mb = world:sub{"keyboard"}

local pickup_mb = world:sub {"pickup"}

local function isGizmoSelect(eid)
	if eid == gizmo_eid.x[1] or eid == gizmo_eid.x[2] then
		return true
	elseif eid == gizmo_eid.y[1] or eid == gizmo_eid.y[2] then
		return true
	elseif eid == gizmo_eid.z[1] or eid == gizmo_eid.z[2] then
		return true
	else
		return false
	end
end

function gizmo_sys:data_changed()
	for _, key, press, state in keypress_mb:unpack() do
		if key == "SPACE" and press == 0 then
			-- world:pub{"record_camera_state"}
			-- onChangeColor(cube)
		end
	end
	for _,pick_id,pick_ids in pickup_mb:unpack() do
		print("pickup_mb", pick_id, pick_ids)
        local hub = world.args.hub
        local eid = pick_id
        if eid and world[eid] then
            -- if not world[eid].gizmo_object then
            --     hub.publish(WatcherEvent.RTE.SceneEntityPick,{eid})
            --     on_pick_entity(eid)
			-- end
			--onChangeColor(world[eid])
			if not isGizmoSelect(eid) then
				gizmo.transform.srt.t = world[eid].transform.srt.t
			end
        else
            -- hub.publish(WatcherEvent.RTE.SceneEntityPick,{})
            -- on_pick_entity(nil)
        end
    end
end