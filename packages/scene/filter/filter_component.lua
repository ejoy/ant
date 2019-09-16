local ecs = ...

ecs.component_alias("view_tag", "string")
ecs.component_alias("filter_tag", "string")
ecs.component_alias("main_view", "boolean")
ecs.component_alias("blit_view", "boolean")

local pf = ecs.component "primitive_filter"
	.view_tag "view_tag" ("main_view")
	.filter_tag "filter_tag" ("can_render")	

function pf:init()
	self.result = {
		translucent = {},
		opaticy = {},
	}
	return self
end