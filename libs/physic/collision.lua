local ecs = ...
local world = ecs.world

ecs.component "collition" {
	shape = {
		type = "userdata",
		default = {
			type = "capsule",
			radius = 1,
			height = 2,
		}
	},
	obj = {
		type = "userdata",
		default = {

		}
	}
}
