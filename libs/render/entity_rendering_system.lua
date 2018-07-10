local ecs = ...
local world = ecs.world

local ru = require "render.util"
local bgfx = require "bgfx"

local draw_entity_sys = ecs.system "entity_rendering"

--draw_entity_sys.depend "add_entities_system"
draw_entity_sys.depend "view_system"
draw_entity_sys.depend "camera_controller"
draw_entity_sys.depend "lighting_primitive_filter_system"
draw_entity_sys.depend "transparency_filter_system"

draw_entity_sys.dependby "end_frame"

draw_entity_sys.singleton "math_stack"
draw_entity_sys.singleton "primitive_filter"

function draw_entity_sys:update()
    local camera = world:first_entity("main_camera")
    local main_viewid = camera.viewid.id
	bgfx.touch(main_viewid)
	
	local ms = self.math_stack
	
	local filter = self.primitive_filter

	local results = {
		{result = filter.result, mode = "",},
		{result = filter.transparent_result, mode = "D",}	-- "D" for descending, meaning back to front
	}
	
	for _, r in ipairs(results) do
		bgfx.set_view_mode(main_viewid, r.mode)
		for _, prim in ipairs(r.result) do
			local srt = prim.srt
			local mat = ms({type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
			ru.draw_primitive(main_viewid, prim, mat)
		end
    end
end