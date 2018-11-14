local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"

ecs.import "scene.filter.filter_system"

ecs.import "inputmgr.message_system"


local computil = require "render.components.util"

local simplescene = ecs.system "simple_scene"
simplescene.singleton "math_stack"

function simplescene:init()
	local bunnyeid = world:new_entity(
		"position", "scale", "rotation",
		"mesh", "material", "can_render",
		"name"
	)

	local bunny = world[bunnyeid]
	bunny.name.n = "demo_bunny"

	local ms = self.math_stack
	ms(bunny.position, 	{0, 0, 0, 1}, 	"=")
	ms(bunny.scale, 	{1, 1, 1}, 		"=")
	ms(bunny.rotation, 	{0, 0, 0}, 		"=")

	computil.load_mesh(bunny.mesh, "/engine/assets/depiction/bunny.mesh")
	computil.load_material(bunny.material, "depiction/bunny.material")
end