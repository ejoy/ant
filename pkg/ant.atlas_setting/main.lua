local fs = require "filesystem"
local datalist = require "datalist"
local aio = import_package "ant.io"

local function merge(root, tbl)
	for k,v in pairs(tbl) do
		if root[k] == nil then
			root[k] = v
		end
	end
end

local function create(paths)
	local root = {}
	for _, path in ipairs(paths) do
		if fs.exists(path) then
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
	"/pkg/vaststars.settings/atlas_setting.ant",
	"/pkg/ant.atlas_setting/default/atlas_setting.ant",
}
