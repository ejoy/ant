local require = import and import(...) or require
local log = log and log(...) or print

local rawtable = require "rawtable"
local path = require "filesystem.path"

-- terrain loader protocal 
return function (filename, param)
    local mesh = rawtable(filename)
    -- todo: terrain struct 
    -- or use extension file format outside
     
    return mesh
end
