local fs = require "filesystem"
local datalist = require "datalist"
local resource = import_package "ant.resource"

local assetmgr = {}
assetmgr.__index = assetmgr

function assetmgr.load_depiction(filename)
	if type(filename) == "string" then
		filename = fs.path(filename)
	end
	local f = assert(fs.open(filename, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
end

local support_ext = {
	fx        = true,
	hierarchy = true,
	material  = true,
	mesh      = true,
	ozz       = true,
	pbrm      = true,
	state     = true,
	terrain   = true,
	texture   = true,

	--
	rendermesh = true,
	glbmesh   = true,
}

local function get_accessor(name)
	if support_ext[name] then
		return require ("ext_" .. name)
	end

	error("Unsupport asset type: " .. name)
end

function assetmgr.get_loader(name)
	return get_accessor(name).loader
end

function assetmgr.get_unloader(name)
	return get_accessor(name).unloader
end

function assetmgr.load(filename, data, lazyload)
    resource.load(filename, data, lazyload)
    return resource.proxy(filename)
end

function assetmgr.load_multiple(filelist, lazyload)
    for _, filename in ipairs(filelist) do
        resource.load(filename, nil, lazyload)
    end
    return resource.multiple_proxy(filelist)
end

function assetmgr.init()
	for name in pairs(support_ext) do
		local accessor = get_accessor(name)
		resource.register_ext(name, accessor.loader, accessor.unloader)
	end
end

return assetmgr
