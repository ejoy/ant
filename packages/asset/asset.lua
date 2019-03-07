local fs = require "filesystem"
local pfs = require "filesystem.pkg"

local support_list = {
	"shader",
	"mesh",
	"state",			
	"material",
	"module",
	"texture",
	"hierarchy",
	"lk",
	"ozz",
	"sm",
}

local loaders = {}
local assetmgr = {}
assetmgr.__index = assetmgr

function assetmgr.get_loader(name)	
	local loader = loaders[assert(name)]
	if loader == nil then
		local function is_support(name)
			for _, v in ipairs(support_list) do
				if v == name then
					return true
				end
			end
			return false
		end

		if is_support(name) then
			loader = require ("ext_" .. name)
			loaders[name] = loader
		else
			error("Unsupport assetmgr type " .. name)
		end
	end
	return loader
end

local resources = setmetatable({}, {__mode="kv"})

function assetmgr.find_asset_path(fullrespath)
	if pfs.exists(fullrespath) then
		return fullrespath:vfspath()
	end
	return nil
end

function assetmgr.find_asset_path_old(resource)
	local pkgname, respath = resource.package, resource.filename
	return assetmgr.find_asset_path(pfs.path('//'..pkgname) / respath)
end

function assetmgr.find_depiction_path(pkgname, respath)
	local fullrespath = assetmgr.find_asset_path(pfs.path('//'..pkgname) / respath)
	if fullrespath == nil then
		fullrespath = assetmgr.find_asset_path(pfs.path('//'..pkgname) / "depiction" / respath)
	end

	if fullrespath == nil then
		error(string.format("not found res, pkgname:%s, respath:%s", pkgname, respath))
	end
	return fullrespath
end


local function res_key(pkgname, respath)
	-- TODO, should use vfs to get the resource file unique key(resource hash), for cache same content file	
	return string.format("%s:%s", assert(pkgname), respath:string())
end

function assetmgr.load(pkgname, respath, param)	
	assert(pkgname == nil or type(pkgname) == "string")
	assert(type(respath) ~= "string")

	local reskey = res_key(pkgname, respath)
	local res = resources[reskey]
	if res == nil then
		local moudlename = respath:extension():string():match("%.(.+)$")
		if moudlename == nil then
			error(string.format("not found ext from file:%s", respath:string()))
		end
		local loader = assetmgr.get_loader(moudlename)
		res = loader(pkgname, respath, param)
		resources[reskey] = res
	end

	return res
end

function assetmgr.save(tree, pkgname, respath)	
	local seri = import_package "ant.serialize"
	seri.save(pkgname, respath, tree)
end

function assetmgr.has_res(pkgname, respath)
	local key = res_key(pkgname, respath)
	return resources[key] ~= nil
end

return assetmgr
