local ecs = ...
local world = ecs.world

local geometry_drawer = import_package "ant.geometry".drawer
local setting		= import_package "ant.settings".setting

local ies = world:interface "ant.scene|ientity_state"
local iom = world:interface "ant.objcontroller|obj_motion"

local bgfx = require "bgfx"
local math3d = require "math3d"

local widget_drawer_sys = ecs.system "widget_drawer_system"

local function create_dynamic_buffer(layout, num_vertices, num_indices)
	local declmgr = import_package "ant.render".declmgr
	local decl = declmgr.get(layout)
	local vb_size = num_vertices * decl.stride
	assert(num_vertices <= 65535)
	local ib_size = num_indices * 2
	return {
		vb = {
			start = 0,
			num = 0,
			{handle=bgfx.create_dynamic_vertex_buffer(vb_size, declmgr.get(layout).handle, "a")}
		},
		ib = {
			start = 0,
			num = 0,
			handle = bgfx.create_dynamic_index_buffer(ib_size, "a")
		}
	}
end

local wd_trans = ecs.transform "widget_drawer_transform"
function wd_trans.process_prefab(e)
	local wd = e.widget_drawer
	e.mesh = create_dynamic_buffer(wd.declname, wd.vertices_num, wd.indices_num)
end

local dmb_trans = ecs.transform "debug_mesh_bounding_transform"
function dmb_trans.process_entity(e)
	local rc = e._rendercache
	rc.debug_mesh_bounding = e.debug_mesh_bounding
end

function widget_drawer_sys:init()
	world:create_entity {
		policy = {
			"ant.render|render",
			"ant.render|bounding_draw",
			"ant.general|name",
		},
		data = {
			transform = {},
			material = "/pkg/ant.resources/materials/line.material",
			state = ies.create_state "visible",
			scene_entity = true,
			widget_drawer = {
				vertices_num = 1024,
				indices_num = 2048,
				declname = "p3|c40niu",
			},
			name = "bounding_draw"
		}
	}
end

function widget_drawer_sys:end_frame()
	local dmesh = world:singleton_entity "widget_drawer"
	if dmesh then
		local rc = dmesh._rendercache
		local vbdesc, ibdesc = rc.vb, rc.ib
		vbdesc.start, vbdesc.num = 0, 0
		ibdesc.start, ibdesc.num = 0, 0
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
	local rc = dmesh._rendercache
	local vbdesc, ibdesc = rc.vb, rc.ib

	local vertex_offset = vbdesc.num
	bgfx.update(vbdesc.handles[1], vertex_offset, bgfx.memory_buffer(vbfmt, vb));
	vbdesc.num = vertex_offset + numvertices

	local numindices = #ib
	if numindices ~= 0 then
		local index_offset = ibdesc.num
		local newib = index_offset == 0 and ib or offset_ib(vertex_offset, ib)
		bgfx.update(ibdesc.handle, index_offset, bgfx.memory_buffer(ibfmt, newib))
		ibdesc.num = index_offset + numindices
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
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_box(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_box(shape.size, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_capsule(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_capsule({
		tessellation = 2,
		height = shape.height,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_sphere(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_sphere({
		tessellation = 2,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_aabb_box(shape, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_aabb_box(shape, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

function iwd.draw_skeleton(ske, ani, srt)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_skeleton(ske, ani, DEFAULT_COLOR, srt, desc)
	append_buffers("fffd", desc.vb, "w", desc.ib)
end

local physic_bounding_sys = ecs.system "physic_bounding_system"

local iwd = world:interface "ant.render|iwidget_drawer"

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

function rmb_sys:widget()
	local sd  = setting:data()
	if sd.debug and sd.debug.show_bounding then
		local desc={vb={}, ib={}}
		for _, eid in world:each "debug_mesh_bounding" do
			local e = world[eid]
			local rc = e._rendercache
			if rc.debug_mesh_bounding and e._bounding and e._bounding.aabb then
				if rc and rc.vb and ies.can_visible(eid) then
					local aabb = rc.aabb
					local v = math3d.tovalue(aabb)
					local aabb_shape = {min=v, max={v[5], v[6], v[7]}}
					geometry_drawer.draw_aabb_box(aabb_shape, DEFAULT_COLOR, nil, desc)
				end
			end
		end
	
		append_buffers("fffd", desc.vb, "w", desc.ib)
	end
end