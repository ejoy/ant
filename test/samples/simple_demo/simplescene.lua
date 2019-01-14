local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local computil = require "render.components.util"
local camerautil = require "render.camera.util"
local math = import_package "ant.math"
local asset = import_package "ant.asset"

local mu = math.util

local simplescene = ecs.system "simple_scene"

simplescene.depend "camera_init"

function simplescene:init()
	computil.create_grid_entity(world)

	local bunnyeid = world:new_entity(
		"position", "scale", "rotation",
		"mesh", "material", "can_render",
		"name"
	)

	local bunny = world[bunnyeid]
	bunny.name = "demo_bunny"

	mu.identify_transform(bunny)

	computil.load_mesh(bunny.mesh, "engine", "bunny.mesh")
	computil.add_material(bunny.material, "engine", "bunny.material")

	camerautil.focus_selected_obj(world, bunnyeid)
end