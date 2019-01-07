local ecs = ...
local world = ecs.world

ecs.import "render.constant_system"
ecs.import "render.camera.camera_component"
ecs.import "render.entity_rendering_system"


ecs.import_package "inputmgr"

-- light entity
ecs.import "serialize.serialize_component"
ecs.import "render.light.light"

-- scene
ecs.import "scene.filter.lighting_filter"
ecs.import "scene.filter.shadow_filter"
ecs.import "scene.filter.transparency_filter"
ecs.import "scene.hierarchy.hierarchy"

-- scene.cull
--ecs.import "scene.cull_system"

-- test entity
ecs.import "editor.ecs.editable_hierarchy"
ecs.import "editor.ecs.camera_controller"

-- enable
ecs.import "serialize.serialize_system"



local lu = require "render.light.util"
local PVPScenLoader = require "test.samples.PVPScene.PVPSceneLoader"

local init_loader = ecs.system "init_loader"

function init_loader:init()
	do
		lu.create_directional_light_entity(world, "directional_light")
		lu.create_ambient_light_entity(world, "ambient_light", "gradient", {1, 1, 1,1})
	end

	do
		PVPScenLoader.create_entitices(world)
	end

end