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
	fx		= true,
	pbrm	= true,
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

local function res_key(filename)
	-- TODO, should use vfs to get the resource file unique key(resource hash), for cache same content file	
	return filename:string()
end

local function module_name(filename)
	return filename:extension():string():match "%.(.+)$"
end

local function is_file(filename)
	return filename:string():sub(1, 2) ~= '//'
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

assetmgr.load_depiction = rawtable

assetmgr.res_key = res_key

local resource_profiles = {}

function assetmgr.unload(reskey)
	local res = resources[reskey]
	if res then
		local unloader = assetmgr.get_unloader(module_name(fs.path(reskey)))
		if unloader then
			unloader(res)
		end
		resources[reskey] = nil
		resource_profiles[reskey] = nil
	else
		log.error("not found resource:", reskey)
	end
end

local function generate_resname_operation()
	local stem_namemapper = {}
	return function (resname)
		local ss = resname:string()
		assert(ss:sub(1, 2) == "//")
		
		local stem = resname:stem()
		
		local stemname = stem:string()
		local idx = stem_namemapper[stemname] or 0
		idx = idx + 1
		stem_namemapper[stemname] = idx
		
		return resname:parent_path() / stemname .. "_" .. idx .. resname:extension():string()
	end
end

local generate_resname = generate_resname_operation()

local reloaders = {}

local function load_resource(filename)
	if is_file(filename) then
		local loader = assetmgr.get_loader(module_name(filename))
		return loader(filename)
	end

	assert(filename:string():match "//res.mesh")
	local loader = reloaders[res_key(filename)]
	if loader then
		return loader()
	end
end

local function record_resource_used(reskey)
	local profile = assert(resource_profiles[reskey])
	profile.counter = profile.counter + 1
end

function assetmgr.resource_profiles()
	return resource_profiles
end

function assetmgr.each_resource()
	return pairs(resources)
end

local function default_profile(sizebytes)
	return {
		counter = 0,
		sizebytes = sizebytes
	}
end

function assetmgr.get_resource(filename)
	local reskey = res_key(filename)
	local res = resources[reskey]
	if res == nil then
		local ressize
		res, ressize = load_resource(filename)
		if res then
			resources[reskey] = res
			resource_profiles[reskey] = default_profile(ressize or 0)
		end
	end
	if res then
		record_resource_used(reskey)
	end
	return res
end

function assetmgr.register_resource(reffile, content, reloader)
	local res = assetmgr.get_resource(reffile)
	if res then
		local newreffile = generate_resname(reffile)
		res = assetmgr.get_resource(newreffile)
		if res then
			log.error("ref key have been used:", reffile:string(), ", regenerate resname still used:", newreffile:string())
		else
			log.info("duplicate resname : ", reffile:string(), ", using new resname:", newreffile:string())
		end
		reffile = newreffile
	end

	local reskey = res_key(reffile)
	resources[reskey] = content
	resource_profiles[reskey] = default_profile(0)

	if reloader then
		reloaders[reskey] = reloader
	end
	return reffile
end

function assetmgr.get_all_resources()
	return resources
end

function assetmgr.save(tree, filename)
	local seri = import_package "ant.serialize"
	seri.save(filename, tree)
end

function assetmgr.has_resource(filename)
	local key = res_key(filename)
	return resources[key] ~= nil
end

return assetmgr
