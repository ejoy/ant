--luacheck: ignore self
local ecs = ...
local world = ecs.world





local ru = require "util"
local bgfx = require "bgfx"
local math = import_package "math"
local ms = math.stack

local draw_entity_sys = ecs.system "entity_rendering"

--draw_entity_sys.depend "add_entities_system"
draw_entity_sys.depend "view_system"
draw_entity_sys.depend "final_filter_system"

draw_entity_sys.dependby "end_frame"

function draw_entity_sys:update()
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