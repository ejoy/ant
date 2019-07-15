local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local renderpkg = import_package "ant.render"
local computil = renderpkg.components
local camerautil = renderpkg.camera

local fs = require "filesystem"

local simplescene = ecs.system "simple_scene"

simplescene.dependby "message_system"
simplescene.dependby "final_filter"
simplescene.dependby "entity_rendering"

function simplescene:init()
	computil.create_grid_entity(world)

	local bunnyeid = world:create_entity {
		transform = mu.srt(),
		rendermesh = {},
		mesh = {ref_path = fs.path "/pkg/ant.resources/bunny.mesh",},
		material = computil.assign_material(fs.path "/pkg/ant.resources/materials/bunny.material"),
		name = "demo_bunny",
		can_render = true,
		main_view = true,
	}

	camerautil.focus_selected_obj(world, bunnyeid)
end