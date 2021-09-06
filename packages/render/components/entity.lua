local ecs = ...
local world = ecs.world

local ientity 	= ecs.interface "entity"
local declmgr   = require "vertexdecl_mgr"
local math3d    = require "math3d"
local hwi		= import_package "ant.hwi"
local geopkg    = import_package "ant.geometry"
local geodrawer = geopkg.drawer
local geolib    = geopkg.geometry

local mathpkg   = import_package "ant.math"
local mc		= mathpkg.constant

local ies = world:interface "ant.scene|ientity_state"
local imaterial = world:interface "ant.asset|imaterial"
local irender = world:interface "ant.render|irender"
local imesh 	= world:interface "ant.asset|imesh"
local bgfx = require "bgfx"

local function create_dynamic_mesh(layout, vb, ib)
	local declmgr = import_package "ant.render".declmgr
	local decl = declmgr.get(layout)
	return {
		vb = {
			{handle=bgfx.create_dynamic_vertex_buffer(bgfx.memory_buffer("fffd", vb), declmgr.get(layout).handle, "a")}
		},
		ib = {
			handle = bgfx.create_dynamic_index_buffer(bgfx.memory_buffer("d", ib), "ad")
		}
	}
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
		mesh.vb[#mesh.vb+1] = {
			declname = correct_layout,
			memory = {flag, vb}
		}
		num = num + #vb / #flag
	end
	mesh.vb.num = num
	if ib then
		mesh.ib = {
			start = 0, num = #ib,
			memory = {"w", ib},
		}
	end
	return world.component "mesh"(mesh)
end

ientity.create_mesh = create_mesh

local nameidx = 0
local function gen_test_name() nameidx = nameidx + 1 return "entity" .. nameidx end

local function create_simple_render_entity(name, material, mesh, srt, state)
	return world:deprecated_create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform	= srt or {},
			material	= material,
			mesh		= mesh,
			state		= state or ies.create_state "visible",
			name		= name or gen_test_name(),
			scene_entity= true,
		}
	}
end

ientity.create_simple_render_entity = create_simple_render_entity

