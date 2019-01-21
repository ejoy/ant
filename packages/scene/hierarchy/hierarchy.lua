local ecs = ...
local world = ecs.world
local schema = world.schema

local assetmgr = import_package "ant.asset"
local fs = require "filesystem"

schema:userdata "hierarchy"
local hierarchy = ecs.component "hierarchy"

function hierarchy:init()
	return {
		builddata = nil
	}
end

function hierarchy:save()
	self.ref_path[2] = self.ref_path[2]:string()
	return self
end

function hierarchy:load()
	self.ref_path[2] = fs.path(self.ref_path[2])
	self.builddata = assert(assetmgr.load(self.ref_path[1], self.ref_path[2]))
	return self
end

schema:userdata "hierarchy_name_mapper"
local hierarchy_name_mapper = ecs.component "hierarchy_name_mapper"

function hierarchy_name_mapper:init()
	return {}
end

function hierarchy_name_mapper:save()
	assert(type(self) == "table")
	local t = {}
	for k, eid in pairs(self) do
		assert(type(eid) == "number")
		local e = world[eid]
		local seri = e.serialize
		if seri then
			t[k] = seri.uuid
		end
	end
	return t
end
