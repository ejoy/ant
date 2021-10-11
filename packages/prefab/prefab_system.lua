local ecs = ...
local world = ecs.world
local assetmgr = import_package "ant.asset"

if ecs.component then
	ecs.require "prefab".init(world)
end

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

function ecs.create_instance(filename, args)
	local prefab = assetmgr.resource(filename, self)
	return self:instance_prefab(prefab, args)
end
