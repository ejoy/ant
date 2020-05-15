local fs = require "filesystem"
local datalist = require "datalist"
local resource = import_package "ant.resource"

local assetmgr = {}
assetmgr.__index = assetmgr

local function valid_component(world, name)
	local tc = world:import_component(name)
	return tc and tc.methodfunc and tc.methodfunc.init
end

function assetmgr.load_component(world, name, filename)
	if not filename or not valid_component(world, name) then
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

local ext_bin = {
	fx      = true,
	texture = true,
	mesh    = true,
	ozz     = true,
}

local ext_tmp = {
	rendermesh 	= true,
	glbmesh   	= true,
	gpufx		= true,
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
	local function loader(ext, filename, data)
		if ext_bin[ext] then
			return require("ext_" .. ext).loader(filename, data)
		elseif ext_tmp[ext] then
			return require("ext_" .. ext).loader(data)
		else
			local world = data
			return assetmgr.load_component(world, ext, filename)
		end
	end
	local function unloader(ext, res, data)
		if ext_bin[ext] then
			require("ext_" .. ext).unloader(res)
		elseif ext_tmp[ext] then
			require("ext_" .. ext).unloader(res)
		else
			local world = data
			world:component_delete(ext, res)
		end
	end
	resource.register(loader, unloader)
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
