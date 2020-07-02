local ecs = ...
local world = ecs.world

local assetmgr = require "asset"
local resource = import_package "ant.resource"

local m = ecs.component "skeleton"

function m:init()
	if type(self) == "string" then
		return assetmgr.resource(world, self)
	end
	return self
end

function m:save()
	if resource.status(self) ~= "runtime" then
		return tostring(self)
	end
	return self
end
