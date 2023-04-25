local platform  = require "bee.platform"
local fs = require "filesystem"
local reg = require "registry"
local settings = assert(reg.create(fs.path "/settings"))

local BgfxOS <const> = {
    macos = "osx",
}
reg.use(settings, BgfxOS[platform.os] or platform.os)

return settings
