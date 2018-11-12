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

local asset_rootdir = "assets"

local searchdirs = {	
	asset_rootdir,
	asset_rootdir .. "/build"
}

function assetmgr.get_searchdirs()
	return searchdirs
end

function assetmgr.find_valid_asset_path(asset_subpath)
	if vfsutil.exist(asset_subpath) then
		return asset_subpath
	end

	for _, d in ipairs(searchdirs) do
		local p = path.join(d, asset_subpath)        
		if vfsutil.exist(p) then
			return p
		end
	end

	return nil
end

function assetmgr.assetdir()
	return asset_rootdir
end

function assetmgr.insert_searchdir(idx, dir)
	if idx then
		assert(idx <= #searchdirs)
	else
		idx = idx or (#searchdirs + 1)
	end
	table.insert(searchdirs, idx, dir)
end

function assetmgr.remove_searchdir(idx)
	assert(idx <= #searchdirs)
	table.remove(searchdirs, idx)
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
