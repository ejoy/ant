local fs = require "filesystem"
local vfs = require "vfs"
local antpm = require "antpm"

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
}

local loaders = {}
local function get_loader(name)	
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

local assetmgr = {}
assetmgr.__index = assetmgr

local resources = setmetatable({}, {__mode="kv"})

local engineassetdir = fs.path "engine/assets"

function assetmgr.pkgdir(pkgname)
	if pkgname == nil or pkgname == "engine" then
		return engineassetdir
	end

	local root = antpm.find(pkgname)
	if root == nil then
		error(string.format("package not found:%s", pkgname))
	end
	return root
end

function assetmgr.find_asset_path(pkgname, respath)
	local pkgpath = assetmgr.pkgdir(pkgname)

	local fullrespath = pkgpath / respath
	if vfs.type(fullrespath:string()) ~= nil then
		return fullrespath
	end
	return nil
end

function assetmgr.find_depiction_path(pkgname, respath)
	local fullrespath = assetmgr.find_asset_path(pkgname, respath)
	if fullrespath == nil then
		fullrespath = assetmgr.find_asset_path(pkgname, fs.path "depiction" / respath)
	end

	if fullrespath == nil then
		error(string.format("not found res, pkgname:%s, respath:%s", pkgname or "engine", respath))
	end
	return fullrespath
end


local function res_key(pkgname, respath)
	-- TODO, should use vfs to get the resource file unique key(resource hash), for cache same content file
	pkgname = pkgname or "engine"
	return string.format("%s:%s", pkgname, respath:string())
end

function assetmgr.load(pkgname, respath, param)	
	assert(pkgname == nil or type(pkgname) == "string")
	assert(type(respath) == "userdata")

	local reskey = res_key(pkgname, respath)
	local res = resources[reskey]
	if res == nil then
		local moudlename = respath:extension():string():match("%.(.+)$")
		if moudlename == nil then
			error(string.format("not found ext from file:%s", respath))
		end
		local loader = get_loader(moudlename)
		res = loader(pkgname, respath, param)
		resources[res_key] = res
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
