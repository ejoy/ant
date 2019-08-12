local ecs = ...

local mathpkg			= import_package "ant.math"
local ms				= mathpkg.stack

local assetpkg			= import_package "ant.asset"
local assetmgr			= assetpkg.mgr

local hiemodule 		= require "hierarchy"
local math3d_adapter 	= require "math3d.adapter"

local hiecomp = ecs.component "hierarchy"
	["opt"].ref_path "respath"
	["opt"].visible "boolean"
function hiecomp:init()
	self.visible = self.visible or true
	if self.ref_path then
		assetmgr.load(self.ref_path)
	end
end

function hiecomp:delete()
	if self.ref_path then
		assetmgr.unload(self.ref_path)
	end
end

local mathadapter_util = import_package "ant.math.adapter"

mathadapter_util.bind("hierarchy", function ()
	local node_mt = hiemodule.node_metatable()	
	node_mt.add_child = math3d_adapter.vector(ms, node_mt.add_child, 3)
	node_mt.transform = math3d_adapter.vector(ms, node_mt.transform, 2)
end)