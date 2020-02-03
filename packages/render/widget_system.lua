local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local ms = mathpkg.stack

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
	local numvertices = (#vb - 1) // 4

	if numvertices == 0 then
		return 
	end
	
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

function rmb:widget()
	local dmesh = world:singleton_entity "widget_drawer"

	local transformed_boundings = {}
	computil.calc_transform_boundings(world, transformed_boundings)

	local vb, ib = {"fffd"}, {}
	for _, tb in ipairs(transformed_boundings) do
		add_aabb_bounding(tb:get "aabb", vb, ib, 0xffff00ff)
	end

	append_buffers(dmesh, vb, ib)
end

local function apply_srt(shape, srt)
	if not srt then
		return {
			s = {1,1,1,0},
			r = {0,0,0,0},
			t = ms(shape.origin, "P"),
		}
	end
	return {
		s = srt.s,
		r = srt.r,
		t = ms(srt.t, shape.origin, "+P"),
	}
end
local function draw_box(shape, srt, vb, ib)
	srt = apply_srt(shape, srt)
	local color <const> = 0xffffff00
	local desc={vb={}, ib={}}
	geometry_drawer.draw_box(shape.size, color, srt, desc)
	append_buffer(desc, vb, ib)
end
local function draw_capsule(shape, srt, vb, ib)
	srt = apply_srt(shape, srt)
	local color <const> = 0xffffff00
	local desc={vb={}, ib={}}
	geometry_drawer.draw_capsule({
		tessellation = 2,
		height = shape.height,
		radius = shape.radius,
	}, color, srt, desc)
	append_buffer(desc, vb, ib)
end
local function draw_sphere(shape, srt, vb, ib)
	srt = apply_srt(shape, srt)
	local color <const> = 0xffffff00
	local desc={vb={}, ib={}}
	geometry_drawer.draw_sphere({
		tessellation = 2,
		radius = shape.radius,
	}, color, srt, desc)
	append_buffer(desc, vb, ib)
end
local function draw_compound(shape, srt, vb, ib)
	srt = apply_srt(shape, srt)
	if shape.box then
		for _, sh in ipairs(shape.box) do
			draw_box(sh, srt, vb, ib)
		end
	end
	if shape.capsule then
		for _, sh in ipairs(shape.capsule) do
			draw_capsule(sh, srt, vb, ib)
		end
	end
	if shape.sphere then
		for _, sh in ipairs(shape.sphere) do
			draw_sphere(sh, srt, vb, ib)
		end
	end
	if shape.compound then
		for _, sh in ipairs(shape.compound) do
			draw_compound(sh, srt, vb, ib)
		end
	end
end

local phy_bounding = ecs.system "physic_bounding"
phy_bounding.require_system "ant.scene|primitive_filter_system"
phy_bounding.require_system "ant.render|reset_mesh_buffer"
phy_bounding.require_system "ant.bullet|collider_system"

function phy_bounding:widget()
	local dmesh = world:singleton_entity "widget_drawer"
	local vb, ib = {"fffd"}, {}
	for _, eid in world:each "collider" do
		local e = world[eid]
		local collider = e.collider
		local srt = e.transform
		if collider.sphere then
			draw_sphere(collider.sphere, srt, vb, ib)
		end
		if collider.box then
			draw_box(collider.box, srt, vb, ib)
		end
		if collider.capsule then
			draw_capsule(collider.capsule, srt, vb, ib)
		end
		if collider.compound then
			draw_compound(collider.compound, srt, vb, ib)
		end
	end
	if #vb > 1 then
		append_buffers(dmesh, vb, ib)
	end
end

local reset_bounding_buffer = ecs.system "reset_mesh_buffer"
function reset_bounding_buffer:end_frame()
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


local iwidget_drawer = ecs.interface "iwidget_drawer"


function iwidget_drawer.create()
	local eid = world:create_entity {
		policy = {
			"ant.render|name",
			"ant.render|render",
			"ant.render|bounding_draw",
		},
		data = {
			transform 		= mu.identity_transform(),
			material 		= {ref_path = "/pkg/ant.resources/depiction/materials/line.material"},
			rendermesh 		= {},
			name 			= "mesh's bounding renderer",
			can_render 		= true,
			widget_drawer = true,
		}
	}

	local rm = world[eid].rendermesh
	rm.reskey = assetmgr.register_resource(fs.path "//res.mesh/bounding.mesh", computil.create_simple_dynamic_mesh("p3|c40niu", 1024, 2048))
	return eid
end

function iwidget_drawer.draw_lines(points, transform)
	if #points % 2 ~= 0 then
		error(string.format("argument array must multiple of 2:%d", #points))
	end
	local dmesh = world:singleton_entity "widget_drawer"
	local desc = {vb={"fffd"}, ib={}}
	geometry_drawer.draw_line(points, 0xfff0f000, transform, desc)
	append_buffers(dmesh, desc.vb, desc.ib)
end

function iwidget_drawer.draw_box(size, transform)
end

function iwidget_drawer.draw_sphere(sphere, transform)
	local dmesh = world:singleton_entity "widget_drawer"
	local vb, ib = {"fffd"}, {}
	draw_sphere(sphere, transform, vb, ib)
	append_buffers(dmesh, vb, ib)
end
