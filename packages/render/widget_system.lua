local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local math3d = require "math3d"

local assetmgr = import_package "ant.asset"

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
bt.require_system "render_mesh_bounding_system"

local widget_drawer_sys = ecs.system "widget_drawer_system"

widget_drawer_sys.require_policy "ant.general|name"
widget_drawer_sys.require_policy "render"
widget_drawer_sys.require_policy "bounding_draw"

function widget_drawer_sys:init()
	local eid = world:create_entity {
		policy = {
			"ant.general|name",
			"ant.render|render",
			"ant.render|bounding_draw",
		},
		data = {
			transform 		= {srt = mu.srt()},
			material 		= "/pkg/ant.resources/materials/line.material",
			rendermesh 		= {},
			name 			= "mesh's bounding renderer",
			can_render 		= true,
			widget_drawer = true,
			scene_entity = true,
		}
	}

	world[eid].rendermesh = assetmgr.load("//res.mesh/bounding.rendermesh", computil.create_simple_dynamic_mesh("p3|c40niu", 1024, 2048))
end

function widget_drawer_sys:end_frame()
	local dmesh = world:singleton_entity "widget_drawer"
	if dmesh then
		local meshscene = dmesh.rendermesh
		local _, scene = next(meshscene.scenes)
		local _, meshnode = next(scene)
		local group = meshnode[1]
		local vbdesc, ibdesc = group.vb, group.ib
		vbdesc.start, vbdesc.num = 0, 0
		ibdesc.start, ibdesc.num = 0, 0

		vbdesc.handles[1].updateoffset = 0
		ibdesc.updateoffset = 0
	end
end

local iwd = ecs.interface "iwidget_drawer"

iwd.require_system "widget_drawer_system"

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
	local meshscene = dmesh.rendermesh
	local scene = meshscene.scenes[meshscene.default_scene]
	local _, meshnode = next(scene)
	local group = meshnode[1]

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

function iwd.draw_lines(shape, srt)
	local desc = {vb={"fffd"}, ib={}}
	geometry_drawer.draw_line(shape, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function iwd.draw_box(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_box(shape.size, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function iwd.draw_capsule(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_capsule({
		tessellation = 2,
		height = shape.height,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function iwd.draw_sphere(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_sphere({
		tessellation = 2,
		radius = shape.radius,
	}, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function iwd.draw_aabb_box(shape, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_aabb_box(shape, DEFAULT_COLOR, apply_srt(shape, srt), desc)
	append_buffers(desc.vb, desc.ib)
end

function iwd.draw_skeleton(ske, ani, srt)
	local desc={vb={"fffd"}, ib={}}
	geometry_drawer.draw_skeleton(ske, ani, DEFAULT_COLOR, srt, desc)
	append_buffers(desc.vb, desc.ib)
end

local physic_bounding_sys = ecs.system "physic_bounding_system"
physic_bounding_sys.require_interface "iwidget_drawer"

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

rmb_sys.require_system "widget_drawer_system"

function rmb_sys:widget()
	-- local transformed_boundings = {}
	-- computil.get_mainqueue_transform_boundings(world, transformed_boundings)
	-- for _, tb in ipairs(transformed_boundings) do
	-- 	local aabbmin, aabbmax = math3d.index(tb, 1), math3d.index(tb, 2)
	-- 	iwd.draw_aabb_box{min=math3d.totable(aabbmin), max=math3d.totable(aabbmax)}
	-- end
end