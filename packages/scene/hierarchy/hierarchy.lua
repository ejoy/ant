local ecs = ...

local hiemodule 		= require "hierarchy"
local math3d_adapter 	= require "math3d.adapter"

ecs.tag "scene_entity"

local hie = ecs.policy "hierarchy"
hie.require_component "parent"
hie.require_component "scene_entity"


local mathadapter_util = import_package "ant.math.adapter"

mathadapter_util.bind("hierarchy", function ()
	local node_mt 			= hiemodule.node_metatable()
	node_mt.add_child 		= math3d_adapter.format(node_mt.add_child, "vqv", 3)
	node_mt.set_transform 	= math3d_adapter.format(node_mt.set_transform, "vqv", 2)
	node_mt.transform 		= math3d_adapter.getter(node_mt.transform, "vqv", 2)

	local builddata_mt = hiemodule.builddata_metatable()
	builddata_mt.joint = math3d_adapter.getter(builddata_mt.joint, "m", 2)
end)