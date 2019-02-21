--luacheck: ignore self
local ecs = ...
local world = ecs.world
local schema = ecs.schema


local ru = import_package "ant.render".util
local ms = import_package "ant.math".stack

schema:type "widget"
	.mesh "mesh"
	.material "material"
	.srt "srt"
	.can_render "boolean"

local widget_sys = ecs.system "widget_system"

widget_sys.depend "primitive_filter_system"
widget_sys.dependby "lighting_primitive_filter_system"
widget_sys.dependby "transparency_filter_system"

function widget_sys:update()
	local camera = world:first_entity("main_camera")

	local filter = assert(camera.primitive_filter)
	for _, eid in world:each("widget") do
		local e = world[eid]
		local widget = e.widget

		if widget.can_render then
			local meshhandle = assert(widget.mesh).assetinfo.handle		
			local materials = assert(widget.material).content

			local srt = widget.srt
			local mat = ms({type="srt", s=srt.s, r=srt.r, t=srt.t}, "m")
			ru.insert_primitive(eid, meshhandle, materials, mat, filter)
		end
	end
end