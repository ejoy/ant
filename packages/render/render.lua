local ecs = ...
local world = ecs.world

local fbmgr 	= require "framebuffer_mgr"
local bgfx 		= require "bgfx"
local ru 		= require "util"

local math3d	= require "math3d"

local assetmgr  = import_package "ant.asset"

ecs.component "rendermesh" {}

ecs.component_alias("mesh", "resource")

local ml = ecs.transform "mesh_loader"

function ml.process(e, eid)
	local filename = tostring(e.mesh):gsub("%.%w+:", ".glbmesh")
	world:add_component(eid, "rendermesh", assetmgr.load(filename, e.mesh))
end

local c_rm = ecs.transform "create_rendermesh"

function c_rm.process(e, eid)
	world:add_component(eid, "rendermesh", {})
end

ecs.component_alias("material", "resource")

ecs.tag "blit_render"
ecs.tag "can_render"

ecs.tag "main_queue"
ecs.tag "blit_queue"

ecs.component_alias("viewid", "int", 0)
ecs.component_alias("view_mode", "string", "")

ecs.component_alias("fb_index", "int")
ecs.component_alias("rb_index", "int")

local rt = ecs.component "render_target"
	.viewport 			"viewport"
	.viewid				"viewid"
	["opt"].view_mode	"view_mode"
	["opt"].fb_idx 		"fb_index"

function rt:init()
	self.view_mode = self.view_mode or ""

	local viewid = self.viewid
	local fb_idx = self.fb_idx
	if fb_idx then
		fbmgr.bind(viewid, fb_idx)
	else
		self.fb_idx = fbmgr.get_fb_idx(viewid)
	end
	return self
end

function rt:delete()
	fbmgr.unbind(self.viewid)
end

local cs = ecs.component "clear_state"
    .color "int" (0x303030ff)
    .depth "real" (1)
	.stencil "int" (0)
	.clear "string" ("all")

ecs.component "rect"
	.x "real" (0)
	.y "real" (0)
	.w "real" (1)
	.h "real" (1)

ecs.component "viewport"
	.clear_state "clear_state"
	.rect "rect"

ecs.component "camera"
	.eyepos		"vector"
	.viewdir	"vector"
	.updir		"vector"
	.frustum	"frustum"
	["opt"].lock_target "lock_target"


local et= ecs.transform "camera_transfrom"

function et.process(e)
	local lt = e.camera.lock_target
	if lt and e.parent == nil then
		error(string.format("'lock_target' defined in 'camera' component, but 'parent' component not define in entity"))
	end
end

ecs.component_alias("camera_eid", "entityid")
ecs.component_alias("visible", "boolean", true)

local render_sys = ecs.system "render_system"

local function update_view_proj(viewid, camera)
	local view = math3d.lookto(camera.eyepos, camera.viewdir)
	local proj = math3d.projmat(camera.frustum)
	bgfx.set_view_transform(viewid, view, proj)
end

function render_sys:init()
	ru.create_main_queue(world, {w=world.args.width,h=world.args.height})
end

function render_sys:render_commit()
	local render_properties = world:interface "ant.render|render_properties".data()
	for _, eid in world:each "render_target" do
		local rq = world[eid]
		if rq.visible then
			local rt = rq.render_target
			local viewid = rt.viewid
			ru.update_render_target(viewid, rt)
			update_view_proj(viewid, world[rq.camera_eid].camera)

			local filter = rq.primitive_filter
			local results = filter.result

			local function draw_primitives(result)
				local visibleset = result.visible_set.n and result.visible_set or result
				for i=1, visibleset.n do
					local prim = visibleset[i]
					ru.draw_primitive(viewid, prim, prim.worldmat, render_properties)
				end
			end

			bgfx.set_view_mode(viewid, rt.view_mode)

			draw_primitives(results.opaticy)
			draw_primitives(results.translucent)
		end
		
	end
end

local mathadapter_util = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"
mathadapter_util.bind("bgfx", function ()
	bgfx.set_transform = math3d_adapter.matrix(bgfx.set_transform, 1, 1)
	bgfx.set_view_transform = math3d_adapter.matrix(bgfx.set_view_transform, 2, 2)
	bgfx.set_uniform = math3d_adapter.variant(bgfx.set_uniform_matrix, bgfx.set_uniform_vector, 2)
	local idb = bgfx.instance_buffer_metatable()
	idb.pack = math3d_adapter.format(idb.pack, idb.format, 3)
	idb.__call = idb.pack
end)

