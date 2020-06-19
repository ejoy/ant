local ecs = ...
local world = ecs.world
local ecs_policy = import_package "ant.ecs".policy

local m = ecs.component "prefab"

local function load_prefab(v)
	return {
		prefab = world.component "resource"(v.prefab),
		args = v.args or {},
	}
end

local function load_entity(v)
	local policy, dataset, action = v.policy, v.data, v.action
	local template = ecs_policy.create(world, policy)
	local e = {}
	for _, c in ipairs(template.component) do
		e[c] = dataset[c]
	end
	for _, f in ipairs(template.process_prefab) do
		f(e)
	end
	return {
		template = template,
		dataset = e,
		action = action or {},
	}
end

function m:init()
	local prefab = {}
	for _, v in ipairs(self) do
		prefab[#prefab+1] = v.prefab and load_prefab(v) or load_entity(v)
	end
	return prefab
end
