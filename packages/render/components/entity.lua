local ecs	= ...
local world = ecs.world
local w		= world.w
local ientity 	= ecs.interface "ientity"
local declmgr   = require "vertexdecl_mgr"
local math3d    = require "math3d"
local hwi		= import_package "ant.hwi"
local geopkg    = import_package "ant.geometry"
local geodrawer = geopkg.drawer
local geolib    = geopkg.geometry

local mathpkg   = import_package "ant.math"
local mc		= mathpkg.constant

local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender	= ecs.import.interface "ant.render|irender"
local imesh 	= ecs.import.interface "ant.asset|imesh"
local bgfx 		= require "bgfx"

local function create_dynamic_mesh(layout, vb, ib)
	local decl = declmgr.get(layout)
	return {
		vb = {
			handle=bgfx.create_dynamic_vertex_buffer(bgfx.memory_buffer("fffd", vb), decl.handle, "a")
		},
		ib = {
			handle = bgfx.create_dynamic_index_buffer(bgfx.memory_buffer("d", ib), "ad")
		}
	}
end

local function create_mesh(vbdata, ibdata, aabb)
	local vb = {
		start = 0,
	}
	local mesh = {vb = vb}

	if aabb then
		mesh.bounding = {aabb=aabb}
	end
	
	local correct_layout = declmgr.correct_layout(vbdata[1])
	local flag = declmgr.vertex_desc_str(correct_layout)

	vb.num = #vbdata[2] // #flag
	vb.declname = correct_layout
	vb.memory = {flag, vbdata[2]}

	if ibdata then
		mesh.ib = {
			start = 0, num = #ibdata,
			memory = {"w", ibdata},
		}
	end
	return imesh.init_mesh(mesh)
end

ientity.create_mesh = create_mesh

local nameidx = 0
local function gen_test_name() nameidx = nameidx + 1 return "entity" .. nameidx end

local function simple_render_entity_data(name, material, mesh, scene, color, hide)
	return {
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene 		= scene or {},
			material	= material,
			simplemesh	= imesh.init_mesh(mesh, true),
			visible_state= hide and "auxgeom" or "main_view|auxgeom",
			name		= name or gen_test_name(),
			on_ready 	= function(e)
				imaterial.set_property(e, "u_color", color and math3d.vector(color) or mc.ONE)
			end
		}
	}
end

local function create_simple_render_entity(name, material, mesh, scene, color, hide)
	return ecs.create_entity(simple_render_entity_data(name, material, mesh, scene, color, hide))
end

ientity.create_simple_render_entity = create_simple_render_entity
ientity.simple_render_entity_data = simple_render_entity_data

local function grid_mesh_entity_data(name, materialpath, vb, ib)
	return {
		policy = {
			"ant.render|simplerender",
			"ant.general|name"
		},
		data = {
			scene 		= {},
			material 	= materialpath,
			visible_state= "main_view|auxgeom",
			name 		= name or "GridMesh",
			simplemesh	= imesh.init_mesh(create_dynamic_mesh("p3|c40niu", vb, ib), true), --create_mesh({"p3|c40niu", vb}, ib)
			on_ready = function(e)
				ivs.set_state(e, "auxgeom", true)
			end
		},
	}
end

function ientity.create_grid_mesh_entity(name, w, h, size, color, materialpath)
	local vb, ib = {}, {}
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

	return vb, ecs.create_entity(grid_mesh_entity_data(name, materialpath, vb, ib))
end

function ientity.create_grid_entity_simple(name, w, h, unit, scene)
	w = w or 64
	h = h or 64
	unit = unit or 1
	local vb, ib = geolib.grid(w, h, nil, unit)
	local mesh = create_mesh({"p3|c40niu", vb}, ib)
	return create_simple_render_entity(name, "/pkg/ant.resources/materials/line_foreground.material", mesh, scene)
end

