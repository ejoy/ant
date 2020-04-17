local ecs = ...
local world = ecs.world
local pipeline = ecs.pipeline

world:import "@ant.scene"

-- define at least three stage init/exit/update
pipeline "init" {
	"init",
}

-- empty slot for exit/update
pipeline "exit"
pipeline "update" {
--	"data_changed",
--	"widget",
	pipeline "scene" {
		"update_hierarchy_scene",
		"lock_target",
		"update_transform",
	},
--	pipeline "render"
	"end_frame",
}

local m = ecs.system 'game'
--local sceneobject = world:require "ant.scene.object"
--local root = sceneobject.root

-- stage init
function m:init()
	local eid = world:create_entity {
		policy = { "ant.scene|hierarchy_policy" },
		data = {
			parent = 1,
			scene_entity = true,
		},
	}
--	local obj = root:create(eid)
--	print ("Game start", obj, obj.parent)
end
