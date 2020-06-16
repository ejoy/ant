local ecs = ...
local world = ecs.world

local ientity = ecs.interface "entity"

local declmgr   = require "vertexdecl_mgr"
local hwi       = require "hardware_interface"
local math3d    = require "math3d"
local assetmgr  = import_package "ant.asset"
local mu        = import_package "ant.math".util
local geopkg    = import_package "ant.geometry"
local geodrawer = geopkg.drawer
local geolib    = geopkg.geometry

local ies = world:interface "ant.render|ientity_state"

local function create_vb_buffer(flag, vb)
	return ("<"..flag:gsub("d", "I4"):rep(#vb/#flag)):pack(table.unpack(vb))
end

local function create_ib_buffer(ib)
	return ("<"..("I4"):rep(#ib)):pack(table.unpack(ib))
end

local function create_mesh(vb_lst, ib)
	local mesh = {
		vb = {
			start = 0,
		}
	}
	local num = 0
	for i = 1, #vb_lst, 2 do
		local layout, vb = vb_lst[i], vb_lst[i+1]
		local correct_layout = declmgr.correct_layout(layout)
		local flag = declmgr.vertex_desc_str(correct_layout)
		local vb_value = create_vb_buffer(flag, vb)
		mesh.vb[#mesh.vb+1] = {
			declname = correct_layout,
			memory = {vb_value,1,#vb_value},
		}
		num = num + #vb / #flag
	end
	mesh.vb.num = num
	if ib then
		local ib_value = create_ib_buffer(ib)
		mesh.ib = {
			start = 0, num = #ib,
			flag = "d",
			memory = {ib_value,1,#ib_value},
		}
	end
	return world.component "mesh"(mesh)
end

function ientity.create_mesh(vb, ib)
	return create_mesh(vb, ib)
end

local nameidx = 0
local function gen_test_name() nameidx = nameidx + 1 return "entity" .. nameidx end

local function create_simple_render_entity(srt, material, name, mesh, state)
	return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform	= world.component "transform" {srt = world.component "srt"(srt or {})},
			material	= world.component "resource"(material),
			mesh		= mesh,
			state		= state or ies.create_state "visible",
			name		= name or gen_test_name(),
			scene_entity= true,
		}
	}
end

function ientity.create_grid_entity(name, w, h, unit, srt)
	w = w or 64
	h = h or 64
	unit = unit or 1
	local vb, ib = geolib.grid(w, h, unit)
	local gvb = {}
	for _, v in ipairs(vb) do
		for _, vv in ipairs(v) do
			gvb[#gvb+1] = vv
		end
	end
	local mesh = create_mesh({"p3|c40niu", gvb}, ib)
	return create_simple_render_entity(srt, "/pkg/ant.resources/materials/line.material", name, mesh, ies.create_state "visible")
end

local plane_mesh
local function get_plane_mesh()
	if plane_mesh == nil then
		local vb = {
			-0.5, 0, 0.5, 0, 1, 0, 0, 1,	--left top
			0.5,  0, 0.5, 0, 1, 0, 1, 1,	--right top
			-0.5, 0,-0.5, 0, 1, 0, 0, 0,	--left bottom
			0.5,  0,-0.5, 0, 1, 0, 1, 0,	--right bottom
		}
		plane_mesh = create_mesh({"p3|n3|t2", vb})
		plane_mesh.bounding = {
			aabb = math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))
		}
	end
	return plane_mesh
end

function ientity.create_plane_entity(srt, materialpath, color, name, info)
	local policy = {
		"ant.render|render",
		"ant.general|name",
	}

	local data = {
		transform = world.component "transform" {srt = world.component "srt"(srt or {})},
		material = world.component "resource"(materialpath or "/pkg/ant.resources/materials/test/singlecolor_tri_strip.material"),
		state = ies.create_state "visible|selectable",
		name = name or "Plane",
		scene_entity = true,
		mesh = get_plane_mesh(),
	}

	if info then
		for policy_name, dd in pairs(info) do
			policy[#policy+1] = policy_name
			for k, d in pairs(dd) do
				data[k] = d
			end
		end
	end

	local eid = world:create_entity{
		policy = policy,
		data = data,
	}

	local e = world[eid]
	e.material.properties.u_color = world.component "vector"(color)
	return eid
end

local function quad_mesh(rect)
	local origin_bottomleft = hwi.get_caps().originBottomLeft
	local minv, maxv
	if origin_bottomleft then
		minv, maxv = 0, 1
	else
		minv, maxv = 1, 0
	end
	local x, y, w, h
	if rect then
		x, y = rect.x or 0, rect.y or 0
		w, h = rect.w, rect.h
	else
		x, y = -1, -1
		w, h = 2, 2
	end
	return create_mesh({"p3|t2", {
		x, 		y, 		0, 	0, minv,	--bottom left
		x,		y + h, 	0, 	0, maxv,	--top left
		x + w, 	y, 		0, 	1, minv,	--bottom right
		x + w, 	y + h, 	0, 	1, maxv,	--top right
	}})
end

function ientity.quad_mesh(rect)
	return quad_mesh(rect)
end

local fullquad_meshres
function ientity.fullquad_mesh()
	if fullquad_meshres == nil then
		fullquad_meshres = quad_mesh()
	end
	return fullquad_meshres
end

function ientity.create_quad_entity(rect, material, name)
	local mesh = quad_mesh(rect)
	return create_simple_render_entity(nil, material, name, mesh)
end

function ientity.create_texture_quad_entity(texture_tbl, name)
	local vb = {
		-3,  3, 0, 0, 0,
		 3,  3, 0, 1, 0,
		-3, -3, 0, 0, 1,
		 3, -3, 0, 1, 1,
	}
	local mesh = create_mesh({"p3|t2", vb})
	local eid = create_simple_render_entity(nil, "/pkg/ant.resources/materials/texture.material",  name, mesh)
	world:set(eid, "material", {properties = texture_tbl})
	return eid
end


local frustum_ib = {
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

function ientity.create_frustum_entity(frustum_points, name, color)
	local vb = {}
	color = color or 0xff00000f
	for i=1, #frustum_points do
		local p = math3d.totable(frustum_points[i])
		table.move(p, 1, 3, #vb+1, vb)
		vb[#vb+1] = color
	end
	local mesh = create_mesh({"p3|c40niu", vb}, frustum_ib)
	return create_simple_render_entity(nil, "/pkg/ant.resources/materials/line.material", name, mesh)
end

local axis_ib = {
	0, 1,
	2, 3,
	4, 5,
}
function ientity.create_axis_entity(srt, color, name)
	local axis_vb = {
		0, 0, 0, color or 0xff0000ff,
		1, 0, 0, color or 0xff0000ff,
		0, 0, 0, color or 0xff00ff00,
		0, 1, 0, color or 0xff00ff00,
		0, 0, 0, color or 0xffff0000,
		0, 0, 1, color or 0xffff0000,
	}
	local mesh = create_mesh({"p3|c40niu", axis_vb}, axis_ib)
	return create_simple_render_entity(srt, "/pkg/ant.resources/materials/line.material", name, mesh)
end


local skybox_mesh
local function get_skybox_mesh()
	if skybox_mesh == nil then
		local desc = {vb={}, ib={}}
		geodrawer.draw_box({1, 1, 1}, nil, nil, desc)
		local gvb = {}
		for _, v in ipairs(desc.vb)do
			table.move(v, 1, 3, #gvb+1, gvb)
		end
		skybox_mesh = create_mesh({"p3", gvb}, desc.ib)
	end

	return skybox_mesh
end

function ientity.create_skybox(material)
    return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform = world.component "transform" {srt=mu.srt()},
			material = world.component "resource"(material or "/pkg/ant.resources/materials/skybox.material"),
			state = ies.create_state "selectable|visible",
			scene_entity = true,
			name = "sky_box",
			mesh = get_skybox_mesh(),
		}
	}
end

local function create_sky_mesh(w, h)
	local vb = {}
	local ib = {}

	local w_count, h_count = w - 1, h - 1
	for j=0, h_count do
		for i=0, w_count do
			local x = i / w_count * 2.0 - 1.0
			local y = j / h_count * 2.0 - 1.0
			vb[#vb+1] = x
			vb[#vb+1] = y
		end
	end

	for j=0, h_count - 1 do
		for i=0, w_count - 1 do
			local lineoffset = w * j
			local nextlineoffset = w*j + w

			ib[#ib+1] = i + lineoffset
			ib[#ib+1] = i + 1 + lineoffset
			ib[#ib+1] = i + nextlineoffset

			ib[#ib+1] = i + 1 + lineoffset
			ib[#ib+1] = i + 1 + nextlineoffset
			ib[#ib+1] = i + nextlineoffset
		end
	end
	return create_mesh({"p2", vb}, ib)
end

function ientity.create_procedural_sky(settings)
	settings = settings or {}
	local function attached_light(eid)
		if eid then
			return world[eid].serialize
		end
	end
    return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.sky|procedural_sky",
			"ant.general|name",
		},
		data = {
			transform = world.component "transform" {srt=world.component "srt"{}},
			material = world.component "resource" "/pkg/ant.resources/materials/sky/procedural/procedural_sky.material",
			procedural_sky = world.component "procedural_sky" {
				--attached_sun_light = attached_light(settings.attached_sun_light),
				which_hour 	= settings.whichhour or 12,	-- high noon
				turbidity 	= settings.turbidity or 2.15,
				month 		= settings.whichmonth or "June",
				latitude 	= settings.whichlatitude or math.rad(50),
			},
			state = ies.create_state "visible",
			mesh = create_sky_mesh(32, 32),
			scene_entity = true,
			name = "procedural sky",
		}
	}
end

function ientity.entity_bounding(eid)
	local e = world[eid]
	local m = e.mesh
	if m and ies.can_visible(eid) then
		local wm = e.transform._world
		local b = m.bounding
		if b then
			return math3d.aabb_transform(b.aabb, wm)
		end
	end
end
