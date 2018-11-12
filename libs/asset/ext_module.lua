local require = import and import(...) or require
local rawtable = require "rawtable"
local assetmgr = require "asset"

return function(filename)	
	local fn = assetmgr.find_valid_asset_path(filename)
	if fn == nil then
		error(string.format("invalid file, %s", filename))
	end

    local t = rawtable(fn)
    local files = assert(t.modules)
    local modules = {}
    for _, v in ipairs(files) do
        table.insert(modules, v)
    end

    return modules
end