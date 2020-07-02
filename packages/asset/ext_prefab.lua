local ecs_policy = import_package "ant.ecs".policy
local assetmgr = require "asset"
local cr = import_package "ant.compile_resource"
local datalist = require "datalist"

local function load_prefab(world, v)
	return {
		prefab = assetmgr.resource(world, v.prefab),
		data = v,
	}
end

local function load_entity(world, v)
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

local function loader(filename, world)
	local data = datalist.parse(cr.read_file(filename))
	local prefab = {}
	for _, v in ipairs(data) do
		prefab[#prefab+1] = v.prefab and load_prefab(world, v) or load_entity(world, v)
	end
	return prefab
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
