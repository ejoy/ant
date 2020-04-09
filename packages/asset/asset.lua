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

function assetmgr.load(fullpath, data, lazyload)
	local fn = fullpath:match "[^:]+"
    resource.load(fn, data, lazyload)
    return resource.proxy(fullpath)
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

function assetmgr.clone(res_template, path)
	if path == nil then
		return resource.clone(res_template)
	end

	local root = resource.clone(res_template)
	local sub = root
	for name in path:gmatch "[^/]+" do
		local o = sub[name]
		if o == nil then
			error(string.format("invalid subpath %s in %s", name, path))
		end
		sub = resource.clone(o)
	end

	return root
end

return assetmgr
