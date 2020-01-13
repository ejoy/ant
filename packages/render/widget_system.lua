--luacheck: ignore self
local ecs = ...
local world = ecs.world
local physicworld = world.args.Physics.world

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

ecs.tag "bounding_drawer"

local bdp = ecs.policy "bounding_draw"
bdp.unique_component "bounding_drawer"

ecs.component "debug_mesh_bounding"

local bt = ecs.policy "debug_mesh_bounding"
bt.require_component "debug_mesh_bounding"
bt.require_system "render_mesh_bounding"

local rmb = ecs.system "render_mesh_bounding"

rmb.require_system "ant.scene|primitive_filter_system"
rmb.require_system "ant.render|reset_mesh_buffer"

local function append_buffer(desc, gvb, gib)
	local vb, ib = desc.vb, desc.ib
	local offsetib = (#gvb - 1) // 4	--yes, gvb not gib
	table.move(vb, 1, #vb, #gvb+1, gvb)

	for _, i in ipairs(ib) do
		gib[#gib+1] = i + offsetib
	end
end

local function add_aabb_bounding(aabb, vb, ib, color)
	color = color or 0xffffff00

	local desc={vb={}, ib={}}
	geometry_drawer.draw_aabb_box(aabb, color, nil, desc)

	append_buffer(desc, vb, ib)
end

local function offset_ib(start_vertex, ib)
	local newib = {}
	for _, idx in ipairs(ib) do
		newib[#newib+1] = idx + start_vertex
	end
	return newib
end

local function append_buffers(dmesh, vb, ib)
	local rm = dmesh.rendermesh
	local meshscene = assetmgr.get_resource(rm.reskey)
	local group = meshscene.scenes[1][1][1]

	local vbdesc, ibdesc = group.vb, group.ib

	local numvertices = (#vb - 1) // 4
	local numindices = #ib

	vbdesc.num = vbdesc.num + numvertices
	ibdesc.num = ibdesc.num + numindices

	local vbhandle = vbdesc.handles[1]
	local vertex_offset = vbhandle.updateoffset or 0
	local index_offset = ibdesc.updateoffset or 0

	local newib = index_offset == 0 and ib or offset_ib(vertex_offset, ib)

	bgfx.update(vbhandle.handle, vertex_offset, vb);
	vbhandle.updateoffset = vertex_offset + numvertices
	bgfx.update(ibdesc.handle, index_offset, newib)
	ibdesc.updateoffset = index_offset + numindices
end

function rmb:widget()
	local dmesh = world:singleton_entity "bounding_drawer"

	local transformed_boundings = {}
	computil.calc_transform_boundings(world, transformed_boundings)

	local vb, ib = {"fffd"}, {}
	for _, tb in ipairs(transformed_boundings) do
		add_aabb_bounding(tb:get "aabb", vb, ib, 0xffff00ff)
	end

	append_buffers(dmesh, vb, ib)
end

local phy_bounding = ecs.system "physic_bounding"
phy_bounding.require_system "ant.scene|primitive_filter_system"
phy_bounding.require_system "ant.render|reset_mesh_buffer"
phy_bounding.require_system "ant.bullet|collider_system"

function phy_bounding:widget()
	local dmesh = world:singleton_entity "bounding_drawer"

	local vb, ib = {"fffd"}, {}
	for _, eid in world:each "collider_tag" do
		local e = world[eid]
		local collidercomp = assert(e[e.collider_tag])
		local colliderhandle = collidercomp.collider.handle

		local min, max = physicworld:aabb(colliderhandle)
		add_aabb_bounding({min=min, max=max}, vb, ib)
	end

	append_buffers(dmesh, vb, ib)
end

local reset_bounding_buffer = ecs.system "reset_mesh_buffer"
function reset_bounding_buffer:end_frame()
	local dmesh = world:singleton_entity "bounding_drawer"
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


local ray_cast_hitted = world:sub {"ray_cast_hitted"}

local draw_raycast_point = ecs.system "draw_raycast_point"
draw_raycast_point.require_system "ant.scene|primitive_filter_system"
draw_raycast_point.require_system "ant.bullet|character_collider_system"

function draw_raycast_point:widget()
    local vb, ib = {"fffd", }, {}
    for hitted in ray_cast_hitted:each() do
        local result = hitted[3]
        local pt = result.hit_pt_in_WS

		local len = 0.5
		local min = {-len, -len, -len,}
		local max = {len, len, len}
		min = ms(min, pt, "T")
		max = ms(max, pt, "T")
        add_aabb_bounding({min=min, max=max}, vb, ib)
	end
end