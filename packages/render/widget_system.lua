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
bdp.require_component "bounding_drawer"

local rmb = ecs.system "render_mesh_bounding"
rmb.step "widget"

rmb.dependby "primitive_filter_system"
rmb.dependby "reset_mesh_buffer"

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
	local iboffset = ib.updateoffset or 0

	bgfx.update(vbhandle.handle, vboffset, vb);
	vbhandle.updateoffset = (#vb - 1) / 4	-- 4 for 3 float and one dword
	bgfx.update(ibdesc.handle, iboffset, ib)
	ib.updateoffset = #ib * 2	-- 2 for uint16_t
end

function rmb:update()
	local dmesh = world:first_entity "bounding_drawer"

	local transformed_boundings = {}
	computil.calc_transform_boundings(world, transformed_boundings)

	local vb, ib = {"fffd"}, {}
	for _, tb in ipairs(transformed_boundings) do
		add_aabb_bounding(dmesh, tb:get "aabb")
	end

	update_buffers(dmesh, vb, ib)
end

local phy_bounding = ecs.system "physic_bounding"
phy_bounding.dependby "primitive_filter_system"
phy_bounding.dependby "reset_mesh_buffer"
phy_bounding.depend "collider_system"

function phy_bounding:update()
	local dmesh = world:first_entity "bounding_drawer"

	local vb, ib = {"fffd"}, {}
	for _, eid in world:each "collider_tag" do
		local e = world[eid]
		local collidercomp = assert(e[e.collider_tag])
		local colliderhandle = collidercomp.collider.handle

		local min, max = physicworld:aabb(colliderhandle)
		add_aabb_bounding({min=min, max=max}, vb, ib)
	end

	update_buffers(dmesh, vb, ib)
end

local reset_bounding_buffer = ecs.system "reset_mesh_buffer"
reset_bounding_buffer.step "end_frame"

reset_bounding_buffer.depend "end_frame"

function reset_bounding_buffer:update()
	local dmesh = world:first_entity "bounding_drawer"
	if dmesh then
		local meshscene = assetmgr.get_resource(dmesh.rendermesh.reskey)
		local group = meshscene.scenes[1][1][1]
		group.vb.handles[1].updateoffset = 0
		group.ib.updateoffset = 0
	end
end


local ray_cast_hitted = world:sub {"ray_cast_hitted"}

local draw_raycast_point = ecs.system "draw_raycast_point"
draw_raycast_point.step "widget"
draw_raycast_point.dependby "primitive_filter_system"
draw_raycast_point.depend "character_system"

function draw_raycast_point:update()
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