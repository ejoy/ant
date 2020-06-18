local ecs = ...
local world = ecs.world
local ecs_policy = import_package "ant.ecs".policy

local m = ecs.component "prefab"

local function load_entity(v)
	local policy, dataset, action = v.policy, v.data, v.action
	local info = ecs_policy.create(world, policy)
	local e = {}
	for _, c in ipairs(info.component) do
		e[c] = dataset[c]
	end
	for _, f in ipairs(info.process_prefab) do
		f(e)
	end
	return {
		policy = info,
		dataset = e,
		action = action or {},
	}
end

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

function m:init()
	local prefab = {}
	for _, v in ipairs(self) do
		if v.prefab then
			local subprefab = world.component "resource"(v.prefab)
			table_append(prefab, subprefab)
		else
			prefab[#prefab+1] = load_entity(v)
		end
	end
	return prefab
end
