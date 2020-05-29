local ecs = ...
local world = ecs.world
local policy = import_package "ant.ecs".policy

local m = ecs.component "prefab"

function m:init()
	local prefab = {
		entities = {},
		connection = self[1],
	}
	for i = 2, #self do
		local policies, dataset = self[i].policy, self[i].data
		local info = policy.create(world, policies)
		local e = {}
		for _, c in ipairs(info.component) do
			e[c] = dataset[c]
		end
		for _, f in ipairs(info.process_prefab) do
			f(e)
		end
		prefab.entities[i-1] = {
			policy = info,
			dataset = e,
		}
	end
	return prefab
end
