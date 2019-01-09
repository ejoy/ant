local ecs = ...
local world = ecs.world






ecs.import "inputmgr"

local computil = require "render.components.util"
local camerautil = require "render.camera.util"
local math = import_package "math"
local mu = math.util

local simplescene = ecs.system "simple_scene"

simplescene.depend "camera_init"

function simplescene:init()
	computil.create_gird_entity(world)

	local bunnyeid = world:new_entity(
		"position", "scale", "rotation",
		"mesh", "material", "can_render",
		"name"
	)

	local bunny = world[bunnyeid]
	bunny.name = "demo_bunny"

	mu.identify_transform(bunny)

	computil.load_mesh(bunny.mesh, "engine/assets/depiction/bunny.mesh")
	computil.load_material(bunny.material, {"depiction/bunny.material"})

	camerautil.focus_selected_obj(world, bunnyeid)
end