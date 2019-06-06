local ecs = ...

ecs.component_alias("view_tag", "string")
ecs.component_alias("filter_tag", "string")
ecs.component_alias("main_view", "boolean")
ecs.component_alias("blit_view", "boolean")

-- ecs.component "handle"

-- ecs.component "mesh_vertices"
-- 	.handles "handle[]"

-- ecs.component "mesh_indices"
-- 	.handle "handle"

-- ecs.component "buffer_range"
-- 	.start "int" (0)
-- 	.num "int"	(0)

-- ecs.component "mesh_group"
-- 	.vb "mesh_vertices"
-- 	.ib "mesh_indices"
-- 	.prims "buffer_range[]"


-- ecs.component "render_prim"
-- 	.material "material_content[]"
-- 	.properties "properties"
-- 	.meshgroup "mesh_group"
	
-- ecs.component "filter_result"
-- 	.cast_shadow 	"render_prim[]"
-- 	.translucent	"render_prim[]"
-- 	.opaque	"render_prim[]"

-- ecs.component "render_properties"
-- 	.lighting "properties"
-- 	.shadow "properties"

local pf = 
ecs.component "primitive_filter"
	.view_tag "view_tag" ("main_view")
	.filter_tag "filter_tag" ("can_render")	
	-- .result "filter_result"
	-- .render_properties "render_properties"

function pf:init()
	local function default_properties()
		return {
			uniforms = {},
			textures = {},
		}
	end
	self.result = {
		cast_shadow = {},
		translucent = {},
		opaque = {},
	}
	self.render_properties = {
		lighting = default_properties(),
		shadow = default_properties(),
		postprocess = default_properties(),
	}

	return self
end