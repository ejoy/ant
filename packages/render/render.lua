local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local viewidmgr = require "viewid_mgr"

local ms = import_package "ant.math".stack
local ru = require "util"

ecs.tag "main_camera"
ecs.component_alias("view_tag", "string")

ecs.component_alias("viewid", "int", 0)

local renderbuffer = ecs.component "render_buffer"
	.format "string"
	.flags "string"
	.w "real" (1)
	.h "real" (1)
	.layers "real" (1)

function renderbuffer:init()
	self.handle = bgfx.create_texture2d(self.w, self.h, false, self.layers, self.format, self.flags)
end

local fb = ecs.component "frame_buffer" 
	['opt'].color "render_buffer"
	['opt'].depth "render_buffer"
function fb:init()
	local c, d = self.color, self.depth	
	if c or d then
		self.handle = bgfx.create_frame_buffer({c.handle, d.handle}, true)		
	end
end

local rt = ecs.component "render_target" {depend = "viewid"}
	.frame_buffers "frame_buffer[]"

function rt:postinit(e)
	if self then
		for _, fb in ipairs(self.frame_buffers) do
			bgfx.set_view_frame_buffer(e.viewid, fb)
		end
	end
end

ecs.component "rect"
	.x "real" (0)
	.y "real" (0)
	.w "real" (1)
	.h "real" (1)
local vp = 
ecs.component "viewport" {depend = "viewid"}
	.clear_state "clear_state"
	.rect "rect"

ecs.component "camera" {depend = "viewid"}
	.type "string" ("free")
	.eyepos	"vector"
	.viewdir "vector"
	.updir "vector"
	.frustum"frustum"	


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

		local viewid = rq.viewid
		update_viewport(viewid, rq.viewport)
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

