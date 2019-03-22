-- --luacheck: ignore self
local ecs = ...
local world = ecs.world

-- local ru = require "util"
local bgfx = require "bgfx"
local math3d_adapter = require "math3d.adapter"
local ms = import_package "ant.math".stack

-- local draw_entity_sys = ecs.system "entity_rendering"

-- draw_entity_sys.depend "view_system"
-- draw_entity_sys.depend "final_filter_system"

-- draw_entity_sys.dependby "end_frame"

-- local function draw_primitives(vid, result, mode, render_properties)
-- 	if result and next(result) then
-- 		bgfx.set_view_mode(vid, mode)
-- 		for _, prim in ipairs(result) do
-- 			ru.draw_primitive(vid, prim, prim.srt, render_properties)
-- 		end
-- 	end
-- end

-- function draw_entity_sys:update()
-- 	for _, eid in world:each("camera") do
-- 		local e = world[eid]
-- 		local camera = e.camera
-- 		local viewid = assert(camera.viewid)

-- 		bgfx.touch(viewid)
-- 		local filter = e.primitive_filter
-- 		local render_properties = filter.render_properties
-- 		draw_primitives(viewid, filter.result, "", render_properties)
-- 		draw_primitives(viewid, filter.transparent_result, "D", render_properties)
-- 	end
-- end

local render_math_adapter = ecs.system "render_math_adapter"
render_math_adapter.dependby "math_adapter"
function render_math_adapter:bind_math_adapter()
	bgfx.set_transform = math3d_adapter.matrix(ms, bgfx.set_transform, 1, 1)
	bgfx.set_view_transform = math3d_adapter.matrix(ms, bgfx.set_view_transform, 2, 2)
	bgfx.set_uniform = math3d_adapter.variant(ms, bgfx.set_uniform_matrix, bgfx.set_uniform_vector, 2)
	local idb = bgfx.instance_buffer_metatable()
	idb.pack = math3d_adapter.format(ms, idb.pack, idb.format, 3)
	idb.__call = idb.pack
end