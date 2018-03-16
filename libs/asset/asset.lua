local require = import and import(...) or require

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
		error("Unsupport asset type " .. ext)
	end
})

for _, mname in ipairs(support_list) do
	loader[mname] = require("ext_" .. mname)
end

local asset_cache = setmetatable({}, {
	__mode = "kv",
	__index = function (t, filename)
		assert(type(filename) == "string")
		print(filename)
		local ext = assert(filename:match "%.([%w_]+)$")
		local v = loader[ext](filename, t)
		t[filename] = v
		return v
	end,
})

return asset_cache
