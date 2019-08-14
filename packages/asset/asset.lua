local fs = require "filesystem"

local support_types = {
	sc		= true,
	mesh 	= true,
	state 	= true,
	material= true,
	texture = true,
	hierarchy= true,--scene hierarchy info, using ozz-animation runtime struct
	lk 		= true,
	ozz 	= true,
	sm 		= true,	--animation state machine
	terrain = true,
}

local resources = {}
local accessors = {}

local assetmgr = {}
assetmgr.__index = assetmgr

local function get_accessor(name)
	local accessor = accessors[name]
	if accessor == nil then
		if support_types[name] then
			accessor 		= require ("ext_" .. name)
			accessors[name] = accessor
		else
			error("Unsupport asset type: " .. name)
		end
	end
	return accessor
end

function assetmgr.get_loader(name)
	return get_accessor(name).loader
end

function assetmgr.get_unloader(name)
	return get_accessor(name).unloader
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

local function get_resource(ref_path)
	local reskey = res_key(ref_path)
	return resources[reskey]
end

assetmgr.get_resource = get_resource
assetmgr.res_key = res_key

function assetmgr.load(filename, param)
	local reskey = res_key(filename)
	local res = resources[reskey]
	if res == nil then
		local loader = assetmgr.get_loader(module_name(filename))
		res = loader(filename, param)
		resources[reskey] = res
	end
	
	return res
end

function assetmgr.unload(filename)
	local reskey = res_key(filename)
	local res = resources[reskey]
	if res then
		local unloader = assetmgr.get_unloader(module_name(filename))
		unloader(res)
		resources[reskey] = nil
	else
		log.error("not found resource:", filename:string())
	end
end

function assetmgr.register_resource(reffile, content)
	local res = get_resource(reffile)
	if res then
		log.error("ref key have been used:", reffile:String())
	end

	resources[res_key(reffile)] = content
	return reffile
end

function assetmgr.get_all_resources()
	return resources
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
