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


function assetmgr.find_depiction_path(fullrespath)
	local res = assetmgr.find_asset_path(fullrespath)
	if res == nil then
		local pkgname = fullrespath:root_name()
		res = assetmgr.find_asset_path(pkgname / "depiction" / pfs.relative(fullrespath, pkgname))
	end
	if res == nil then
		error(string.format("not found res, pkgname:%s, respath:%s", fullrespath:string()))
	end
	return res
end

local function res_key(filename)
	-- TODO, should use vfs to get the resource file unique key(resource hash), for cache same content file	
	return filename:string()
end

function assetmgr.load(filename, param)	
	assert(type(filename) ~= "string")

	local reskey = res_key(filename)
	local res = resources[reskey]
	if res == nil then
		local moudlename = filename:extension():string():match("%.(.+)$")
		if moudlename == nil then
			error(string.format("not found ext from file:%s", filename:string()))
		end
		local loader = assetmgr.get_loader(moudlename)
		res = loader(filename, param)
		resources[reskey] = res
	end

	return res
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
