local platform  = require "bee.platform"
local fs = require "filesystem"
local reg = require "registry"
local settings = reg.create(fs.path "/settings", "r")

local BgfxOS <const> = {
    macos = "osx",
}
settings:use(BgfxOS[platform.os] or platform.os)

return settings
