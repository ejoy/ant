local ecs = ...
local world = ecs.world

ecs.import "ant.render"
ecs.import "ant.editor"
ecs.import "ant.inputmgr"
ecs.import "ant.serialize"
ecs.import "ant.scene"
ecs.import "ant.timer"
ecs.import "ant.objcontroller"
ecs.import "ant.hierarchy.offline"

local renderpkg = import_package "ant.render"
local lu = renderpkg.light
local computil = renderpkg.components
local PVPScenLoader = require "PVPSceneLoader"

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

	computil.create_grid_entity(world, "grid", 64, 64, 1)
end
