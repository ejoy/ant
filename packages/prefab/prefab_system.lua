local ecs = ...
local world = ecs.world
local assetmgr = import_package "ant.asset"
require "prefab".init(world)

function world:create_template(t)
	local prefab = {__class=t}
	for _, v in ipairs(t) do
		if v.prefab then
			prefab[#prefab+1] = {
				prefab = assetmgr.resource(v.prefab, self),
				args = v.args,
			}
		else
			prefab[#prefab+1] = self:create_entity_template(v)
		end
	end
	return prefab
end

function world:instance(filename, args)
	local prefab = assetmgr.resource(filename, self)
	return self:instance_prefab(prefab, args)
end

function world:create_object(initargs)
	local prefab = assetmgr.resource(initargs[1], self)
	self:instance_prefab(prefab, {})
end

local m = ecs.system "prefab_system"
