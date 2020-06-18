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
