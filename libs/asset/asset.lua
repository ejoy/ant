local require = import and import(...) or require

local path = require "filesystem.path"
local fs = require "filesystem"
local seri = require "serialize.util"

local support_list = {
	"shader",
	"mesh",
	"state",
	"uniform",
	"camera",
	"render",
	"tex_mapper",
	"material",
	"hierarchy",
	"module",
}

local loader = setmetatable({} , {
	__index = function(_, ext)
		error("Unsupport assetmgr type " .. ext)
	end
})

for _, mname in ipairs(support_list) do
	loader[mname] = require("ext_" .. mname)
end

local assetmgr = {}
assetmgr.__index = assetmgr

local resources = setmetatable({}, {__mode="kv"})

-- function assetmgr.get_loaders()
-- 	return loader
-- end

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
	assert(idx <= #searchdirs)
	table.insert(searchdirs, idx, dir)
end

function assetmgr.remove_searchdir(idx)
	assert(idx <= #searchdirs)
	table.remove(searchdirs, idx)
end

function assetmgr.load(filename)
	assert(type(filename) == "string")
	local res = resources[filename]
	if res == nil then
		local ext = assert(path.ext(filename))
		local fn = assetmgr.find_valid_asset_path(filename)
		if fn == nil then
			fn = assetmgr.find_valid_asset_path(path.join("assetfiles", filename))
		end		
		
		res = loader[ext](fn)
		resources[fn] = res
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
-- 		local v = loader[ext](filename, t)
-- 		t[filename] = v		
-- 		return v
-- 	end,
-- })

-- return assetmgr_cache
