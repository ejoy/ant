local fs = require "bee.filesystem"
local vfs = require "vfs"

local app_path = fs.path(vfs.directory "external")

return function ()
    return app_path
end
