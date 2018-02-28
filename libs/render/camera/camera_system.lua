local ecs = ...
local world = ecs.world

local render_util = require "render.render_util"
local bgfx = require "bgfx"

--[@
local camera_system = ecs.system "camera_system"
camera_system.singleton "math_stack"

function camera_system:update()
	render_util.for_each_comp(world, {"view_transform", "frustum"},
	function (entity)		
		local ct = assert(entity.view_transform)
		local view_mat = self.math_stack(ct.eye, ct.direction, "lP")
		local mat_str = self.math_stack(view_mat, "V")
		--print(mat_str)

		view_mat = self.math_stack(view_mat, "m")

		local frustum = assert(entity.frustum)
		local proj_mat = frustum.proj_mat
		bgfx.set_view_transform(0, view_mat, ~proj_mat)
	end)
	
end
--@]