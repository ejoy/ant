local math3d  	= require "math3d"
local bgfx 		= require "bgfx"
local geolib
local world
local m = {}

local function create_dynamic_mesh(layout, vb, ib)
	local declmgr = import_package "ant.render".declmgr
	local decl = declmgr.get(layout)
	return {
		vb = {
			start = 0,
			num_vertices = #vb / decl.stride,
			{handle=bgfx.create_dynamic_vertex_buffer(bgfx.memory_buffer("fffd", vb), declmgr.get(layout).handle, "a")}
		},
		ib = {
			start = 0,
			num_indices = #ib,
			handle = bgfx.create_dynamic_index_buffer(bgfx.memory_buffer("w", ib), "a")
		}
	}
end

local function create_simple_render_entity(srt, material, name, mesh, state)
	return world:create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			transform	= srt or {},
			material	= material,
			mesh		= mesh,
			state		= state or ies.create_state "visible",
			name		= name,-- or gen_test_name(),
			scene_entity= true,
		}
	}
end

function m.get_frustum_vb(points, color)
    local vb = {}
    for i=1, #points do
        local p = math3d.totable(points[i])
        table.move(p, 1, 3, #vb+1, vb)
        vb[#vb+1] = color or 0xffffffff
    end
    return vb
end

function m.create_dynamic_frustum(frustum_points, name, color)
    local vb = m.get_frustum_vb(frustum_points, color)
    local ib = {
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
    local mesh = create_dynamic_mesh("p3|c40niu", vb, ib)
	return create_simple_render_entity(nil, "/pkg/ant.resources/materials/line.material", name, mesh)
end

function m.create_dynamic_line(srt, p0, p1, name, color)
	local vb = {
		p0[1], p0[2], p0[3], color or 0xffffffff,
		p1[1], p1[2], p1[3], color or 0xffffffff,
	}
    local mesh = create_dynamic_mesh("p3|c40niu", vb, {0, 1} )
	return create_simple_render_entity(srt, "/pkg/ant.resources/materials/line_singlecolor.material", name, mesh)
end

function m.get_circle_vb_ib(radius, slices, color)
	local circle_vb, circle_ib = geolib.circle(radius, slices)
	local gvb = {}
	--color = color or 0xffffffff
	for i = 1, #circle_vb, 3 do
		gvb[#gvb+1] = circle_vb[i]
		gvb[#gvb+1] = circle_vb[i + 1]
		gvb[#gvb+1] = circle_vb[i + 2]
		gvb[#gvb+1] = color or 0xffffffff
	end
	return gvb, circle_ib
end

function m.create_dynamic_circle(radius, slices, srt, name)
	-- local circle_vb, circle_ib = geolib.circle(radius, slices)
	-- local gvb = {}
	-- --color = color or 0xffffffff
	-- for i = 1, #circle_vb, 3 do
	-- 	gvb[#gvb+1] = circle_vb[i]
	-- 	gvb[#gvb+1] = circle_vb[i + 1]
	-- 	gvb[#gvb+1] = circle_vb[i + 2]
	-- 	gvb[#gvb+1] = 0xffffffff
	-- end
	local vb, ib = m.get_circle_vb_ib(radius, slices)
	local mesh = create_dynamic_mesh("p3|c40niu", vb, ib)
	return create_simple_render_entity(srt, "/pkg/ant.resources/materials/line_singlecolor.material", name, mesh)
end


return function(w)
	world = w
	local geopkg = import_package "ant.geometry"
	geolib = geopkg.geometry
    return m
end