function ientity.create_grid_entity(name, width, height, unit, linewidth)
	local ipl = ecs.import.interface "ant.render|ipolyline"
	
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

	local c<const> = 1
	local eid1 = ipl.add_linelist(pl, linewidth, {c, c, c, 1.0})

	local centerwidth<const> = linewidth * 2.0
	return eid1, ipl.add_linelist({{-hw_len, 0, 0}, {hw_len, 0, 0},}, centerwidth, {c, 0.0, 0.0, 1.0}),
	ipl.add_linelist({{0, 0, -hh_len}, {0, 0, hh_len},}, centerwidth, {0.0, 0.0, c, 1.0})
end


function ientity.plane_mesh(tex_uv)
	local u0, v0, u1, v1
	if tex_uv then
		u0, v0, u1, v1 = tex_uv[1], tex_uv[2], tex_uv[3], tex_uv[4]
	else
		u0, v0, u1, v1 = 0, 0, 1, 1
	end
	local vb = {
		-0.5, 0, 0.5, 0, 1, 0, u0, v0,	--left top
		 0.5, 0, 0.5, 0, 1, 0, u1, v0,	--right top
		-0.5, 0,-0.5, 0, 1, 0, u0, v1,	--left bottom
		 0.5, 0,-0.5, 0, 1, 0, u1, v1,	--right bottom
	}
	return create_mesh({"p3|n3|t2", vb}, nil, math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5})))
end

local plane_vb<const> = {
	-0.5, 0, 0.5, 0, 1, 0,	--left top
	0.5,  0, 0.5, 0, 1, 0,	--right top
	-0.5, 0,-0.5, 0, 1, 0,	--left bottom
	-0.5, 0,-0.5, 0, 1, 0,
	0.5,  0, 0.5, 0, 1, 0,
	0.5,  0,-0.5, 0, 1, 0,	--right bottom
}

function ientity.create_prim_plane_entity(name, materialpath, scene, color, hide)
	return ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene 		= scene or {},
			material 	= materialpath,
			visible_state= "main_view",
			name 		= name or "Plane",
			simplemesh 	= imesh.init_mesh(create_mesh({"p3|n3", plane_vb}, nil, math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))), true),
			on_ready = function (e)
				ivs.set_state(e, "main_view", not hide)
				imaterial.set_property(e, "u_color", math3d.vector(color))
			end
		},
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
		return fullquad_mesh()
	end

	return quad_mesh(rect)
end

function ientity.create_quad_entity(rect, material, name)
	return create_simple_render_entity(name, material, quad_mesh(rect))
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

function ientity.frustum_entity_data(frustum_points, name, color)
	local vb = {}
	color = color or {1.0, 1.0, 1.0, 1.0}
	for i=1, 8 do
		local p = math3d.tovalue(math3d.array_index(frustum_points, i))
		table.move(p, 1, 3, #vb+1, vb)
	end
	local mesh = create_mesh({"p3", vb}, frustum_ib)

	return simple_render_entity_data(name, "/pkg/ant.resources/materials/line_color.material", mesh, {}, color)
end

function ientity.create_frustum_entity(frustum_points, name, color)
	return ecs.create_entity(ientity.frustum_entity_data(frustum_points, name, color))
end

local function axis_mesh(color)
	local r = math3d.tovalue(color or mc.RED)
	local g = math3d.tovalue(color or mc.GREEN)
	local b = math3d.tovalue(color or mc.BLUE)
	local axis_vb = {
		0, 0, 0, r[1], r[2], r[3], r[4],
		1, 0, 0, r[1], r[2], r[3], r[4],
		0, 0, 0, g[1], g[2], g[3], g[4],
		0, 1, 0, g[1], g[2], g[3], g[4],
		0, 0, 0, b[1], b[2], b[3], b[4],
		0, 0, 1, b[1], b[2], b[3], b[4],
	}
	return create_mesh{"p3|c4", axis_vb}
end

function ientity.axis_entity_data(name, scene, color, material)
	local mesh = axis_mesh(color)
	return simple_render_entity_data(name, material or "/pkg/ant.resources/materials/line_background.material", mesh, scene, color)
end

function ientity.create_axis_entity(name, scene, color, material)
	return ecs.create_entity(ientity.axis_entity_data(name, scene, color, material))
end

function ientity.create_screen_axis_entity(name, screen_3dobj, scene, color, material)
	local mesh = axis_mesh(color)
	return ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.objcontroller|screen_3dobj",
			"ant.general|name",
		},
		data = {
			screen_3dobj = screen_3dobj,
			scene 		= scene or {},
			material	= "/pkg/ant.resources/materials/line_background.material",
			simplemesh	= imesh.init_mesh(mesh, true),
			visible_state= "main_view|auxgeom",
			name		= name,
		}
	}
