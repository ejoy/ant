local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local math3d = require "math3d"

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local geometry_drawer = import_package "ant.geometry".drawer

local bgfx = require "bgfx"
local fs = require "filesystem"

ecs.tag "widget_drawer"

local bdp = ecs.policy "bounding_draw"
bdp.unique_component "widget_drawer"

ecs.component "debug_mesh_bounding"

local bt = ecs.policy "debug_mesh_bounding"
bt.require_component "debug_mesh_bounding"
bt.require_system "render_mesh_bounding"

local m = ecs.system "widget_drawer"

m.require_policy "name"
m.require_policy "render"
m.require_policy "bounding_draw"

function m:init()
	local eid = world:create_entity {
		policy = {
			"ant.render|name",
			"ant.render|render",
			"ant.render|bounding_draw",
		},
		data = {
			transform 		= {srt = mu.srt()},
			material 		= {ref_path = "/pkg/ant.resources/depiction/materials/line.material"},
			rendermesh 		= {},
			name 			= "mesh's bounding renderer",
			can_render 		= true,
			widget_drawer = true,
		}
	}

	local rm = world[eid].rendermesh
	rm.reskey = assetmgr.register_resource(fs.path "//res.mesh/bounding.mesh", computil.create_simple_dynamic_mesh("p3|c40niu", 1024, 2048))
end

function m:end_frame()
	local dmesh = world:singleton_entity "widget_drawer"
	if dmesh then
		local meshscene = assetmgr.get_resource(dmesh.rendermesh.reskey)
		local group = meshscene.scenes[1][1][1]
		local vbdesc, ibdesc = group.vb, group.ib
		vbdesc.start, vbdesc.num = 0, 0
		ibdesc.start, ibdesc.num = 0, 0

		vbdesc.handles[1].updateoffset = 0
		ibdesc.updateoffset = 0
	end
end

local m = ecs.interface "iwidget_drawer"

m.require_system "widget_drawer"

local DEFAULT_COLOR <const> = 0xffffff00

local function offset_ib(start_vertex, ib)
	local newib = {}
	for _, idx in ipairs(ib) do
		newib[#newib+1] = idx + start_vertex
	end
	return newib
end

local function append_buffers(vb, ib)
	local numvertices = (#vb - 1) // 4
	if numvertices == 0 then
		return
	end
	local dmesh = world:singleton_entity "widget_drawer"
	local rm = dmesh.rendermesh
	local meshscene = assetmgr.get_resource(rm.reskey)
	local group = meshscene.scenes[1][1][1]

	local vbdesc, ibdesc = group.vb, group.ib

	vbdesc.num = vbdesc.num + numvertices

	local vbhandle = vbdesc.handles[1]
	local vertex_offset = vbhandle.updateoffset or 0
	bgfx.update(vbhandle.handle, vertex_offset, vb);
	vbhandle.updateoffset = vertex_offset + numvertices

	local numindices = #ib
	if numindices ~= 0 then
		ibdesc.num = ibdesc.num + numindices
		local index_offset = ibdesc.updateoffset or 0
		local newib = index_offset == 0 and ib or offset_ib(vertex_offset, ib)
		bgfx.update(ibdesc.handle, index_offset, newib)
		ibdesc.updateoffset = index_offset + numindices
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

function m.draw_lines(shape, srt)
	local desc = {vb={"fffd"}, ib={}}
	geometry_drawer.draw_line(shape, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function m.draw_box(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_box(shape.size, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function m.draw_capsule(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_capsule({
		tessellation = 2,
		height = shape.height,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function m.draw_sphere(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_sphere({
		tessellation = 2,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function m.draw_aabb_box(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_aabb_box(shape, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function m.draw_skeleton(ske, ani, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_skeleton(ske, ani, DEFAULT_COLOR, srt, desc)
	append_buffers(desc.vb, desc.ib)
end

local m = ecs.system "physic_bounding"
m.require_interface "iwidget_drawer"

local iwd = world:interface "ant.render|iwidget_drawer"

function m:widget()
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

local rmb = ecs.system "render_mesh_bounding"

rmb.require_system "widget_drawer"

function rmb:widget()
	local transformed_boundings = {}
	computil.get_mainqueue_transform_boundings(world, transformed_boundings)
	for _, tb in ipairs(transformed_boundings) do
		-- local aabbmin, aabbmax = math3d.aabb_get(tb)
		-- iwd.draw_aabb_box(tb:get "aabb")
	end
end