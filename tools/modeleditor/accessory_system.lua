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
	
	local dbgprim = sample.debug_primitive
	if dbgprim then		
		table.insert(self.debug_object.renderobjs.wireframe.desc, assert(dbgprim.cache.desc))
	end	
end