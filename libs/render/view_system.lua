local ecs = ...
local world = ecs.world

local ru = require "render.util"
local cu = require "render.components.util"
local mu = require "math.util"
local bgfx = require "bgfx"

--[@
local view_sys = ecs.system "view_system"
view_sys.singleton "math_stack"
function view_sys:update()
	ru.foreach_entity(world, cu.get_view_entity_components(),
	function (entity)
		local view_mat = self.math_stack(entity.position.v, entity.direction.v, "Lm")
		
		local frustum = assert(entity.frustum)
		local proj_mat = mu.proj_v(self.math_stack, frustum)
		bgfx.set_view_transform(entity.viewid.id, view_mat, proj_mat)
	end)
end
--@]