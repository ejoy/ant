local platform  = require "bee.platform"
local fs = require "filesystem"
local reg = require "registry"

local function read_setting(defpath, userpath)
    local default_settings = assert(reg.create(defpath))
    reg.use(default_settings, platform.os)

    if fs.exists(fs.path(userpath)) then
        local userdef_settings = assert(reg.create(userpath))
        reg.use(userdef_settings, platform.os)
        reg.merge(userdef_settings, default_settings)
        return userdef_settings
    else
        return default_settings
    end
end

local general_settings = read_setting("/pkg/ant.settings/default/general.settings", "/general.settings")
local graphic_settings = read_setting("/pkg/ant.settings/default/graphic.settings", "/graphic.settings")

reg.merge(general_settings, graphic_settings)

return general_settings
