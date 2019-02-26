local ecs = ...
local schema = ecs.schema

schema:type "primitive_filter"
	.view_tag "view_tag" ("main_viewtag")
	.filter_tag "filter_tag" ("can_render")
	.no_lighting "boolean" (false)


schema:typedef("main_viewtag", "boolean")

local primitive_filter = ecs.component "primitive_filter"

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