local ecs = ...
local world = ecs.world

local ru = require "render.render_util"
local cu = require "render.components.util"
local bgfx = require "bgfx"

--[@
local camera_system = ecs.system "camera_system"
camera_system.singleton "math_stack"
camera_system.singleton "viewport"

function camera_system:update()
	ru.foreach_comp(world, cu.get_camera_component_names(),
	function (entity)
		local view_mat = self.math_stack(entity.position.v, entity.direction.v, "Lm")
	
		-- we should cache this by checking whether aspect is changed
		local vp = self.viewport
		local ci = vp.camera_info
		local frustum = assert(entity.frustum)

		local proj_mat = self.math_stack({type = "proj", fov=frustum.fov, aspect = vp.width/vp.height, n=frustum.near, f=frustum.far}, "m")		
		bgfx.set_view_transform(0, view_mat, proj_mat)
	end)
	
end
--@]