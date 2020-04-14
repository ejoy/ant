local ecs = ...
local world = ecs.world

ecs.import "ant.math"

local fbmgr 	= require "framebuffer_mgr"
local bgfx 		= require "bgfx"
local ru 		= require "util"

local math3d	= require "math3d"

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

ecs.tag "main_queue"
ecs.tag "blit_queue"
ecs.tag "blit_render"

local bq_p = ecs.policy "blit_queue"
bq_p.unique_component "blit_queue"

ecs.component_alias("viewid", "int", 0)
ecs.component_alias("view_mode", "string", "")

ecs.component_alias("fb_index", "int")
ecs.component_alias("rb_index", "int")

local mqp = ecs.policy "main_queue"
mqp.unique_component "main_queue"

local m = ecs.transform "render_target"
m.input "viewid"
m.output "render_target"
function m.process(e)
	local viewid = e.viewid
	local fb_idx = e.render_target.fb_idx
	if fb_idx then
		fbmgr.bind(viewid, fb_idx)
	else
		e.render_target.fb_idx = fbmgr.get_fb_idx(viewid)
	end
end

local rt = ecs.component "render_target"
	.viewport 	"viewport"
	["opt"].fb_idx 	"fb_index"

function rt:delete(e)
	fbmgr.unbind(e.viewid)
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

local cp = ecs.policy "camera"
cp.require_component "camera"

local et= ecs.transform "camera_transfrom"
et.output "camera"

function et.process(e)
	local lt = e.camera.lock_target
	if lt and e.parent == nil then
		error(string.format("'lock_target' defined in 'camera' component, but 'parent' component not define in entity"))
	end
end

ecs.component_alias("camera_eid", "entityid")
ecs.component_alias("visible", "boolean", true)

local rqp = ecs.policy "render_queue"
rqp.require_component "viewid"
rqp.require_component "render_target"
rqp.require_component "camera_eid"
rqp.require_component "primitive_filter"
rqp.require_component "visible"
rqp.require_transform "render_target"

local blit_render_sys = ecs.system "blit_render_system"
blit_render_sys.require_policy "blit_queue"
blit_render_sys.require_policy "blitrender"
blit_render_sys.require_policy "name"

function blit_render_sys:init_blit_render()
	log.info("init blit system")
    ru.create_blit_queue(world, {w=world.args.width,h=world.args.height})
end

local render_sys = ecs.system "render_system"

render_sys.require_singleton "render_properties"

render_sys.require_system "ant.scene|primitive_filter_system"
render_sys.require_system "ant.scene|scenespace_system"
render_sys.require_system "ant.scene|cull_system"

render_sys.require_system "load_properties_system"
render_sys.require_system "end_frame_system"
render_sys.require_system "viewport_detect_system"
render_sys.require_system "blit_render_system"

render_sys.require_policy "render_queue"
render_sys.require_policy "main_queue"
render_sys.require_policy "camera"
render_sys.require_policy "name"

local function update_view_proj(viewid, camera)
	local view = math3d.lookto(camera.eyepos, camera.viewdir)
	local proj = math3d.projmat(camera.frustum)
	bgfx.set_view_transform(viewid, view, proj)
end

function render_sys:init()
	ru.create_main_queue(world, {w=world.args.width,h=world.args.height})
end

function render_sys:render_commit()
	local render_properties = world:singleton "render_properties"
	for _, eid in world:each "viewid" do
		local rq = world[eid]
		if rq.visible then
			local viewid = rq.viewid
			ru.update_render_target(viewid, rq.render_target)
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

			bgfx.set_view_mode(viewid, rq.view_mode)

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

