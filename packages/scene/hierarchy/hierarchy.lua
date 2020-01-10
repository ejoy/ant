local ecs = ...

local mathpkg			= import_package "ant.math"
local ms				= mathpkg.stack

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
	local node_mt = hiemodule.node_metatable()
	node_mt.add_child = math3d_adapter.vector(ms, node_mt.add_child, 3)
	node_mt.transform = math3d_adapter.vector(ms, node_mt.transform, 2)
end)