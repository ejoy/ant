local ecs = ...

local schema = ecs.schema

schema:type "scenenode"
	["opt"].parent "scenenode" ()
	.id "int" (-1)
	["opt"].hierarchy_ref "hierarchy" ()
	.eid "int" (-1)
	.children "scenenode[]"

schema:type "scenelayer"
	.nodes "scenenode[]"


local testscene = ecs.system "test_scene"
function testscene:init()
	local layereid = world:new_entity("scenelayer", "name", "serialize")

	local layer = world[layereid]
	local sceneroot = world:create_component("scenenode")
	table.insert(layer.scenelayer.nodes, sceneroot)


	local cubeeid = world:new_entity(
		"position", "scale", "rotation"
	)

	--sn.parent


end