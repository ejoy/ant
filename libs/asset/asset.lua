local require = import and import(...) or require

local path = require "filesystem.path"
local fs = require "filesystem"

local support_list = {
	"shader",
	"mesh",
	"state",
	"uniform",
	"camera",
	"render",
	"tex_mapper",
	"material",
}

local loader = setmetatable({} , {
	__index = function(_, ext)
		error("Unsupport assetmgr type " .. ext)
	end
})

for _, mname in ipairs(support_list) do
	loader[mname] = require("ext_" .. mname)
end

local asset_default_path = "assets/assetfiles/materials"

local assetmgr = {}
assetmgr.__index = assetmgr

local resources = setmetatable({}, {__mode="kv"})

-- function assetmgr.get_loaders()
-- 	return loader
-- end



function assetmgr.load(filename)
	assert(type(filename) == "string")		
	local ext = assert(path.ext(filename))

	local function check_use_default_path(fn)
		if path.is_mem_file(fn) or fs.exist(fn) then
			return fn
		end

		local defaultpath = path.join(asset_default_path, fn)
		if not fs.exist(defaultpath) then
			error(string.format("file not exist : %s, tried : %s", fn, defaultpath))
			return nil
		end

		return defaultpath
	end

	local fn = check_use_default_path(filename)
	
	local v = loader[ext](fn)
	resources[fn] = v
	return v
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
