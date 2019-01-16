local ecs = ...
local world = ecs.world
local assetmgr = import_package "ant.asset"

local h = ecs.component_struct "hierarchy" {
	ref_path = "",
}

--TODO
--save = function(v, arg)
--	assert(type(v) == "string")
--	local e = world[arg.eid]
--	local comp = e[arg.comp]	
--	local builddata = comp.builddata
--	assert(builddata)
--	return v
--end,
--load = function(v)
--	assert(type(v) == "string")			
--	assert(fs.path(v):extension() == fs.path ".hierarchy")
--	local e = world[arg.eid]
--	local comp = e[arg.comp]
--
--	comp.builddata = assert(assetmgr.load(v))
--	return v
--end

function h:init()
	self.builddata = nil
end

ecs.component "hierarchy_name_mapper"{
}

--TODO
--save = function(v, arg)
--	assert(type(v) == "table")
--	local t = {}
--	for k, eid in pairs(v) do
--		assert(type(eid) == "number")
--		local e = world[eid]
--		local seri = e.serialize
--		if seri then
--			t[k] = seri.uuid
--		end
--	end
--	return t
--end,
--load = function(v, arg)
--	assert(type(v) == "table")
--	return v
--end
