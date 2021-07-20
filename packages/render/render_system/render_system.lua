local ecs = ...
local world = ecs.world

local isp		= world:interface "ant.render|system_properties"

local render_sys = ecs.system "render_system"

function render_sys:update_system_properties()
	isp.update()
end
