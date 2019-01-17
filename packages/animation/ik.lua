local ecs = ...
local mathutil = (import_package "ant.math").util

local ik = ecs.component "ik" {
	target 		= mathutil.create_component_vector(),
	pole_vector = mathutil.create_component_vector(),
	mid_axis 	= mathutil.create_component_vector(),
	weight 		= 0.0,
	soften 		= 0.0,
	twist_angle = 0.0,
}

function ik:init()
	self.start_joint = -1
	self.mid_joint = -1
	self.end_joint = -1
	self.enable = false
end
