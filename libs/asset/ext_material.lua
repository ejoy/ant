local require = import and import(...) or require

local rawtable = require "rawtable"
require "util"

return function(filename, assetlib)
    local material = assert(rawtable(filename))
    return recurse_read(material, filename, {"shader", "state", "tex_mapper", "uniform"}, assetlib)
end