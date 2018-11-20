local require = import and import(...) or require

local fs = require "lfs"

local cache = setmetatable({}, {
	__mode = "kv" ,
	__index = function(self, path)
		local mod = assert(loadfile(path))
		self[path] = mod
		return mod
	end,
})

local function add_path(path, all)
	for fname in fs.dir(path) do
		local name = fname:match "^(.*)%.lua$"
		if name and all[name] == nil then
			all[name] = path .. "/" .. name .. ".lua"
		end
	end
end

return function (path)
	local all = {}
	for p in path:gmatch "[^;]+" do
		add_path(p, all)
	end
	local modules = {}
	for mod, filename in pairs(all) do
		local f = cache[filename]
		table.insert(modules,f)
	end
	return modules
end
