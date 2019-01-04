-- luacheck: globals import

local require = import and import(...) or require

local fs = require "filesystem"

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

-- local loaders = setmetatable({} , {
-- 	__index = function(_, ext)
-- 		error("Unsupport assetmgr type " .. ext)
-- 	end
-- })

-- for _, mname in ipairs(support_list) do	
-- 	loaders[mname] = require ("ext_" .. mname)
-- end
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

local assetsubdir = fs.path "assets"
local depictiondir = assetsubdir / "depiction"
local enginedir = fs.path "engine"

function assetmgr.assetdir()
	return assetsubdir
end

function assetmgr.depictiondir()
	return depictiondir
end

local engine_assetpath = enginedir / assetsubdir
local engine_assetbuildpath = engine_assetpath / "build"

local searchdirs = {
	assetsubdir, 
	assetsubdir / "build",
	engine_assetpath,
	engine_assetbuildpath,
}

--[[
	asset find order:
	1. try to load respath
	2. if respath include "engine/assets" sub path, try "engine/assets/build"
	3. this file should be a relative path, then try:
		3.1. try local path, include "assets", "assets/build"
		3.2. if local path not found, try "engine/assets", "engine/assets/build".

	that insure:
		if we want a file using a path like this:
			"engine/assets/depicition/bunny.mesh"
		meaning, we want an engine file, and will not load bunny.mesh file from local directory

		if we want a file without "engine/assets" sub path, then it will try to load
		from local path, if not found, then try "engine/assets" path
]]
function assetmgr.find_valid_asset_path(respath)
	if fs.exists(respath) then		
		return respath
	end

	local enginebuildpath, found = respath:string():gsub(("^/?%s"):format(engine_assetpath:string()), engine_assetbuildpath:string())
	if found ~= 0 then
		if fs.exists(enginebuildpath) then
			return enginebuildpath
		end
		return nil
	end

	for _, v in ipairs(searchdirs) do
		local p = v / respath
		if fs.exists(p) then
			return p
		end
	end
	return nil
end

function assetmgr.find_depiction_path(p)
	local fn = assetmgr.find_valid_asset_path(p)
	if fn == nil then
		if not p:string():match("^/?engine/assets") then
			local np = fs.path("depiction") / p
			fn = assetmgr.find_valid_asset_path(np)
		end
	end

	if fn == nil then
		error(string.format("invalid path, %s", p))
	end

	return fn	
end

function assetmgr.load(filepath, param)
	local res = resources[filepath:string()]
	if res == nil then
		local moudlename = filepath:extension():string():match("%.(.+)$")
		if moudlename == nil then
			error(string.format("not found ext from file:%s", filepath:string()))
		end
		local loader = get_loader(moudlename)
		res = loader(filepath, param)
		resources[filepath:string()] = res
	end

	return res
end

function assetmgr.save(tree, filepath)	
	local seri = require "serialize.util"
	seri.save(filepath, tree)
end

function assetmgr.has_res(filepath)
	return resources[filepath:string()] ~= nil
end

return assetmgr
