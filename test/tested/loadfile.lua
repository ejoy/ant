local assetmgr = import_package "ant.asset"
local fs = require 'filesystem'

return function (name)    
    local filename = assetmgr.find_asset_path(nil, name)
    if filename then
        local f = assert(fs.open(filename, "rb"))
        local data = f:read "a"
        f:close()
        return data
    end
    return nil
end
