local assetmgr = require "asset"
local rawtable = require "rawtable"

-- terrain loader protocal 
return function (filename)
    local mesh = rawtable(assetmgr.find_depiction_path(filename))
    -- todo: terrain struct 
    -- or use extension file format outside
    return mesh
end
