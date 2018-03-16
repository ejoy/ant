local require = import and import(...) or require
local rawtable = require "rawtable"
require "util"

return function(filename, assetlib)
    local render = rawtable(filename)
    return recurse_read(render, filename, {"mesh", "material"}, assetlib)
end