local require = import and import(...) or require
local rawtable = require "rawtable"
local assetmgr = require "asset"

return function(filename)	
	local fn = assetmgr.find_depiction_path(filename)
    local t = rawtable(fn)
    local files = assert(t.modules)
    local modules = {}
    for _, v in ipairs(files) do
        table.insert(modules, v)
    end

    return modules
end