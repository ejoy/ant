local pm = require "antpm"
local fs = require "filesystem"
local get_modules = require "modules"

return function(name)
	local root = fs.path('/pkg/'..name)
	local modules = get_modules(root, {"*.lua"})
	local results = {}
	for _, path in ipairs(modules) do
		local module, err = fs.loadfile(path, 't', pm.loadenv(name))
		if not module then
			error(("module '%s' load failed:%s"):format(path:string(), err))
		end
		results[#results+1] = module
	end
	return results
end
