local ecs = ...
local world = ecs.world

local assetmgr = require "asset"

local m = ecs.component "meshskin"

function m:init()
	if type(self) == "string" then
		return assetmgr.resource(world, self)
	end
	return self
end
