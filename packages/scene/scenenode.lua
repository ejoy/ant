local ecs = ...
local world = ecs.world
local schema = world.schema
local fs = require "filesystem"

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
	local layereid = world:create_entity{
		scenelayer = {

		}, 
		name = "scene layer", 
		serialize = '',
	}

	local layer = world[layereid]
	local sceneroot = world:create_component("scenenode")
	table.insert(layer.scenelayer.nodes, sceneroot)

	local cubeeid = world:create_entity  {
		position = {0, 0, 0, 1},
		scale = {1, 1, 1, 0},
		rotation = {0, 0, 0, 0},
		can_render = true,
		mesh = {
			ref_path = {package="ant.resources", filename = fs.path "cube.mesh"},
		},
		material = {
			content = {
				{
					ref_path = {package = "ant.resources", filename = fs.path "bunny.material"}
				}
			}
		},
		name = "cube",
	}

	--sn.parent


end