local ecs = ...
local world = ecs.world

local render_util = require "render.render_util"
local bgfx = require "bgfx"

--[@
local camera_system = ecs.system "camera_system"
camera_system.singleton "math_stack"
camera_system.singleton "viewport"

function camera_system:update()
	render_util.for_each_comp(world, {"view_transform", "frustum"},
	function (entity)		
		local ct = assert(entity.view_transform)
		local view_mat = self.math_stack(ct.eye, ct.direction, "Lm")
	
		-- we should cache this by checking whether aspect is changed
		local vp = self.viewport
		local ci = vp.camera_info
		local frustum = assert(entity.frustum)
		frustum.proj_mat = self.math_stack({type = "proj", fov = ci.fov, aspect = vp.width/vp.height, n = ci.near, f = ci.far})
		local proj_mat = frustum.proj_mat
		bgfx.set_view_transform(0, view_mat, ~proj_mat)
	end)
	
end
--@]