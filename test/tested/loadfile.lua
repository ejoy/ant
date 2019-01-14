local assetmgr = import_package "ant.asset"

return function (name)    
    local filename = assetmgr.find_asset_path(nil, name)
    if filename then
        local f = assert(io.open(filename:string(), "rb"))
        local data = f:read "a"
        f:close()
        return data
    end
    return nil
end
