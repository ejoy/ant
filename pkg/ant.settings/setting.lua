local platform  = require "bee.platform"
local fs = require "filesystem"
local reg = require "registry"

local function read_setting(defpath, userpath)
    local default_settings = assert(reg.create(defpath))
    reg.use(default_settings, platform.os)

    if fs.exists(userpath) then
        local userdef_settings = assert(reg.create(userpath))
        reg.use(userdef_settings, platform.os)
        reg.merge(userdef_settings, default_settings)
        return userdef_settings
    else
        return default_settings
    end
end

local userdef_settings          = read_setting(fs.path "/pkg/ant.settings/default/settings",          fs.path "/settings")
local userdef_graphic_settings  = read_setting(fs.path "/pkg/ant.settings/default/graphic_settings",  fs.path "/graphic_settings")

reg.merge(userdef_settings, userdef_graphic_settings)

return userdef_settings
