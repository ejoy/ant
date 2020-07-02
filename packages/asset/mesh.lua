local ecs = ...
local world = ecs.world

local m = ecs.component "mesh"

local assetmgr = require "asset"
local resource = import_package "ant.resource"
local ext_meshbin = require "ext_meshbin"

function m:init()
	if type(self) == "string" then
		return assetmgr.resource(world, self)
	end
    return ext_meshbin.init(self)
end

function m:save()
	if resource.status(self) ~= "runtime" then
		return tostring(self)
	end
	return self
end

local mt = ecs.transform "mesh_transform"
function mt.process_prefab(e)
	local mesh = e.mesh
	local c = e._cache_prefab
	if mesh then
		local handles = {}
		c.vb = {
			start   = mesh.vb.start,
			num     = mesh.vb.num,
			handles = handles,
		}
		for _, v in ipairs(mesh.vb) do
			handles[#handles+1] = v.handle
		end
		if mesh.ib then
			c.ib = {
				start	= mesh.ib.start,
				num 	= mesh.ib.num,
				handle	= mesh.ib.handle,
			}
		else
			c.ib = nil
		end
	end
end