end

function ientity.create_line_entity(name, p0, p1, scene, color, hide)
	local ic = color and ((math.floor(color[1] * 255) & 0xFF) | ((math.floor(color[2] * 255) & 0xFF) << 8)| ((math.floor(color[3] * 255) & 0xFF) << 16)| ((math.floor(color[4] * 255) & 0xFF) << 24)) or 0xffffffff
	local vb = {
		p0[1], p0[2], p0[3], ic,
		p1[1], p1[2], p1[3], ic,
	}
	local mesh = create_mesh({"p3|c40niu", vb}, {0, 1})
	return create_simple_render_entity(name, "/pkg/ant.resources/materials/line_color.material", mesh, scene, color, hide)
	
end

function ientity.create_circle_entity(name, radius, slices, scene, color, hide)
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
	return create_simple_render_entity(name, "/pkg/ant.resources/materials/line_color.material", mesh, scene, color, hide)
end

function ientity.create_circle_mesh_entity(name, radius, slices, mtl, scene, color, hide)
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
	return create_simple_render_entity(name, mtl, mesh, scene, color, hide)
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
    return ecs.reate_entity {
		policy = {
			"ant.sky|skybox",
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
            scene = {},
			material = material or "/pkg/ant.resources/materials/sky/skybox.material",
			visible_state = "main_view",
			ibl = {
				irradiance = {size=64},
				prefilter = {size=256},
				LUT = {size=256},
			},
			name = "sky_box",
			skybox = {},
			owned_mesh_buffer = true,
			simplemesh = get_skybox_mesh(),
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
    return ecs.create_entity {
		policy = {
			"ant.render|simplerender",
			"ant.sky|procedural_sky",
			"ant.general|name",
		},
		data = {
            scene = {},
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
			visible_state = "main_view",
			owned_mesh_buffer = true,
			simplemesh = create_sky_mesh(32, 32),
			name = "procedural sky",
		}
	}
end

function ientity.create_gamma_test_entity()
	ecs.create_entity {
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
					handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("ffff", {
						100, 200, 0.0, 0.0,
						100, 132, 0.0, 1.0,
						420, 200, 1.0, 0.0,
						420, 132, 1.0, 1.0,
					}), declmgr.get "p2|t2".handle)
                }
            },
			owned_mesh_buffer = true,
            scene = {},
            visible_state = "main_view",
        }
    }
end

