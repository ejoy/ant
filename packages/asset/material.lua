local ecs = ...
local world = ecs.world

local assetmgr = require "asset"

local mt = ecs.transform "material_transform"

function mt.process_prefab(e)
	local m = e.material
	if m then
		local c = e._cache
		local m = assetmgr.load_material(m, c.material_setting)
		c.fx, c.properties, c.state = m.fx, m.properties, m.state
	end
end

local im = ecs.interface "imaterial"
function im.load(materialpath, setting)
	local m = world.component "resource"(materialpath)
	return assetmgr.load_material(m, setting)
end

function im.set_property(eid, who, what)
	local rc = world[eid]._rendercache
	if what.stage then
		rc.properties[who] = what
	else
		assert(type(what) == "table")
		local t
		local n = #what
		if n == 4 then
			t = "vector"
		elseif n == 16 then
			t = "matrix"
		else
			error(("invalid uniform data, only support 4/16 array:%d"):format(n))
		end
		rc.properties[who] = world.component(t)(what)
	end
	
end
