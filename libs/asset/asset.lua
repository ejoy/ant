-- luacheck: globals import

local require = import and import(...) or require

local path = require "filesystem.path"
local seri = require "serialize.util"
local vfsutil= require "vfs.util"

local support_list = {
	"shader",
	"mesh",
	"state",			
	"material",
	"module",
	"texture",
	"hierarchy",
	"ske",
	"ani",	
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
	local loader = loaders[name]
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

function assetmgr.find_valid_asset_path(respath)	
	if vfsutil.exist(respath) then
		return respath
	end

	local enginebuildpath, found = respath:gsub("^/?engine/assets", "engine/assets/build")
	if found ~= 0 then
		if vfsutil.exist(enginebuildpath) then
			return enginebuildpath
		end
		return nil
	end

	for _, v in ipairs {"assets", "assets/build"} do
		local p = path.join(v, respath)		
		if vfsutil.exist(p) then
			return p
		end
	end
	return nil
end

function assetmgr.find_depiction_path(p)
	local fn = assetmgr.find_valid_asset_path(p)
	if fn == nil then
		if not p:match("^/?engine/assets") then
			local np = path.join("depiction", p)
			fn = assetmgr.find_valid_asset_path(np)			
		end
	end

	if fn == nil then
		error(string.format("invalid path, %s", p))
	end

	return fn	
end

function assetmgr.load(filename, param)
  --  print("filename", filename)
	assert(type(filename) == "string")
	local res = resources[filename]
	if res == nil then
		local ext = assert(path.ext(filename))
		local loader = get_loader(ext)
		res = loader(filename, param)
		resources[filename] = res
	end

	return res
end

function assetmgr.save(tree, filename)
	assert(type(filename) == "string")
	seri.save(filename, tree)
end

function assetmgr.has_res(filename)
	return resources[filename] ~= nil
end

return assetmgr
