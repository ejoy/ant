local ecs = ...
local world = ecs.world

ecs.import "editor.ecs.debug.debug_drawing"

local renderbonesys = ecs.system "renderbone_system"
renderbonesys.singleton "debug_object"
renderbonesys.dependby "debug_draw"

function renderbonesys:update()
	local sample = world:first_entity("sampleobj")
	if sample then
		local dbgprim = sample.debug_primitive
		if dbgprim then
			local desc = dbgprim.cache.desc
			if desc then
				local descbuffer = self.debug_object.renderobjs.wireframe.desc
				local function append_array(from, to)				
					table.move(from, 1, #from, #to+1, to)
				end

				append_array(desc.vb, descbuffer.vb)
				append_array(desc.ib, descbuffer.ib)
				if desc.primitives then
					append_array(desc.primitives, descbuffer.primitives)
				end
			end
			
		end	
	end
end