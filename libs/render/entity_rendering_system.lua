local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.view_system"
ecs.import "render.end_frame_system"
ecs.import "scene.filter.filter_system"

local ru = require "render.util"
local bgfx = require "bgfx"
local mu = require "math.util"

local draw_entity_sys = ecs.system "entity_rendering"

--draw_entity_sys.depend "add_entities_system"
draw_entity_sys.depend "view_system"
draw_entity_sys.depend "final_filter_system"

draw_entity_sys.dependby "end_frame"

draw_entity_sys.singleton "math_stack"

function draw_entity_sys:update()
	local ms = self.math_stack

	for _, eid in world:each("primitive_filter") do
		local e = world[eid]
		local viewid = assert(e.viewid)

		bgfx.touch(viewid)
		local filter = e.primitive_filter
		for _, r in ipairs {
								{result = filter.result, mode = "",},
								{result = filter.transparent_result, mode = "D",}	-- "D" for descending, meaning back to front
							} do
			local result = r.result
			if result and next(result) then
				bgfx.set_view_mode(viewid, r.mode)
				for _, prim in ipairs(r.result) do
					local srt = prim.srt
					local mat = ms({type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
					ru.draw_primitive(viewid, prim, mat)
				end
			end
		end
	end
end