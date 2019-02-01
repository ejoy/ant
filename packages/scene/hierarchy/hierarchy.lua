local ecs = ...
local world = ecs.world
local schema = world.schema

schema:typedef("hierarchy", "resource")

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
