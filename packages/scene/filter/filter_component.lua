local ecs = ...

ecs.component_alias("view_tag", "string")
ecs.component_alias("filter_tag", "string")
ecs.component_alias("main_view", "boolean")
ecs.component_alias("blit_view", "boolean")

local pf = ecs.component "primitive_filter"
	.view_tag "view_tag" ("main_view")
	.filter_tag "filter_tag" ("can_render")	

local function default_properties()
	return {
		uniforms = {},
		textures = {},
	}
end

function pf:init()
	self.result = {
		translucent = {},
		opaticy = {},
	}
	self.render_properties = {
		lighting 	= default_properties(),
		shadow 		= default_properties(),
		postprocess = default_properties(),
	}

	return self
end