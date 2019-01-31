local ecs = ...
local world = ecs.world
local schema = world.schema

local assetmgr = import_package "ant.asset"

schema:type "hierarchy"
	.ref_path "resource"

local hierarchy = ecs.component "hierarchy"

function hierarchy:load()
	self.builddata = assert(assetmgr.load(self.ref_path.package, self.ref_path.filename))
	return self
end

schema:type "hierarchy_name_mapper"
local hierarchy_name_mapper = ecs.component "hierarchy_name_mapper"

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
