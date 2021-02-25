local ecs = ...

local m = ecs.component "mesh"

local assetmgr = require "asset"
local ext_meshbin = require "ext_meshbin"

function m:init()
	if type(self) == "string" then
		return assetmgr.resource(self)
	end
	self.procedural_mesh = true
    return ext_meshbin.init(self)
end

function m:delete()
	if self.procedural_mesh then
		ext_meshbin.delete(self)
	end
end

local mbt = ecs.transform "mesh_bounding_transform"
function mbt.process_entity(e)
	local m = e.mesh
	if m.bounding and m.bounding.aabb then
		e._bounding.aabb = m.bounding.aabb
	end
end

local mpt = ecs.transform "mesh_prefab_transform"
function mpt.process_prefab(e)
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

local mt = ecs.transform "mesh_transform"

function mt.process_entity(e)
	local rc = e._rendercache
	local c = e._cache_prefab

	rc.vb = c.vb
	rc.ib = c.ib
end

local smt = ecs.transform "simple_mesh_transform"
function smt.process_entity(e)
	local s = e.simplemesh
	local rc = e._rendercache
	rc.vb = s.vb
	rc.ib = s.ib
end


local imesh = ecs.interface "imesh"
function imesh.create_vb(vb)
	return ext_meshbin.proxy_vb(vb)
end

function imesh.create_ib(ib)
	return ext_meshbin.proxy_ib(ib)
end