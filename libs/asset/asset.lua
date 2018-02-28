local require = import and import(...) or require

local support_list = {
	"shader",
	"mesh",
	"state",
	"uniform",
	"camera",
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
		local ext = assert(filename:match "%.(%w+)$")
		local v = loader[ext](filename)
		t[filename] = v
		return v
	end,
})

return asset_cache
