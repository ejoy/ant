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
	material  = true,
	mesh      = true,
	ozz       = true,
	pbrm      = true,
	state     = true,
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
	if fullpath:sub(1,1) ~= "/" then
		TMPFILE_INDEX = TMPFILE_INDEX + 1
		local serialize = import_package "ant.serialize"
		local data = serialize.dl(fullpath)
		local ext = fullpath:match("%.([^.\n]+)\n")
		local filename = ("/tmp/%08d.%s"):format(TMPFILE_INDEX, ext)
		resource.load(filename, data, lazyload)
		return filename
	end

	local filename = fullpath:match "[^:]+"
	resource.load(filename, resdata, lazyload)
	return fullpath
end

function assetmgr.load(fullpath, resdata, lazyload)
    return resource.proxy(resource_load(fullpath, resdata, lazyload))
end

function assetmgr.init()
	for name in pairs(support_ext) do
		local accessor = get_accessor(name)
		resource.register_ext(name, accessor.loader, accessor.unloader)
	end
end

assetmgr.patch = resource.patch

local resource_cache = {}
function assetmgr.generate_resource_name(restype, name)
	local key = ("//res.%s/%s"):format(restype, name)
	local idx = resource_cache[key]
	if idx == nil then
		resource_cache[key] = 0
		return key
	end

	idx = idx + 1
	resource_cache[key] = idx
	local n, ext = name:match "([^.]+)%.(.+)$"
	return ("//res.%s/%s%d.%s"):format(restype, n, idx, ext)
end

return assetmgr
