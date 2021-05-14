local ecs = ...
local world = ecs.world
local math3d = require "math3d"

local ientity = world:interface "ant.render|entity"
local st_sys = ecs.system "shadow_test_system"

local mc = import_package "ant.math".constant
local ies = world:interface "ant.scene|ientity_state"
local imaterial = world:interface "ant.asset|imaterial"
local ilight = world:interface "ant.render|light"
local iom = world:interface "ant.objcontroller|obj_motion"

--[[
	set outter sphere radius: 'r'
	set sphere origin: (0, 0, 0)
	set tetrahedron height and edge: h, e
	so origin to bottom face: d = h - r
	bottom face to origin distance: d
	set bottom face radius: 'c'
	so: c = (2*sqrt(2)/3) * r
		d = (1/3) * r
		b = c/2 = (sqrt(2)/3)*r
		a = (sqrt(6)/3)*r
	so top vertex is: (0, r, 0)
	vertex in z-axis is: (0.0, -d, c) = (0, -1/3*r, (2*sqrt(2)/3)*r)
	another 2 vertices:
		(-a, -d, -b) = (-sqrt(6)/3*r, -1/3*r, -(sqrt(2)/3)*r)
		( a, -d, -b) = ( sqrt(6)/3*r, -1/3*r, -(sqrt(2)/3)*r)
]]

local function create_tetrahedron_entity(r)
	local c = (2*math.sqrt(2.0)/3.0)*r
	local d = (1.0/3.0)*r
	local b = c * 0.5
	local a = (math.sqrt(6.0)/3.0)*r
	local vertices = {
		{ 0, r, 0},
		{ 0,-d, c},
		{-a,-d,-b},
		{ a,-d,-b},
	}

	local colors = {
		0xff0000ff, --red
		0xff00ff00,	--green
		0xffff0000, --blue
		0xff00ffff, --yellow
	}

	local indices = {
		{0, 1, 4}, --red
		{0, 3, 1}, --green
		{0, 4, 3}, --blue
		{1, 3, 4}, --yellow
	}
	local vb = {}
	for i=1, 4 do
		local cc= colors[i]
		for _, ii in ipairs(indices[i]) do
			local v = vertices[ii]
			for j=1, 3 do
				vb[#vb+1] = v[j]
			end
			vb[#vb+1] = cc
		end
	end

	local m = ientity.create_mesh("p3|c40niu", vb)
	ientity.create_simple_render_entity(nil, "/pkg/ant.resources/materials/")
end

function st_sys:init()
	world:create_entity {
		policy = {
			"ant.render|render",
			"ant.render|shadow_cast_policy",
			"ant.general|name",
		},
		data = {
			state = ies.create_state "visible|selectable|cast_shadow",
			scene_entity = true,
			transform =  {
				s=100,
				t={0, 2, 0, 0}
			},
			material = "/pkg/ant.resources/materials/singlecolor.material",
			mesh = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
			name = "cast_shadow_cube",
		}
	}

	local rooteid = world:create_entity {
		policy = {
			"ant.scene|transform_policy",
			"ant.general|name",
		},
		data = {
			transform =  {t = {0, 0, 3, 1}},
			name = "mesh_root",
			scene_entity = true,
		}
	}
	world:instance("/pkg/ant.resources.binary/meshes/RiggedFigure.glb|mesh.prefab", {import={root=rooteid}})

    local eid = ientity.create_plane_entity(
		{t = {0, 0, 0, 1}, s = {50, 1, 50, 0}},
		"/pkg/ant.resources/materials/mesh_shadow.material",
		"test_shadow_plane", nil, true)

	imaterial.set_property(eid, "u_basecolor_factor", {0.8, 0.8, 0.8, 1})
end

function st_sys:post_init()
	--ilight.create_light_direction_arrow(ilight.directional_light(), {scale=0.02, cylinder_cone_ratio=1, cylinder_rawradius=0.45})
end
