local pm = require "antpm"
local fs = require "filesystem"
local get_modules = require "modules"

return function(name)
	local _, config = pm.find(name)
	if not _ then
		error(("package '%s' not found"):format(name))
		return
	end
	local root = fs.path('/pkg/'..name)
	local modules = config.ecs_modules
	if modules then
		local tmp = {}
		for _, m in ipairs(modules) do
			tmp[#tmp+1] = root / m
		end
		modules = tmp
	else
		modules = get_modules(root, {"*.lua"})
	end
	local results = {}
	for _, path in ipairs(modules) do
		local module, err = pm.loadfile(path)
		if not module then
			error(("module '%s' load failed:%s"):format(path:string(), err))
		end
		table.insert(results, module)
	end
	return results
end
