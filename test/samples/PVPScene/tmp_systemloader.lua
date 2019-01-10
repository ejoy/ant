local ecs = ...
local world = ecs.world

ecs.import "ant.libs"
ecs.import "ant.render"
ecs.import "ant.editor"
ecs.import "ant.inputmgr"
ecs.import "ant.serialize"
ecs.import "ant.scene"
ecs.import "ant.timer"

local lu = import_package "ant.render".light
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
