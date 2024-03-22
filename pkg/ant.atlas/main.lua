local fs = require "filesystem"
local datalist = require "datalist"
local aio = import_package "ant.io"

local function merge(root, tbl)
	for k,v in pairs(tbl) do
		if root[k] == nil then
			root[k] = string.gsub(k, ".texture", ".atlas")
		end
	end
end

local function create(paths)
	local root = {}
	for _, path in ipairs(paths) do
		if fs.exists(fs.path(path)) then
			merge(root, assert(datalist.parse(aio.readall(path))))
		end
	end
	local obj = {}
	function obj:get(key)
        return root[key] and root[key] or key
	end
	return obj
end

return create {
	"/atlas.ant",
	"/pkg/ant.atlas/default/atlas.ant",
}
