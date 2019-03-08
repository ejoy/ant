local assetmgr = require "asset"

-- terrain loader protocal 
return function (filename)
    local mesh = assetmgr.get_depiction(filename)
    -- todo: terrain struct 
    -- or use extension file format outside
    return mesh
end
