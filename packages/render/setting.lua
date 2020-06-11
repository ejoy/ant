local platform  = require "platform"
local fs = require "filesystem"
local settings = import_package "ant.settings".create((fs.path "settings"):localpath(), "r")
settings:use(platform.OS:lower())

return settings
