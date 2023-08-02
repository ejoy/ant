local platform  = require "bee.platform"
local fs = require "filesystem"
local reg = require "registry"
local settings = assert(reg.create(fs.path "/settings"))

reg.use(settings, platform.os)

return settings