function ientity.create_grid_mesh_entity(name, w, h, size, color, materialpath)
	local vb = {
	}
	local ib = {
	}
	local gap = size / 20.0
	local total_width = w * size
	local total_height = h * size
	for i = 0, h - 1 do
		local posz = -total_height * 0.5 + i * size + gap
		for j = 0, w - 1 do
			local posx = -total_width * 0.5 + j * size + gap
			local realcolor = (type(color) == "table") and color[i + 1][ j + 1] or color
			--[[
			v1-----v2
			|      |
			|      |
			v0-----v3
			]]
			--v0
			vb[#vb + 1] = posx
			vb[#vb + 1] = 0.0
			vb[#vb + 1] = posz
			vb[#vb + 1] = realcolor
			--v1
			vb[#vb + 1] = posx
			vb[#vb + 1] = 0.0
			vb[#vb + 1] = posz + size - gap
			vb[#vb + 1] = realcolor
			--v2
			vb[#vb + 1] = posx + size - gap
			vb[#vb + 1] = 0.0
			vb[#vb + 1] = posz + size - gap
			vb[#vb + 1] = realcolor
			--v3
			vb[#vb + 1] = posx + size - gap
			vb[#vb + 1] = 0.0
			vb[#vb + 1] = posz
			vb[#vb + 1] = realcolor
			--ib
			local grid_idx = (i * w + j) * 4
			ib[#ib + 1] = grid_idx + 0
			ib[#ib + 1] = grid_idx + 1
			ib[#ib + 1] = grid_idx + 2
			ib[#ib + 1] = grid_idx + 0
			ib[#ib + 1] = grid_idx + 2
			ib[#ib + 1] = grid_idx + 3
		end
	end
	local data = {
		transform = srt or {},
		material = materialpath,
		state = ies.create_state "visible",
		name = name or "GridMesh",
		scene_entity = true,
		mesh = create_dynamic_mesh("p3|c40niu", vb, ib) --create_mesh({"p3|c40niu", vb}, ib)
	}

	return vb, world:deprecated_create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name"},
		data = data,
	}
end

function ientity.create_grid_entity_simple(name, w, h, unit, srt)
	w = w or 64
	h = h or 64
	unit = unit or 1
	local vb, ib = geolib.grid(w, h, nil, unit)
	local mesh = create_mesh({"p3|c40niu", vb}, ib)
	return create_simple_render_entity(name, "/pkg/ant.resources/materials/line_foreground.material", mesh, srt)
end

function ientity.create_grid_entity(name, width, height, unit, linewidth)
	local ipl = world:interface "ant.render|ipolyline"
	
	local hw = width * 0.5
	local hw_len = hw * unit

	local hh = height * 0.5
	local hh_len = hh * unit

	local pl = {}
	local function add_vertex(x, y, z)
		pl[#pl+1] = {x, y, z}
	end

	local function add_line(x0, z0, x1, z1)
		add_vertex(x0, 0, z0)
		add_vertex(x1, 0, z1)
	end

	for i=0, width do
		if i ~= hw then
			local x = -hw_len + i * unit
			add_line(x, -hh_len, x, hh_len)
		end
	end

	for i=0, height do
		if i ~= hh then
			local y = -hh_len + i * unit
			add_line(-hw_len, y, hw_len, y)
		end
	end

	local eid = ipl.add_linelist(pl, linewidth, {0.8, 0.8, 0.8, 1.0})
	world[eid].name = name

	local centerwidth<const> = linewidth * 2.0
	local xeid = ipl.add_linelist({{-hw_len, 0, 0}, {hw_len, 0, 0},}, centerwidth, {1.0, 0.0, 0.0, 1.0})
	local zeid = ipl.add_linelist({{0, 0, -hh_len}, {0, 0, hh_len},}, centerwidth, {0.0, 0.0, 1.0, 1.0})

	world[xeid].name = name .. ":centerx"
	world[zeid].name = name .. ":centerz"
end


local function get_plane_mesh()
	local vb = {
		-0.5, 0, 0.5, 0, 1, 0, 0, 1,	--left top
		0.5,  0, 0.5, 0, 1, 0, 1, 1,	--right top
		-0.5, 0,-0.5, 0, 1, 0, 0, 0,	--left bottom
		0.5,  0,-0.5, 0, 1, 0, 1, 0,	--right bottom
	}
	local plane_mesh = create_mesh({"p3|n3|t2", vb})
	plane_mesh.bounding = {
		aabb = math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))
	}
	return plane_mesh
end

local prim_plane_mesh

local function get_prim_plane_mesh(sharedmesh)
	local vb = {
		-0.5, 0, 0.5, 0, 1, 0,	--left top
		0.5,  0, 0.5, 0, 1, 0,	--right top
		-0.5, 0,-0.5, 0, 1, 0,	--left bottom
		-0.5, 0,-0.5, 0, 1, 0,
		0.5,  0, 0.5, 0, 1, 0,
		0.5,  0,-0.5, 0, 1, 0,	--right bottom
	}
	if sharedmesh then
		if not prim_plane_mesh then
			local tempmesh = create_mesh({"p3|n3", vb})
			tempmesh.bounding = {
				aabb = math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))
			}
			local internal_vb, internal_ib = imesh.create_rendermesh(tempmesh)
			prim_plane_mesh = {vb = internal_vb, ib = internal_ib}
		end

		return prim_plane_mesh
	end

	local mesh = create_mesh({"p3|n3", vb})
	mesh.bounding = {
		aabb = math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))
	}
	return mesh
end

function ientity.create_prim_plane_entity(srt, materialpath, name, sharedmesh, entity_info)
	local policy = {
		sharedmesh and "ant.render|simplerender" or "ant.render|render",
		"ant.general|name",
	}

	local data = {
		transform = srt or {},
		material = materialpath,
		state = ies.create_state "visible",
		name = name or "Plane",
		scene_entity = true,
	}
	if sharedmesh then
		data.simplemesh = get_prim_plane_mesh(sharedmesh)
	else
		data.mesh = get_prim_plane_mesh()
	end

	if entity_info then
		for policy_name, dd in pairs(entity_info) do
			policy[#policy+1] = policy_name
			for k, d in pairs(dd) do
				data[k] = d
			end
		end
	end

	return world:deprecated_create_entity{
		policy = policy,
		data = data,
	}
end

function ientity.create_plane_entity(srt, materialpath, name, entity_info, enable_shadow)
	local policy = {
		"ant.render|render",
		"ant.general|name",
	}

	local whichstate = "visible|selectable"
	if enable_shadow then
		whichstate = whichstate .. "|cast_shadow"
	end

	local data = {
		transform = srt or {},
		material = materialpath,
		state = ies.create_state(whichstate),
		name = name or "Plane",
		scene_entity = true,
		mesh = get_plane_mesh(),
	}

	if entity_info then
		for policy_name, dd in pairs(entity_info) do
			policy[#policy+1] = policy_name
			for k, d in pairs(dd) do
				data[k] = d
			end
		end
	end

	return world:deprecated_create_entity{
		policy = policy,
		data = data,
	}
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

local fullquad_meshres
local function fullquad_mesh()
	if fullquad_meshres == nil then
		fullquad_meshres = quad_mesh()
	end
	return fullquad_meshres
end

ientity.fullquad_mesh = fullquad_mesh

function ientity.quad_mesh(rect)
	if rect == nil then
		return fullquad_meshres
	end

	return quad_mesh(rect)
end

function ientity.create_quad_entity(rect, material, name)
	local mesh = quad_mesh(rect)
	return create_simple_render_entity(name, material, mesh)
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
	color = color or {1.0, 1.0, 1.0, 1.0}
	for i=1, #frustum_points do
		local p = math3d.totable(frustum_points[i])
		table.move(p, 1, 3, #vb+1, vb)
	end
	local mesh = create_mesh({"p3", vb}, frustum_ib)
	local eid = create_simple_render_entity(name, "/pkg/ant.resources/materials/line_color.material", mesh)
	imaterial.set_property(eid, "u_color", color)
	return eid
end

local axis_ib = {
	0, 1,
	2, 3,
	4, 5,
}
function ientity.create_axis_entity(srt, name, color)
	local axis_vb = {
		0, 0, 0, color or 0xff0000ff,
		1, 0, 0, color or 0xff0000ff,
		0, 0, 0, color or 0xff00ff00,
		0, 1, 0, color or 0xff00ff00,
		0, 0, 0, color or 0xffff0000,
		0, 0, 1, color or 0xffff0000,
	}
	local mesh = create_mesh({"p3|c40niu", axis_vb}, axis_ib)
	return create_simple_render_entity(name, "/pkg/ant.resources/materials/line_color.material", mesh, srt)
end

function ientity.create_line_entity(srt, p0, p1, name, color)
	local vb = {
		p0[1], p0[2], p0[3], color or 0xffffffff,
		p1[1], p1[2], p1[3], color or 0xffffffff,
	}
	local mesh = create_mesh({"p3|c40niu", vb}, {0, 1})
	return create_simple_render_entity(name, "/pkg/ant.resources/materials/line_color.material", mesh, srt)
	
end

function ientity.create_circle_entity(radius, slices, srt, name)
	local circle_vb, circle_ib = geolib.circle(radius, slices)
	local gvb = {}
	--color = color or 0xffffffff
	for i = 1, #circle_vb, 3 do
		gvb[#gvb+1] = circle_vb[i]
		gvb[#gvb+1] = circle_vb[i + 1]
		gvb[#gvb+1] = circle_vb[i + 2]
		gvb[#gvb+1] = 0xffffffff
	end
	local mesh = create_mesh({"p3|c40niu", gvb}, circle_ib)
	return create_simple_render_entity(name, "/pkg/ant.resources/materials/line_color.material", mesh, srt)
end

function ientity.create_circle_mesh_entity(radius, slices, srt, mtl, name)
	local circle_vb, _ = geolib.circle(radius, slices)
	local gvb = {0,0,0,0,0,1}
	local ib = {}
	local idx = 1
	local maxidx = #circle_vb / 3
	for i = 1, #circle_vb, 3 do
		gvb[#gvb+1] = circle_vb[i]
		gvb[#gvb+1] = circle_vb[i + 1]
		gvb[#gvb+1] = circle_vb[i + 2]
		gvb[#gvb+1] = 0
		gvb[#gvb+1] = 0
		gvb[#gvb+1] = 1
		ib[#ib+1] = idx
		ib[#ib+1] = 0
		if idx ~= maxidx then
			ib[#ib+1] = idx + 1
		else
			ib[#ib+1] = 1
		end
		idx = idx + 1
	end
	local mesh = create_mesh({"p3|n3", gvb}, ib)
	return create_simple_render_entity(name, mtl, mesh, srt)
end

local skybox_mesh
local function get_skybox_mesh()
	if skybox_mesh == nil then
		local desc = {vb={}, ib={}}
		geodrawer.draw_box({1, 1, 1}, nil, nil, desc)
		skybox_mesh = create_mesh({"p3", desc.vb}, desc.ib)
	end

	return skybox_mesh
end

function ientity.create_skybox(material)
    return world:deprecated_create_entity {
		policy = {
			"ant.sky|skybox",
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform = {},
			material = material or "/pkg/ant.resources/materials/sky/skybox.material",
			state = ies.create_state "visible",
			ibl = {
				irradiance = {size=64},
				prefilter = {size=256},
				LUT = {size=256},
			},
			scene_entity = true,
			name = "sky_box",
			skybox = {},
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
    return world:deprecated_create_entity {
		policy = {
			"ant.render|render",
			"ant.sky|procedural_sky",
			"ant.general|name",
		},
		data = {
			transform = {},
			material = "/pkg/ant.resources/materials/sky/procedural/procedural_sky.material",
			procedural_sky = {
				--attached_sun_light = attached_light(settings.attached_sun_light),
				which_hour 	= settings.whichhour or 12,	-- high noon
				turbidity 	= settings.turbidity or 2.15,
				month 		= settings.whichmonth or "June",
				latitude 	= settings.whichlatitude or math.rad(50),
			},
			ibl = {
				irradiance = {
					size = 64,
				},
				prefilter = {
					size = 256,
				},
				LUT = {
					size = 256,
				}
			},
			state = ies.create_state "visible",
			mesh = create_sky_mesh(32, 32),
			scene_entity = true,
			name = "procedural sky",
		}
	}
end

function ientity.create_gamma_test_entity()
	world:deprecated_create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            material = "/pkg/ant.resources/materials/gamma_test.material",
            simplemesh = {
                ib = {
                    start = 0,
                    num = 6,
                    handle = irender.quad_ib(),
                },
                vb = {
                    start = 0,
                    num = 4,
                    handles = {
                        bgfx.create_vertex_buffer(bgfx.memory_buffer("ffff", {
                            100, 200, 0.0, 0.0,
                            100, 132, 0.0, 1.0,
                            420, 200, 1.0, 0.0,
                            420, 132, 1.0, 1.0,
                        }), declmgr.get "p2|t2".handle)
                    }
                }
            },
            transform = {},
            scene_entity = true,
            state = 1,
        }
    }
end

function ientity.create_arrow_entity(origin, forward, scale, data)
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
	local cylinder_len = cone_rawlen * data.cylinder_cone_ratio
	local cylinder_halflen = cylinder_len * 0.5
	local cylinder_scaleY = cylinder_len / cylinder_rawlen

	local cylinder_radius = data.cylinder_rawradius or 0.65

	local cone_raw_centerpos = mc.ZERO_PT
	local cone_centerpos = math3d.add(math3d.add({0, cylinder_halflen, 0, 1}, cone_raw_centerpos), {0, cone_raw_halflen, 0, 1})

	local cylinder_bottom_pos = math3d.vector(0, -cylinder_halflen, 0, 1)
	local cone_top_pos = math3d.add(cone_centerpos, {0, cone_raw_halflen, 0, 1})

	local arrow_center = math3d.mul(0.5, math3d.add(cylinder_bottom_pos, cone_top_pos))

	local cylinder_raw_centerpos = mc.ZERO_PT
	local cylinder_offset = math3d.sub(cylinder_raw_centerpos, arrow_center)

	local cone_offset = math3d.sub(cone_centerpos, arrow_center)

	local arroweid = world:deprecated_create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {
				s = scale,
				r = math3d.quaternion(mc.YAXIS, forward),
				t = math3d.sub(origin, cylinder_bottom_pos),	-- move cylinder bottom to zero origin, and move to origin: -cylinder_bottom_pos+origin
			},
			scene_entity = true,
			name = "directional light arrow",
		},
	}

	local cylindereid = world:deprecated_create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform =  {
				s = math3d.ref(math3d.mul(100, math3d.vector(cylinder_radius, cylinder_scaleY, cylinder_radius))),
				t = math3d.ref(cylinder_offset),
			},
			material = "/pkg/ant.resources/materials/simpletri.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin',
			name = "arrow.cylinder",
		},
		action = {
            mount = arroweid,
        }
	}

	imaterial.set_property(cylindereid, "u_color", data.cylinder_color or {1, 0, 0, 1})

	local coneeid = world:deprecated_create_entity{
		policy = {
			"ant.render|render",
			"ant.general|name",
			"ant.scene|hierarchy_policy",
		},
		data = {
			scene_entity = true,
			state = ies.create_state "visible",
			transform =  {s=100, t=cone_offset},
			material = "/pkg/ant.resources/materials/simpletri.material",
			mesh = '/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin',
			name = "arrow.cone"
		},
		action = {
            mount = arroweid,
		}
	}

	imaterial.set_property(coneeid, "u_color", data.cone_color or {1, 0, 0, 1})
end