--forward to z-axis, as 1 size
local function arrow_mesh(headratio, arrowlen, coneradius, cylinderradius)
	arrowlen = arrowlen or 1
	headratio = headratio or 0.15
	local headlen<const> = arrowlen * (1.0-headratio)
	local fmt<const> = "fff"
	local layout<const> = declmgr.get "p3"

	coneradius	= coneradius or 0.1
	cylinderradius	= cylinderradius or coneradius * 0.5
	local slicenum<const> 		= 10
	local deltaradian<const> 	= math.pi*2/slicenum

	local numv<const>			= slicenum*3+3	--3 center points
	local vb = bgfx.memory_buffer(layout.stride*numv)
	local function add_v(idx, x, y, z)
		local vboffset = layout.stride*idx+1
		vb[vboffset] = fmt:pack(x, y, z)
	end

	add_v(0,0.0, 0.0, arrowlen)
	add_v(1,0.0, 0.0, headlen)
	add_v(2,0.0, 0.0, 0.0)

	local offset=3

	for i=0, slicenum-1 do
		local r = deltaradian*i
		local c, s = math.cos(r), math.sin(r)
		local idx = i+offset
		add_v(idx,	c*coneradius, s*coneradius, headlen)

		local idx1 = idx+slicenum
		add_v(idx1,	c*cylinderradius, s*cylinderradius, headlen)
		
		local idx2 = idx1+slicenum
		add_v(idx2, c*cylinderradius, s*cylinderradius, 0.0)
	end

	local numtri<const>		= slicenum*5	--3 circle + 1 quad
	local ibstride<const>	= 2
	local numi<const>		= numtri*3
	local ib = bgfx.memory_buffer(ibstride*numtri*3)
	local ibfmt<const> = "HHH"
	local iboffset = 1
	local function add_t(i0, i1, i2)
		ib[iboffset] = ibfmt:pack(i0, i1, i2)
		iboffset = iboffset + ibstride*3
	end

	local ic1, ic2, ic3 = 0, 1, 2
	local cc1 = ic3+1
	local cc2 = cc1+slicenum
	local cc3 = cc2+slicenum

	--
	for i=0, slicenum-1 do
		--cone
		do
			local i2, i3 = cc1+i, cc1+i+1
			if i == slicenum-1 then
				i3 = cc1
			end
			add_t(ic1, i2, i3)
			add_t(ic2, i3, i2)
		end

		do
			--cylinder quad
			local v0 = cc2+i
			local v1 = cc3+i
			local v2 = v1+1
			local v3 = v0+1

			if i == slicenum-1 then
				v2 = cc3
				v3 = cc2
			end
			
			add_t(v0, v1, v2)
			add_t(v2, v3, v0)

			add_t(ic3, v2, v1)
		end
	end
	return {
		vb = {
			start = 0,
			num = numv,
			handle = bgfx.create_vertex_buffer(vb, layout.handle)
		},
		ib = {
			start = 0,
			num = numi,
			handle = bgfx.create_index_buffer(ib)
		}
	}
end

ientity.arrow_mesh = arrow_mesh

function ientity.create_arrow_entity(headratio, color, material, scene)
	return ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			simplemesh = arrow_mesh(headratio),
			material = material,
			visible_state = "main_view",
			scene = scene or {},
			name = "arrow",
			on_ready = function (e)
				imaterial.set_property(e, "u_color", math3d.vector(color))
			end
		}
	}
end

function ientity.create_quad_lines_entity(name, scene, material, quadnum, width, hide)
    assert(quadnum > 0)
    local hw = width * 0.5
    local function create_vertex_buffer()
        local x0, x1 = -hw, hw
        local z = 0.0
        local vertices = {}
        local fmt = "fffff"
        local u, v = 0.0, 0.0
        for i=0, quadnum do
            vertices[#vertices+1] = fmt:pack(x0, 0.0, z, 0.0, v)
            vertices[#vertices+1] = fmt:pack(x1, 0.0, z, 1.0, v)

            z = z + width
            v = v+1.0
        end

        return bgfx.create_vertex_buffer(bgfx.memory_buffer(table.concat(vertices)), declmgr.get "p3|t2".handle)
    end

	local function create_index_buffer()
		--local def_ib<const> = 
		local ib = {0, 2, 1, 2, 3, 1}
		for i=2, quadnum do
			local d = 2 * (i-1)
			ib[#ib+1] = ib[1] + d
			ib[#ib+1] = ib[2] + d
			ib[#ib+1] = ib[3] + d

			ib[#ib+1] = ib[4] + d
			ib[#ib+1] = ib[5] + d
			ib[#ib+1] = ib[6] + d
		end

		return bgfx.create_index_buffer(bgfx.memory_buffer("w", ib))
	end

    return ecs.create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
			scene = scene or {},
			visible_state = "",
            simplemesh = {
                vb = {
                    start = 0,
                    num = (quadnum+1)*2,
                    handle = create_vertex_buffer(),
                },
                ib = {
                    start = 0,
                    num = 0,
                    handle = create_index_buffer(),
                }
            },
			material = material,
			name = name,
			on_ready = function (e)
				ivs.set_state(e, "main_view", not hide)
			end
        }
    }
end
