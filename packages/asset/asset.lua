local fs = require "filesystem"
local datalist = require "datalist"
local resource = import_package "ant.resource"

local assetmgr = {}
assetmgr.__index = assetmgr

function assetmgr.load_depiction(filepath)
	local f = assert(fs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
end

local support_ext = {
	mesh = true,
	rendermesh = true,
}

function assetmgr.init()
	for name in pairs(support_ext) do
		local accessor = require("ext_" .. name)
		resource.register_ext(name, accessor.loader, accessor.unloader)
	end
end

return assetmgr
