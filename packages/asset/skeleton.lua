local ecs = ...
local world = ecs.world

local assetmgr = require "asset"

local m = ecs.component "skeleton"

function m:init()
	if type(self) == "string" then
		return assetmgr.resource(self)
	end
	return self
end
