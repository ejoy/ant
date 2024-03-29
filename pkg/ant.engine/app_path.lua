local fs = require "bee.filesystem"
local directory = dofile "/engine/firmware/directory.lua"

local app_path = fs.path(directory.external)

return function ()
    return app_path
end
