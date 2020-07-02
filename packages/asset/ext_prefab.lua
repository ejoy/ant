local ecs = ...
local world = ecs.world
local ecs_policy = import_package "ant.ecs".policy

local m = ecs.component "prefab"

local function load_prefab(v)
	return {
		prefab = world.component "resource"(v.prefab),
		data = v,
	}
end

local function load_entity(v)
	local res = ecs_policy.create(world, v.policy)
	local e = {}
	for _, c in ipairs(res.component) do
		local init = res.init_component[c]
		local component = v.data[c]
		if component ~= nil then
			if init then
				e[c] = init(component)
			else
				e[c] = component
			end
		end
	end
	for _, f in ipairs(res.process_prefab) do
		f(e)
	end
	return {
		component = res.component,
		process = res.process_entity,
		template = e,
		data = v,
	}
end

function m:init()
	local prefab = {}
	for _, v in ipairs(self) do
		prefab[#prefab+1] = v.prefab and load_prefab(v) or load_entity(v)
	end
	return prefab
end
