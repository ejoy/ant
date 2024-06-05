local ecs	= ...
local world	= ecs.world
local w		= world.w

local bgfx		= require "bgfx"
local math3d	= require "math3d"
local MESH		= world:clibs "render.mesh"

local geometry_drawer	= import_package "ant.geometry".drawer
local setting			= import_package "ant.settings"
local layoutmgr			= import_package "ant.render".layoutmgr
local mc				= import_package "ant.math".constant

local widget_drawer_sys = ecs.system "widget_drawer_system"

local function create_dynamic_buffer(layout, num_vertices, num_indices)
	
	local decl = layoutmgr.get(layout)
	local vb_size = num_vertices * decl.stride
	assert(num_vertices <= 65535)
	local ib_size = num_indices * 2
	return {
		vb = {
			start = 0,
			num = 0,
			declname = "p3|c40niu",
			handle=bgfx.create_dynamic_vertex_buffer(vb_size, layoutmgr.get(layout).handle, "a"),
		},
		ib = {
			start = 0,
			num = 0,
			handle = bgfx.create_dynamic_index_buffer(ib_size, "a"),
		}
	}
end

function widget_drawer_sys:init()
	local wd = {
		vertices_num = 1024,
		indices_num = 2048,
		declname = "p3|c40niu",
	}
	world:create_entity {
		policy = {
			"ant.render|simplerender",
			"ant.widget|bounding_draw",
		},
		data = {
			scene = {},
			mesh_result = create_dynamic_buffer(wd.declname, wd.vertices_num, wd.indices_num),
			material = "/pkg/ant.resources/materials/line.material",
			render_layer = "translucent",
			visible = true,
			widget_drawer = wd,
		}
	}
end

function widget_drawer_sys:end_frame()
	local e = w:first "widget_drawer render_object:update"
	if e then
		local ro = e.render_object
		MESH.set_num(ro.mesh_idx, "vb0", 0)
		MESH.set_num(ro.mesh_idx, "ib", 0)
		w:submit(e)
	end
end

local iwd = {}

local DEFAULT_COLOR <const> = 0xffffff00

local function offset_ib(start_vertex, ib, startib, endib)
	startib = startib or 1
	endib = endib or #ib
	for i=startib, endib do
		ib[i] = ib[i] + start_vertex
	end
end

local function append_buffers(vbfmt, vb, ibfmt, ib)
	local numvertices = #vb // 4
	if numvertices == 0 then
		return
	end
	local e = w:first "widget_drawer render_object:update"
	local ro = e.render_object
	local _, vbnum, vbhandle = MESH.fetch(ro.mesh_idx, "vb0")

	local vertex_offset = vbnum
	bgfx.update(vbhandle, vertex_offset, bgfx.memory_buffer(vbfmt, vb));
	MESH.set_num(ro.mesh_idx, "vb0", vertex_offset + numvertices)
	local numindices = #ib
	if numindices ~= 0 then
		local _, ibnum, ibhandle = MESH.fetch(ro.mesh_idx, "ib")
		local index_offset = ibnum
		offset_ib(vertex_offset, ib)
		
		bgfx.update(ibhandle, index_offset, bgfx.memory_buffer(ibfmt, ib))
		local ib_num = index_offset + numindices
		MESH.set_num(ro.mesh_idx, "ib", ib_num)
	end
	w:submit(e)
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
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_box(shape, srt, color)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_box(shape.size, color or DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_capsule(shape, srt, color)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_capsule({
		tessellation = 2,
		height = shape.height,
		radius = shape.radius,
	}, color or DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_sphere(shape, srt, color)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_sphere({
		tessellation = 2,
		radius = shape.radius,
	}, color or DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_aabb_box(shape, srt, color)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_aabb_box(shape, color or DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_skeleton(ske, ani, srt, color)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_skeleton(ske, ani, color or DEFAULT_COLOR, srt, desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

local physic_bounding_sys = ecs.system "physic_bounding_system"

function physic_bounding_sys:widget()
	-- for _, eid in world:each "collider" do
	-- 	local e = world[eid]
	-- 	local collider = e.collider
	-- 	local srt = iom.srt(eid)
	-- 	if collider.box then
	-- 		for _, sh in ipairs(collider.box) do
	-- 			iwd.draw_box(sh, srt)
	-- 		end
	-- 	end
	-- 	if collider.capsule then
	-- 		for _, sh in ipairs(collider.capsule) do
	-- 			iwd.draw_capsule(sh, srt)
	-- 		end
	-- 	end
	-- 	if collider.sphere then
	-- 		for _, sh in ipairs(collider.sphere) do
	-- 			iwd.draw_sphere(sh, srt)
	-- 		end
	-- 	end
	-- end
end

local rmb_sys = ecs.system "render_mesh_bounding_system"

local SHOW_BOUNDING<const> = setting:get "debug/show_bounding"

if SHOW_BOUNDING then
	function rmb_sys:follow_scene_update()
		local desc={vb={}, ib={}}
		for e in w:select "visible render_object scene bounding:in" do
			local aabb = e.bounding.scene_aabb
			if aabb ~= mc.NULL then
				local minv, maxv = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
				local aabb_shape = {min=math3d.tovalue(minv), max=math3d.tovalue(maxv)}
				local voffset = #desc.vb//4
				local ibstart = #desc.ib
				geometry_drawer.draw_aabb_box(aabb_shape, DEFAULT_COLOR, nil, desc)

				if voffset ~= 0 then
					offset_ib(voffset, desc.ib, ibstart+1)
				end
			end
		end
	
		append_buffers("fffd", desc.vb, "w", desc.ib)
	end
end
return iwd
