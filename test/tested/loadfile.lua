local assetmgr = require "asset"

return function (name)    
    local filename = assetmgr.find_valid_asset_path(name)
    if filename then
        local f = assert(io.open(filename:string(), "rb"))
        local data = f:read "a"
        f:close()
        return data
    end
    return nil
end
