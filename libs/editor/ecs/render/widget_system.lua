--luacheck: ignore self
local ecs = ...
local world = ecs.world



local ru = require "render.util"

ecs.component_struct "widget" {}

local widget_sys = ecs.system "widget_system"

widget_sys.depend "primitive_filter_system"
widget_sys.dependby "lighting_primitive_filter_system"
widget_sys.dependby "transparency_filter_system"

function widget_sys:update()
	local camera = world:first_entity("main_camera")

	local filter = assert(camera.primitive_filter)
	local result = assert(filter.result)

	for _, eid in world:each("widget") do
		local e = world[eid]
		local widget = e.widget

		if widget.can_render then
			local meshhandle = assert(widget.mesh).assetinfo.handle		
			local materials = assert(widget.material).content
			
			ru.insert_primitive(eid, meshhandle, materials, widget.srt, result)
		end
	end
end