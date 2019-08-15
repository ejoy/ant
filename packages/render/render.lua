local ecs = ...
local world = ecs.world

ecs.import "ant.scene"

local bgfx = require "bgfx"
local fbmgr = require "framebuffer_mgr"

local ms = import_package "ant.math".stack
local ru = require "util"

ecs.tag "main_queue"
ecs.component_alias("view_tag", "string")

ecs.component_alias("viewid", "int", 0)
ecs.component_alias("view_mode", "string", "")

local function delete_handle(self)
	if self.handle then
		bgfx.destroy(self.handle)
		self.handle = nil
	end
end

local renderbuffer = ecs.component "render_buffer"
	.format "string"
	.flags "string"
	.w "real" (1)
	.h "real" (1)
	.layers "real" (1)

function renderbuffer:init()
	if not self.handle then
		self.handle = ru.create_renderbuffer(self)
	end
	return self
end

renderbuffer.delete = delete_handle

local whandle = ecs.component "wnd_handle"
	.name "string" ("")

function whandle:init()
	local name = assert(self.name)
	self.handle = fbmgr.get_native_handle(name)
	return self
end

local nfb = ecs.component "wnd_frame_buffer"
	.wndhandle "wnd_handle"
	.w "int" (1)
	.h "int" (1)
	["opt"].color_format "string" ("")
	["opt"].depth_format "string" ("")

function nfb:init()
	local w = self.wndhandle
	self.handle = bgfx.create_frame_buffer(assert(w.handle), self.w, self.h, self.color_format, self.depth_format)
	return self
end

nfb.delete = delete_handle

local fb = ecs.component "frame_buffer" 
	.render_buffers "render_buffer[]"
	["opt"].manager_buffer "boolean" (true)
	

function fb:init()
	assert(self.handle == nil)
	self.handle = ru.create_framebuffer(self.render_buffers, self.manager_buffer)
	return self
end

function fb:delete()
	if not self.manager_buffer then
		delete_handle(self)
	end
end

local rt = ecs.component "render_target" {depend = "viewid"}
	.viewport "viewport"
	["opt"].frame_buffer "frame_buffer"
	["opt"].wnd_frame_buffer "wnd_frame_buffer"

function rt:postinit(e)
	local viewid = e.viewid
	local fb = self.frame_buffer or self.wnd_frame_buffer
	if fb then
		fbmgr.bind(viewid, fb)
		bgfx.set_view_frame_buffer(viewid, assert(fb.handle))
	else
		fb = fbmgr.get(viewid)
		if fb then
			if fb.wndhandle then
				self.wnd_frame_buffer = fb
			else
				self.frame_buffer = fb
			end
		end
	end
	return self
end

function rt:delete(e)
	local fb = self.frame_buffer or self.wnd_frame_buffer
	if fb then
		fbmgr.unbind(e.viewid)
		self.frame_buffer = nil
		self.wnd_frame_buffer = nil
	end
end

local cs = ecs.component "clear_state"
    .color "int" (0x303030ff)
    .depth "int" (1)
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

ecs.component "camera" {depend = "viewid"}
	.type "string" ("free")
	.eyepos	"vector"
	.viewdir "vector"
	.updir "vector"
	.frustum"frustum"	

ecs.component_alias("visible", "boolean", true) 



local rendersys = ecs.system "render_system"
rendersys.depend "primitive_filter_system"
rendersys.depend "filter_properties"
rendersys.dependby "end_frame"

local statemap = {
	all = "CDS",
	color = "C",
	depth = "D",
	stencil = "S",
	depthstencil = "DS",
	DS = "DS",
	C = "C",
	D = "D",
}

local function update_viewport(viewid, viewport)
	local cs = viewport.clear_state
	local clear_what = cs.clear
	local state = statemap[clear_what]
	if state then
		bgfx.set_view_clear(viewid, state, cs.color, cs.depth, cs.stencil)
	end

	local rt = viewport.rect
	bgfx.set_view_rect(viewid, rt.x, rt.y, rt.w, rt.h)
end

local function update_view_proj(viewid, camera)
	local view, proj = ms:view_proj(camera, camera.frustum)
	bgfx.set_view_transform(viewid, view, proj)
end

local function update_frame_buffer_view(viewid, rt)
	local fb = rt.frame_buffer or rt.wnd_frame_buffer
	if fb then
		local handle = fb.handle
		bgfx.set_view_frame_buffer(viewid, handle)
	end
end

function rendersys:update()
	for _, eid in world:each "viewid" do
		local rq = world[eid]
		if rq.visible ~= false then
			local viewid = rq.viewid
			local rt = rq.render_target
			-- TODO, only call after bgfx.reset has been call?
			update_frame_buffer_view(viewid, rt)
			
			update_viewport(viewid, rt.viewport)
			update_view_proj(viewid, rq.camera)

			local filter = rq.primitive_filter
			local render_properties = filter.render_properties
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

