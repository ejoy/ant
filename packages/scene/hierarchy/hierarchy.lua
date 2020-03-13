local ecs = ...

local mathpkg			= import_package "ant.math"

local hiemodule 		= require "hierarchy"
local math3d_adapter 	= require "math3d.adapter"

ecs.component "hierarchy"
	["opt"].ref_path "respath"

local hp = ecs.policy "hierarchy"
hp.require_component "hierarchy"
hp.require_component "hierarchy_visible"
hp.require_component "transform"

hp.require_system "ant.scene|scene_space"


local mathadapter_util = import_package "ant.math.adapter"

mathadapter_util.bind("hierarchy", function ()
	local node_mt 			= hiemodule.node_metatable()
	node_mt.add_child 		= math3d_adapter.format(node_mt.add_child, "vqv", 3)
	node_mt.set_transform 	= math3d_adapter.format(node_mt.set_transform, "vqv", 2)
	node_mt.transform 		= math3d_adapter.getter(node_mt.transform, "vqv", 2)

	local builddata_mt = hiemodule.builddata_metatable()
	builddata_mt.joint = math3d_adapter.getter(builddata_mt.joint, "m", 2)
end)