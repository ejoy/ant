local ecs = ...
local world = ecs.world

ecs.component "rigid_body" {
	shapes = {
		type = "userdata",
		default = {},
	},
	obj = {
		type = "userdata",
		default = {},
	}
}
