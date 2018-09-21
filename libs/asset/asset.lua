-- luacheck: globals import

local require = import and import(...) or require

local path = require "filesystem.path"
local fs = require "filesystem"
local seri = require "serialize.util"

local support_list = {
	"shader",
	"mesh",
	"state",			
	"material",
	"module",
	"texture",
	"hierarchy",
	"ozz",
	"lk",
}

-- luacheck: ignore param
local function raw_loader(filename, param)
	local f = io.open(filename)
	if f == nil then
		error(string.format("raw_loader open file failed, filename : ", filename))
	end
	local content = f:read("a")
	f:close()
	return content
end

local loaders = setmetatable({} , {
	__index = function(_, ext)
		error("Unsupport assetmgr type " .. ext)
	end
})

for _, mname in ipairs(support_list) do	
	loaders[mname] = require ("ext_" .. mname)
end

local assetmgr = {}
assetmgr.__index = assetmgr

local resources = setmetatable({}, {__mode="kv"})

function assetmgr.add_loader(n, l)
	--assert(loaders[n] == nil)
	loaders[n] = l
end

local asset_rootdir = "assets"

local searchdirs = {
	asset_rootdir,
	asset_rootdir .. "/build"
}

function assetmgr.get_searchdirs()
	return searchdirs
end

function assetmgr.find_valid_asset_path(asset_subpath)
	if path.is_mem_file(asset_subpath) or fs.exist(asset_subpath) then
		return asset_subpath
	end

	for _, d in ipairs(searchdirs) do
		local p = path.join(d, asset_subpath)
        print("check exist: ".. p)
		if fs.exist(p) then
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
		local fn 
		for _, ff in ipairs{filename, path.join("assetfiles", filename)} do
			fn = assetmgr.find_valid_asset_path(ff)
		end

		if fn == nil then
			error(string.format("asset file not found, filename : %s", filename))
		end

		local loader = loaders[ext] or raw_loader
		res = loader(fn, param)
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

-- local assetmgr_cache = setmetatable({}, {
-- 	__mode = "kv",
-- 	__index = function (t, filename)
-- 		assert(type(filename) == "string")		
-- 		local ext = assert(filename:match "%.([%w_]+)$")
-- 		local v = loaders[ext](filename, t)
-- 		t[filename] = v		
-- 		return v
-- 	end,
-- })

-- return assetmgr_cache
