--luacheck: ignore self
local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack

local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local mathbaselib = require "math3d.baselib"

local animodule = require "hierarchy.animation"

local renderpkg = import_package "ant.render"
local computil = renderpkg.components

local geometry_drawer = import_package "ant.geometry".drawer

local bgfx = require "bgfx"

ecs.component_alias("can_show_bounding", "boolean") {depend="can_render"}

ecs.tag "mesh_bounding_drawer_tag"

local bdp = ecs.policy "bounding_draw"
bdp.require_component "mesh_bounding_drawer_tag"
bdp.require_component "can_show_bounding"

local rmb = ecs.system "render_mesh_bounding"
rmb.dependby "primitive_filter_system"

function rmb:init()
	local eid = world:create_entity {
		policy = {
			"name",
			"render",
			"bounding_draw",
		},
		data = {
			transform = mu.identity_transform(),
			material = computil.assign_material "/pkg/ant.resources/depiction/materials/line.material",
			rendermesh = {},
			name = "mesh's bounding renderer",
			can_render = true,
			mesh_bounding_drawer_tag = true,
			can_show_bounding = true,
		}
	}

	local rm = world[eid].rendermesh
	rm.reskey = assetmgr.register_resource("//meshres/mesh_bounding.mesh", computil.create_simple_dynamic_mesh("p3|c40niu", 1024, 2048))
end

local function append_buffer(desc, gvb, gib)
	local vb, ib = desc.vb, desc.ib
	local offsetib = (#gvb - 1) // 4	--yes, gvb not gib
	table.move(vb, 1, #vb, #gvb+1, gvb)

	for _, i in ipairs(ib) do
		gib[#gib+1] = i + offsetib
	end
end

local function add_aabb_bounding(aabb, vb, ib)
	local desc={vb={}, ib={}}
	geometry_drawer.draw_aabb_box(aabb, 0xffffff00, nil, desc)

	append_buffer(desc, vb, ib)
end

local function update_buffers(dmesh, vb, ib)
	local rm = dmesh.rendermesh
	local meshscene = assetmgr.get_resource(rm.reskey)
	local group = meshscene.scenes[1][1][1]

	local vbdesc, ibdesc = group.vb, group.ib

	vbdesc.num = (#vb - 1) // 4
	ibdesc.num = #ib

	vbdesc.start = 0
	ibdesc.start = 0

	local vbhandle = vbdesc.handles[1]
	local vboffset = vbhandle.updateoffset or 0
	local iboffset = ib.updateoffset

	bgfx.update(vbhandle.handle, vboffset, vb);
	vbhandle.updateoffset = (#vb - 1) / 4	-- 4 for 3 float and one dword
	bgfx.update(ib.handle, iboffset, ib)
	ib.updateoffset = #ib * 2	-- 2 for uint16_t
end

function rmb:update()
	local dmesh = world:first_entity "mesh_bounding_drawer_tag"

	local transformed_boundings = {}
	computil.calc_transform_boundings(world, transformed_boundings)

	local vb, ib = {"fffd"}, {}
	for _, tb in ipairs(transformed_boundings) do
		add_aabb_bounding(dmesh, tb:get "aabb")
	end

	update_buffers(dmesh, vb, ib)
end

local phy_bounding = ecs.system "physic_bounding"
ecs.dependby "primitive_filter_system"

function phy_bounding:update()
	local dmesh = world:first_entity "mesh_bounding_drawer_tag"

	local vb, ib = {}, {}
	for _, eid in world:each "collider_tag" do
		local e = world[eid]
		local collidercomp = assert(e[e.collider_tag])
		local colliderhandle = collidercomp.collider.handle

		local min, max = colliderhandle:aabb()
		add_aabb_bounding({min=min, max=max}, vb, ib)
	end

	update_buffers(dmesh, vb, ib)
end