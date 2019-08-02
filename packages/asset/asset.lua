local fs = require "filesystem"

local resources = {
	shader = {},
	mesh = {},
	state = {},
	material = {},
	texture = {},
	hierarchy = {},
	lk = {},
	ozz = {},
	sm = {},
	terrain = {},
}

local loaders = {}
local assetmgr = {}
assetmgr.__index = assetmgr

function assetmgr.get_loader(name)	
	local loader = loaders[assert(name)]
	if loader == nil then
		if resources[name] then
			loader = require ("ext_" .. name)
			loaders[name] = loader
		else
			error("Unsupport assetmgr type " .. name)
		end
	end
	return loader
end

local function rawtable(filepath)
	local env = {}
	local r = assert(fs.loadfile(filepath, "t", env))
	r()
	return env
end

function assetmgr.get_depiction_path(fullpath)	
	if not fs.exists(fullpath) then
		local pkgdir = fs.path("/pkg") / fullpath:package_name()
		fullpath = pkgdir / "depiction" / fs.relative(fullpath, pkgdir)
		if not fs.exists(fullpath) then
			return nil
		end
	end

	return fullpath
end

function assetmgr.get_depiction(fullpath)
	local newfullpath = assetmgr.get_depiction_path(fullpath)
	if newfullpath == nil then
		error(string.format("not found file:%s", fullpath:string()))
	end
	return rawtable(newfullpath)
end

local function res_key(filename)
	-- TODO, should use vfs to get the resource file unique key(resource hash), for cache same content file	
	return filename:string()
end

local function module_name(filepath)
	return filepath:extension():string():match "%.(.+)$"
end

function assetmgr.load(filename, param)	
	assert(type(filename) ~= "string")

	local reskey = res_key(filename)
	local modulename = module_name(filename)
	local subres = resources[modulename]
	if subres == nil then
		error(string.format("not found ext from file:%s", filename:string()))
	end

	local res = subres[reskey]
	if res == nil then
		local loader = assetmgr.get_loader(assert(modulename))
		local handle = loader(filename, param)
		res = {
			handle 		= handle,
			lastframe 	= -1,
			ref_count	= 1,
		}
		subres[reskey] = res
	else
		res.ref_count = res.ref_count + 1
	end

	return res.handle
end

function assetmgr.unload(filename)
	assert(type(filename) ~= "string")
	local reskey = res_key(filename)
	
	local modulename = module_name(filename)
	local subres = resources[modulename]

	if subres == nil then
		error(string.format("not found sub resource from file:%s", filename:string()))
	end

	local res = subres[reskey]

	if res == nil then
		error(string.format("unload a not reference resource:%s", filename:string()))
	end

	if res.ref_count <= 0 then
		print("unload a resource which ref count low or equal to 0", filename:string())
	end

	res.ref_count = res.ref_count - 1
end

function assetmgr.get_resource(name)
	return resources[name]
end

for _, subname in ipairs {"texture", "mesh", "material"} do
	local subres = resources[subname]
	assetmgr["get" .. subname] = function (key)
		return subres[key].handle
	end
end

function assetmgr.save(tree, filename)	
	local seri = import_package "ant.serialize"
	seri.save(filename, tree)
end

function assetmgr.has_res(filename)
	local key = res_key(filename)
	return resources[key] ~= nil
end

return assetmgr
