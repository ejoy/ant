local fs = require "filesystem"
local datalist = require "datalist"
local resource = import_package "ant.resource"

local assetmgr = {}
assetmgr.__index = assetmgr

function assetmgr.load_component(world, name, filename)
	if not filename then
		local f = assert(fs.open(fs.path(name), 'rb'))
		local data = f:read 'a'
		f:close()
		return datalist.parse(data, function(v)
			return world:component_init(v[1], v[2])
		end)
	end
	local f = assert(fs.open(fs.path(filename), 'rb'))
	local data = f:read 'a'
	f:close()
	return world:component_init(name, datalist.parse(data, function(v)
		return world:component_init(v[1], v[2])
	end))
end

local ext_ref = {
	material  = true,
	pbrm      = true,
}

local ext_bin = {
	fx      = true,
	texture = true,
	mesh    = true,
	ozz     = true,
}

local ext_tmp = {
	rendermesh = true,
	glbmesh   = true,
}

local function resource_load(fullpath, resdata, lazyload)
	local filename = fullpath:match "[^:]+"
	resource.load(filename, resdata, lazyload)
	return fullpath
end

function assetmgr.load(fullpath, resdata)
    return resource.proxy(resource_load(fullpath, resdata, false))
end

function assetmgr.resource(world, fullpath)
    return resource.proxy(resource_load(fullpath, world, true))
end

function assetmgr.init()
	for name in pairs(ext_ref) do
		local function loader(filename, world)
			return assetmgr.load_component(world, name, filename)
		end
		local function unloader(res, _, world)
			world:component_delete(name, res)
		end
		resource.register_ext(name, loader, unloader)
	end
	for name in pairs(ext_bin) do
		local function loader(filename, world)
			return world:component_init(name, filename)
		end
		local function unloader(res, _, world)
			world:component_delete(name, res)
		end
		resource.register_ext(name, loader, unloader)
	end
	for name in pairs(ext_tmp) do
		local accessor = require("ext_" .. name)
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
