local assetmgr = require "asset"
local fs = require "filesystem"
local rawtable = require "asset.rawtable"

return function(filename)
    local t = rawtable(assetmgr.find_depiction_path(filename))
    local files = assert(t.modules)
    local modules = {}
    for _, v in ipairs(files) do
        table.insert(modules, v)
    end

    return modules
end
