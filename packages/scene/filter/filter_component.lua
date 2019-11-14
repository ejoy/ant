local ecs = ...

ecs.component_alias("filter_tag", "string")

local pf = ecs.component "primitive_filter"
	.filter_tag "filter_tag" ("can_render")	

function pf:init()
	self.result = {
		translucent = {},
		opaticy = {},
	}
	return self
end