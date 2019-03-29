local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local fbmgr = require "framebuffer_mgr"

local ms = import_package "ant.math".stack
local ru = require "util"

ecs.tag "main_queue"
ecs.component_alias("view_tag", "string")

ecs.component_alias("viewid", "int", 0)

local renderbuffer = ecs.component "render_buffer"
	.format "string"
	.flags "string"
	.w "real" (1)
	.h "real" (1)
	.layers "real" (1)

function renderbuffer:init()
	if not self.handle then
		self.handle = bgfx.create_texture2d(self.w, self.h, false, self.layers, self.format, self.flags)
	end
	return self
end

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
end

local fb = ecs.component "frame_buffer" 
	.render_buffers "render_buffer[]"
	["opt"].manager_buffer "boolean" (true)
	

function fb:init()
	local handles = {}
	for _, rb in ipairs(self.render_buffers) do
		handles[#handles+1] = rb.handle
	end
	assert(#handles > 0)
	self.handle = bgfx.create_frame_buffer(handles, self.manager_buffer or true)
	return self
end

local rt = ecs.component "render_target" {depend = "viewid"}
	.viewport "viewport"
	["opt"].frame_buffer "frame_buffer"
	["opt"].wnd_frame_buffer "wnd_frame_buffer"	

function rt:postinit(e)
	local viewid = e.viewid
	local fb = self.frame_buffer or self.wnd_frame_buffer
	if fb then
		bgfx.set_view_frame_buffer(viewid, assert(fb.handle))
		fbmgr.bind(viewid, fb)
	else
		local fb = fbmgr.get(viewid)
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

local cs = ecs.component "clear_state"
    .color "int" (0x303030ff)
    .depth "int" (1)
    .stencil "int" (0)

function cs:init()
    self.clear_color = true
    self.clear_depth = true
	self.clear_stencil = true
	return self
end

ecs.component "rect"
	.x "real" (0)
	.y "real" (0)
	.w "real" (1)
	.h "real" (1)
local vp = 
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
rendersys.dependby "end_frame"

local function update_viewport(viewid, viewport)
	local clear_state = viewport.clear_state	
	local cs = clear_state
	local state = ''
	if cs.clear_color then
		state = state .. "C"
	end
	if cs.clear_depth then
		state = state .. "D"
	end

	if cs.clear_stencil then
		state = state .. "S"
	end
	if state ~= '' then
		bgfx.set_view_clear(viewid, state, cs.color, cs.depth, cs.stencil)
	end

	local rt = viewport.rect
	bgfx.set_view_rect(viewid, rt.x, rt.y, rt.w, rt.h)
end

local function update_view_proj(viewid, camera)
	local view, proj = ms:view_proj(camera, camera.frustum)
	bgfx.set_view_transform(viewid, view, proj)
end

function rendersys:update()
	for _, eid in world:each "viewid" do
		local rq = world[eid]
		if rq.visible ~= false then
			local viewid = rq.viewid		
			update_viewport(viewid, rq.render_target.viewport)
			update_view_proj(viewid, rq.camera)

			local filter = rq.primitive_filter
			local render_properties = filter.render_properties
			local results = filter.result

			local function draw_primitives(viewid, result, render_properties)
				local numopaque = result.cacheidx - 1
				for i=1, numopaque do
					local prim = result[i]
					ru.draw_primitive(viewid, prim, prim.worldmat, render_properties)
				end
			end

			draw_primitives(viewid, results.opaque, render_properties)
			draw_primitives(viewid, results.translucent, render_properties)
		end
		
	end
end

local render_math_adapter = ecs.system "render_math_adapter"
local math3d_adapter = require "math3d.adapter"
function render_math_adapter:bind_math_adapter()
	bgfx.set_transform = math3d_adapter.matrix(ms, bgfx.set_transform, 1, 1)
	bgfx.set_view_transform = math3d_adapter.matrix(ms, bgfx.set_view_transform, 2, 2)
	bgfx.set_uniform = math3d_adapter.variant(ms, bgfx.set_uniform_matrix, bgfx.set_uniform_vector, 2)
	local idb = bgfx.instance_buffer_metatable()
	idb.pack = math3d_adapter.format(ms, idb.pack, idb.format, 3)
	idb.__call = idb.pack
end

