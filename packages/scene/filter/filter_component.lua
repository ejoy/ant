local ecs = ...

ecs.component_alias("view_tag", "string")
ecs.component_alias("filter_tag", "string")

local primitive_filter = ecs.component "primitive_filter"
	.view_tag "view_tag" ("main_viewtag")
	.filter_tag "filter_tag" ("can_render")
	.no_lighting "boolean" (false)

ecs.component_alias("main_viewtag", "boolean")


function primitive_filter:init()
	self.result = {}
	self.render_properties = {
		lighting = {
			uniforms = {},
			textures = {},
		},
		shadow = {
			uniforms = {},
			textures = {},
		},
	}
	return self
end