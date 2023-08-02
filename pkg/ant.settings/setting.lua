local platform  = require "bee.platform"
local fs = require "filesystem"
local reg = require "registry"

local default_settings = assert(reg.create(fs.path "/pkg/ant.settings/default/settings"))
local userdef_settings = assert(reg.create(fs.path "/settings"))
reg.use(default_settings, platform.os)
reg.use(userdef_settings, platform.os)
reg.merge(userdef_settings, default_settings)

return userdef_settings
