local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local math3d = require "math3d"
local geometry_drawer = import_package "ant.geometry".drawer
local bgfx = require "bgfx"
local widget_drawer_sys = ecs.system "widget_drawer_system"

local function create_dynamic_mesh(layout, num_vertices, num_indices)
	local declmgr = import_package "ant.render".declmgr
	local decl = declmgr.get(layout)
	local vb_size = num_vertices * decl.stride
	assert(num_vertices <= 65535)
	local ib_size = num_indices * 2
	return {
		vb = {
			start = 0,
			num = num_vertices,
			{handle=bgfx.create_dynamic_vertex_buffer(vb_size, declmgr.get(layout).handle, "a")}
		},
		ib = {
			start = 0,
			num = num_indices,
			handle = bgfx.create_dynamic_index_buffer(ib_size, "a")
		}
	}
end

local ies = world:interface "ant.scene|ientity_state"
function widget_drawer_sys:init()
	local eid = world:create_entity {
		policy = {
			"ant.render|render",
			"ant.render|bounding_draw",
		},
		data = {
			transform = mu.srt(),
			material = world.component "resource" "/pkg/ant.resources/materials/line.material",
			mesh = nil,
			state = ies.create_state "visible",
			scene_entity = true,
			widget_drawer = true,
		}
	}
	local dmesh = world[eid]
	dmesh.mesh = create_dynamic_mesh("p3|c40niu", 1024, 2048)
	dmesh.bounding_draw = {
		vertex_offset = 0,
		index_offset = 0,
	}
end

function widget_drawer_sys:end_frame()
	local dmesh = world:singleton_entity "widget_drawer"
	if dmesh then
		local mesh = dmesh.mesh
		local vbdesc, ibdesc = mesh.vb, mesh.ib
		vbdesc.start, vbdesc.num = 0, 0
		ibdesc.start, ibdesc.num = 0, 0

		dmesh.bounding_draw.vertex_offset = 0
		dmesh.bounding_draw.index_offset = 0
	end
end

local iwd = ecs.interface "iwidget_drawer"

local DEFAULT_COLOR <const> = 0xffffff00

local function offset_ib(start_vertex, ib)
	local newib = {}
	for _, idx in ipairs(ib) do
		newib[#newib+1] = idx + start_vertex
	end
	return newib
end

local function append_buffers(vbfmt, vb, ibfmt, ib)
	local numvertices = #vb // 4
	if numvertices == 0 then
		return
	end
	local dmesh = world:singleton_entity "widget_drawer"
	local bounding_draw = dmesh.bounding_draw
	local mesh = dmesh.mesh
	local vbdesc, ibdesc = mesh.vb, mesh.ib

	vbdesc.num = vbdesc.num + numvertices

	local vbhandle = vbdesc[1].handle
	local vertex_offset = bounding_draw.vertex_offset
	
	bgfx.update(vbhandle, vertex_offset, bgfx.memory_buffer(vbfmt, vb));
	bounding_draw.vertex_offset = vertex_offset + numvertices

	local numindices = #ib
	if numindices ~= 0 then
		ibdesc.num = ibdesc.num + numindices
		local index_offset = bounding_draw.index_offset
		local newib = index_offset == 0 and ib or offset_ib(vertex_offset, ib)
		bgfx.update(ibdesc.handle, index_offset, bgfx.memory_buffer(ibfmt, newib))
		bounding_draw.index_offset = index_offset + numindices
	end
end

local function apply_srt(shape, srt)
	if not shape.origin then
		return srt
	end
	if not srt then
		return math3d.matrix{
			t = shape.origin,
		}
	end
	return math3d.matrix{
		s = srt.s,
		r = srt.r,
		t = math3d.add(srt.t, shape.origin),
	}
end

function iwd.draw_lines(shape, srt, color)
	local desc = {vb={}, ib={}}
	geometry_drawer.draw_line(shape, color or DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "s", desc.ib)
end

function iwd.draw_box(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_box(shape.size, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "s", desc.ib)
end

function iwd.draw_capsule(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_capsule({
		tessellation = 2,
		height = shape.height,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "s", desc.ib)
end

function iwd.draw_sphere(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_sphere({
		tessellation = 2,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "s", desc.ib)
end

function iwd.draw_aabb_box(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_aabb_box(shape, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "s", desc.ib)
end

function iwd.draw_skeleton(ske, ani, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_skeleton(ske, ani, DEFAULT_COLOR, srt, desc)
	append_buffers("fffd", desc.vb, "s", desc.ib)
end

local physic_bounding_sys = ecs.system "physic_bounding_system"

local iwd = world:interface "ant.render|iwidget_drawer"

function physic_bounding_sys:widget()
	for _, eid in world:each "collider" do
		local e = world[eid]
		local collider = e.collider
		local srt = e.transform.srt
		if collider.box then
			for _, sh in ipairs(collider.box) do
				iwd.draw_box(sh, srt)
			end
		end
		if collider.capsule then
			for _, sh in ipairs(collider.capsule) do
				iwd.draw_capsule(sh, srt)
			end
		end
		if collider.sphere then
			for _, sh in ipairs(collider.sphere) do
				iwd.draw_sphere(sh, srt)
			end
		end
	end
end

local rmb_sys = ecs.system "render_mesh_bounding_system"

function rmb_sys:widget()
	-- local transformed_boundings = {}
	-- computil.get_mainqueue_transform_boundings(world, transformed_boundings)
	-- for _, tb in ipairs(transformed_boundings) do
	-- 	local aabbmin, aabbmax = math3d.index(tb, 1), math3d.index(tb, 2)
	-- 	iwd.draw_aabb_box{min=math3d.totable(aabbmin), max=math3d.totable(aabbmax)}
	-- end
end