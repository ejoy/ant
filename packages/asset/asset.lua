local fs = require "filesystem"
local datalist = require "datalist"
local resource = import_package "ant.resource"

local assetmgr = {}
assetmgr.__index = assetmgr

function assetmgr.load_depiction(filename)
	local f = assert(fs.open(fs.path(filename), "r"))
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

local TMPFILE_INDEX = 0
local function resource_load(fullpath, resdata, lazyload)
	local filename = fullpath:match "[^:]+"
	if filename:sub(1,1) ~= "/" then
		TMPFILE_INDEX = TMPFILE_INDEX + 1
		local serialize = import_package "ant.serialize"
		local data = serialize.dl(filename)
		local ext = filename:match("%.([^.\n]+)\n")
		local filename = ("/tmp/%08d.%s"):format(TMPFILE_INDEX, ext)
		resource.load(filename, data, lazyload)
		return filename
	end
	
	resource.load(filename, resdata, lazyload)
	return fullpath
end

function assetmgr.load(fullpath, resdata, lazyload)
    return resource.proxy(resource_load(fullpath, resdata, lazyload))
end

function assetmgr.load_multiple(filelist, lazyload)
    for i, filename in ipairs(filelist) do
        filelist[i] = resource_load(filename, lazyload)
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
