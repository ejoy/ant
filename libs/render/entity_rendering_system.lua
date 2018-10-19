local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.view_system"
ecs.import "render.end_frame_system"
ecs.import "scene.filter_system"

local ru = require "render.util"
local bgfx = require "bgfx"
local math_util = require "math.util"

local draw_entity_sys = ecs.system "entity_rendering"

--draw_entity_sys.depend "add_entities_system"
draw_entity_sys.depend "view_system"
draw_entity_sys.depend "lighting_primitive_filter_system"
draw_entity_sys.depend "transparency_filter_system"

draw_entity_sys.dependby "end_frame"

draw_entity_sys.singleton "math_stack"

function draw_entity_sys:update()
    local camera = world:first_entity("main_camera")
	local main_viewid = camera.viewid.id
	bgfx.touch(main_viewid)

	local ms = self.math_stack
	
	local camera_view, camera_proj = math_util.view_proj_matrix( ms, camera )

	local filter = self.primitive_filter

	local results = {
		{result = filter.result, mode = "",},
		{result = filter.transparent_result, mode = "D",}	-- "D" for descending, meaning back to front
	}

	--bgfx.set_view_rect(main_viewid,0,0,ctx.width,ctx.height)
    bgfx.set_view_transform(main_viewid,ms(camera_view,"m"),ms(camera_proj,"m") )   -- (id->pointer) bgfx need pointer 
	
	for _, r in ipairs(results) do
		bgfx.set_view_mode(main_viewid, r.mode)
		for _, prim in ipairs(r.result) do
			local srt = prim.srt

			-- local t = ms(srt.t,"T")
            -- t[1] = t[1] - 2
            -- t[3] = t[3] - 2 
			-- ms(srt.t,{t[1],t[2],t[3]},"=")
			
			local mat = ms({type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
			ru.draw_primitive(main_viewid, prim, mat)

			-- t[1] = t[1] + 2
            -- t[3] = t[3] + 2
			-- ms(srt.t,{t[1],t[2],t[3]},"=")
			
		end
   
	end
end