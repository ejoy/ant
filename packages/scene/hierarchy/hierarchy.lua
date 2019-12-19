local ecs = ...

local mathpkg			= import_package "ant.math"
local ms				= mathpkg.stack

local assetpkg			= import_package "ant.asset"
local assetmgr			= assetpkg.mgr

local hiemodule 		= require "hierarchy"
local math3d_adapter 	= require "math3d.adapter"

local hiecomp = ecs.component "hierarchy" {depend = "transform"}
	["opt"].ref_path "respath"

function hiecomp:init()
	if self.ref_path then
		assetmgr.load(self.ref_path)
	end
	return self
end

local hp = ecs.policy "hierarchy"
hp.require_component "hierarchy"
hp.require_component "hierarchy_visible"
hp.require_component "transform"


local mathadapter_util = import_package "ant.math.adapter"

mathadapter_util.bind("hierarchy", function ()
	local node_mt = hiemodule.node_metatable()	
	node_mt.add_child = math3d_adapter.vector(ms, node_mt.add_child, 3)
	node_mt.transform = math3d_adapter.vector(ms, node_mt.transform, 2)
end)