local ecs = ...

local world = ecs.world
local schema = world.schema

-- schema:type "scenenode"
-- 	.parent "scenenode" ()
-- 	.id "int" (-1)
-- 	.hierarchy_ref "hierarchy" ()
-- 	.eid "int" (-1)
-- 	.children "scenenode[]"

-- schema:type "scenelayer"
-- 	.nodes "scenenode[]"


-- local testscene = ecs.system "test_scene"
-- function testscene:init()
-- 	local layereid = world:new_entity("scenelayer", "name", "serialize")


-- end