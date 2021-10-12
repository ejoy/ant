local ecs = ...
local world     = ecs.world
local math3d  	= require "math3d"
local bgfx 		= require "bgfx"
local ies 		= ecs.import.interface "ant.scene|ientity_state"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local geopkg 	= import_package "ant.geometry"
local geolib 	= geopkg.geometry
local geometry_drawer = geopkg.drawer

local m = {}

local function create_dynamic_mesh(layout, vb, ib)
	local declmgr = import_package "ant.render".declmgr
	local decl = declmgr.get(layout)
	return {
		vb = {
			{handle=bgfx.create_dynamic_vertex_buffer(bgfx.memory_buffer("fffd", vb), declmgr.get(layout).handle, "a")}
		},
		ib = {
			handle = bgfx.create_dynamic_index_buffer(bgfx.memory_buffer("w", ib), "a")
		}
	}
end

local function create_simple_render_entity(srt, material, name, mesh, color, visible, state)
	return ecs.create_entity {
		policy = {
			"ant.render|render",
			"ant.general|name",
		},
		data = {
			reference	= true,
			scene 		= {srt = srt or {}},
			material	= material,
			mesh		= mesh,
			state		= state or ies.create_state "visible",
			name		= name,-- or gen_test_name(),
			on_ready	= function (e)
				imaterial.set_property(e, "u_color", color)
				ies.set_state(e, "visible", visible and visible or false)
			end
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

local function do_create_entity(vb, ib, srt, name, color, hide)
	local mesh = create_dynamic_mesh("p3|c40niu", vb, ib)
	local visible = true
	if hide then
		visible = false
	end
	return create_simple_render_entity(srt, "/pkg/ant.resources/materials/line_color.material", name, mesh, color, visible)
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
    return do_create_entity(vb, ib, {}, name, color)
end

function m.create_dynamic_line(srt, p0, p1, name, color, hide)
	local vb = {
		p0[1], p0[2], p0[3], 0xffffffff,
		p1[1], p1[2], p1[3], 0xffffffff,
	}
	local ib = {0, 1}
    return do_create_entity(vb, ib, srt, name, color, hide)
end

function m.create_dynamic_lines(srt, vb, ib, name, color)
    return do_create_entity(vb, ib, srt, name, color)
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

function m.create_dynamic_circle(radius, slices, srt, name, color, hide)
	local vb, ib = m.get_circle_vb_ib(radius, slices)
	return do_create_entity(vb, ib, srt, name, color, hide)
end

function m.create_dynamic_aabb(srt, name, color, hide)
	local desc={vb={}, ib={}}
	local aabb_shape = {min={0,0,0}, max={1,1,1}}
	--local t = math3d.matrix{}
	geometry_drawer.draw_aabb_box(aabb_shape, 0xffffffff, nil, desc)
	local mesh = create_dynamic_mesh("p3|c40niu", desc.vb, desc.ib)
	return do_create_entity(desc.vb, desc.ib, srt, name, color, hide)
end

function m.get_aabb_vb_ib(aabb_shape, color)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_aabb_box(aabb_shape, color, nil, desc)
	return desc.vb, desc.ib
end

return m