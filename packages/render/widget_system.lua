--luacheck: ignore self
local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack

local mathbaselib = require "math3d.baselib"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local geometry_drawer = import_package "ant.geometry".drawer

local bgfx = require "bgfx"

ecs.component_alias("can_show_bounding", "boolean") {depend="can_render"}

ecs.tag "mesh_bounding_drawer_tag"

local rmb = ecs.system "render_mesh_bounding"
rmb.dependby "primitive_filter_system"

function rmb:init()
	local eid = world:create_entity {
		transform = mu.identity_transform(),
		material = computil.assign_material "/pkg/ant.resources/depiction/materials/line.material",
		rendermesh = {},
		name = "mesh's bounding renderer",
		can_render = true,
		main_view = true,
		mesh_bounding_drawer_tag = true,
		can_show_bounding = true,
	}

	local rm = world[eid].rendermesh
	rm.handle = computil.create_simple_dynamic_mesh("p3|c40niu", 1024, 2048)
end

local function reset_buffers(buffers)
	buffers.vb = {"fffd"}
	buffers.ib = {}
end

local function append_buffer(desc, buffers)
	local vb, ib = desc.vb, desc.ib
	local gvb, gib = buffers.vb, buffers.ib

	local offsetib = (#gvb - 1) // 4	--yes, gvb not gib
	table.move(vb, 1, #vb, #gvb+1, gvb)

	for _, i in ipairs(ib) do
		gib[#gib+1] = i + offsetib
	end
end

local function add_aabb_bounding(dmesh, aabb)
	local rm = dmesh.rendermesh

	local buffers = rm.buffers
	if buffers == nil then
		buffers = {}
		rm.buffers = buffers
		reset_buffers(buffers)
	end

	local desc={vb={}, ib={}}
	geometry_drawer.draw_aabb_box(aabb, 0xffffff00, nil, desc)

	append_buffer(desc, buffers)
end

local function update_buffers(dmesh)
	local rm = dmesh.rendermesh
	local meshscene = rm.handle
	local group = meshscene.scenes[1][1][1]
	local buffers = rm.buffers

	if buffers then
		local vb, ib = buffers.vb, buffers.ib

		group.vb.num = (#vb - 1) // 4
		group.ib.num = #ib
	
		group.vb.start = 0
		group.ib.start = 0
	
		bgfx.update(group.vb.handles[1], 0, vb)
		bgfx.update(group.ib.handle, 0, ib)
	
		reset_buffers(buffers)
	end
end

function rmb:update()
	local dmesh = world:first_entity "mesh_bounding_drawer_tag"

	local transformed_boundings = {}
	computil.calc_transform_boundings(world, transformed_boundings)

	for _, tb in ipairs(transformed_boundings) do
		add_aabb_bounding(dmesh, tb:get "aabb")
	end

	update_buffers(dmesh)
end