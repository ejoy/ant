local ecs = ...
local world = ecs.world

ecs.import "libs"
ecs.import "editor"
ecs.import "inputmgr"

local lu = require "render.light.util"
local PVPScenLoader = require "test.samples.PVPScene.PVPSceneLoader"

local init_loader = ecs.system "init_loader"

init_loader.depend "shadow_primitive_filter_system"
init_loader.depend "transparency_filter_system"
init_loader.depend "entity_rendering"
init_loader.depend "camera_controller"

function init_loader:init()
	do
		lu.create_directional_light_entity(world, "directional_light")
		lu.create_ambient_light_entity(world, "ambient_light", "gradient", {1, 1, 1,1})
	end

	do
		PVPScenLoader.create_entitices(world)
	end
end
