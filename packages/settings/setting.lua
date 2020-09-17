local platform  = require "platform"
local fs = require "filesystem"
local reg = require "registry"
local settings = reg.create(fs.path "settings", "r")
settings:use(platform.OS:lower())

return settings
