local ecs = ...
local world = ecs.world
local ecs_policy = import_package "ant.ecs".policy

local m = ecs.component "prefab"

function m:init()
	local prefab = {
		entities = {},
	}
	for i = 1, #self do
		local policy, dataset, action = self[i].policy, self[i].data, self[i].action
		local info = ecs_policy.create(world, policy)
		local e = {}
		for _, c in ipairs(info.component) do
			e[c] = dataset[c]
		end
		for _, f in ipairs(info.process_prefab) do
			f(e)
		end
		prefab.entities[i] = {
			policy = info,
			dataset = e,
			action = action or {},
		}
	end
	return prefab
end
