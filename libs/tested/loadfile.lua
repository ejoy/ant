local path = require "filesystem.path"
local assetmgr = require "asset"

return function (name)
    local sub_path = path.join(name)
    local filename = assetmgr.find_valid_asset_path(sub_path)
    if filename then
        local f = assert(io.open(filename, "rb"))
        local data = f:read "a"
        f:close()
        return data
    end
    return nil
end
