local ecs = ...
local world = ecs.world


ecs.import "editor.ecs.debug.debug_drawing"

local geodrawer = require "editor.ecs.render.geometry_drawer"

local renderbonesys = ecs.system "renderbone_system"
renderbonesys.singleton "debug_object"
renderbonesys.dependby "debug_draw"

function renderbonesys:init()
	local sample = world:first_entity("sampleobj")
	if sample then
		return 
	end
	
	local ske = sample.skeleton
	if ske then
		local desc = self.debug_object.renderobjs.wireframe.desc
		geodrawer.draw_bones(ske, 0xfff0f0f0, nil, desc)		
	end
end