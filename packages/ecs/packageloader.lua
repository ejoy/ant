local pm = require "antpm"
local fs = require "filesystem"
local get_modules = require "modules"

return function(name)
	local root = fs.path('/pkg/'..name)
	local modules = get_modules(root, {"*.lua"})
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
