--luacheck: ignore self
local ecs = ...
local world = ecs.world

local ru = require "util"
local bgfx = require "bgfx"

local draw_entity_sys = ecs.system "entity_rendering"

draw_entity_sys.depend "view_system"
draw_entity_sys.depend "final_filter_system"

draw_entity_sys.dependby "end_frame"

local function draw_primitives(vid, result, mode, render_properties)
	if result and next(result) then
		bgfx.set_view_mode(vid, mode)
		for _, prim in ipairs(result) do
			ru.draw_primitive(vid, prim, prim.srt, render_properties)
		end
	end
end

function draw_entity_sys:update()
	for _, eid in world:each("camera") do
		local e = world[eid]
		local camera = e.camera
		local viewid = assert(camera.viewid)

		bgfx.touch(viewid)
		local filter = e.primitive_filter
		local render_properties = filter.render_properties
		draw_primitives(viewid, filter.result, "", render_properties)
		draw_primitives(viewid, filter.transparent_result, "D", render_properties)
	end
end