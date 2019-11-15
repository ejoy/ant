local ecs = ...
local world = ecs.world

ecs.import "ant.scene"

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local fbmgr 	= require "framebuffer_mgr"
local camerautil= require "camera.util"

local bgfx 		= require "bgfx"
local ru 		= require "util"

ecs.tag "main_queue"
ecs.component_alias("blit_render", "can_render")

ecs.component_alias("viewid", "int", 0)
ecs.component_alias("view_mode", "string", "")

ecs.component_alias("fb_index", "int")
ecs.component_alias("rb_index", "int")

local rt = ecs.component "render_target" {depend = "viewid"}
	.viewport 	"viewport"
	["opt"].fb_idx 	"fb_index"

function rt:postinit(e)
	local viewid = e.viewid
	local fb_idx = self.fb_idx
	if fb_idx then
		fbmgr.bind(viewid, fb_idx)
	else
		self.fb_idx = fbmgr.get_fb_idx(viewid)
	end

	return self
end

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
	.type "string" ("free")
	.eyepos	"vector"
	.viewdir "vector"
	.updir "vector"
	.frustum"frustum"

ecs.component "camera_mgr"
    .cameras "camera{}"

ecs.component_alias("camera_tag", "string") {depend = "viewid"}
ecs.component_alias("visible", "boolean", true) 

local render_props = ecs.singleton "render_properties"
function render_props.init()
	return {
		lighting = {
			uniforms = {},
			textures = {},
		},
		shadow = {
			uniforms = {},
			textures = {},
		},
		postprocess = {
			uniforms = {},
			textures = {},
		}
	}
end

local rendersys = ecs.system "render_system"

rendersys.singleton "render_properties"

rendersys.depend "primitive_filter_system"
rendersys.depend "filter_properties"
rendersys.dependby "end_frame"

local function update_view_proj(viewid, camera)
	local view, proj = ms:view_proj(camera, camera.frustum)
	bgfx.set_view_transform(viewid, view, proj)
end

function rendersys:init()
	local fbsize = world.args.fb_size	
	ru.create_main_queue(world, fbsize, ms({1, 1, -1}, "inT"), {5, 5, -5})
	ru.create_blit_queue(world, {x=0, y=0, w=fbsize.w, h=fbsize.h})
end

function rendersys:update()
	local render_properties = self.render_properties
	for _, eid in world:each "viewid" do
		local rq = world[eid]
		if rq.visible ~= false then
			local viewid = rq.viewid
			ru.update_render_target(viewid, rq.render_target)
			update_view_proj(viewid, camerautil.get_camera(world, rq.camera_tag))

			local filter = rq.primitive_filter
			local results = filter.result

			local function draw_primitives(result)
				local num = result.cacheidx - 1
				local visibleset = result.visible_set
				if visibleset then
					for i=1, #visibleset do
						local idx = visibleset[i]
						local prim = result[idx]
						ru.draw_primitive(viewid, prim, prim.worldmat, render_properties)
					end
				else
					for i=1, num do
						local prim = result[i]
						ru.draw_primitive(viewid, prim, prim.worldmat, render_properties)
					end
				end
			end

			bgfx.set_view_mode(viewid, rq.view_mode)

			draw_primitives(results.opaticy)
			draw_primitives(results.translucent)
		end
		
	end
end

local before_render_system = ecs.system "before_render_system"
before_render_system.dependby "render_system"

function before_render_system:update()
	world:update_func("before_render")()
end

local mathadapter_util = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"
mathadapter_util.bind("bgfx", function ()
	bgfx.set_transform = math3d_adapter.matrix(ms, bgfx.set_transform, 1, 1)
	bgfx.set_view_transform = math3d_adapter.matrix(ms, bgfx.set_view_transform, 2, 2)
	bgfx.set_uniform = math3d_adapter.variant(ms, bgfx.set_uniform_matrix, bgfx.set_uniform_vector, 2)
	local idb = bgfx.instance_buffer_metatable()
	idb.pack = math3d_adapter.format(ms, idb.pack, idb.format, 3)
	idb.__call = idb.pack
end)

