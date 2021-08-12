local ecs = ...
local world = ecs.world

local lm_baker = ecs.system "lightmap_baker_system"

function lm_baker:init_world()
	world:instance "/pkg/ant.tool.lightmap_baker/assets/scene/scene.prefab"
	world:pub{"bake"}	--bake all scene
end